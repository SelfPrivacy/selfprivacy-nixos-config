{ config, lib, pkgs, ... }:
let
  inherit (import ./common.nix config)
    admin-pass-filepath
    db-pass-filepath
    domain
    override-config-fp
    secrets-filepath
    sp
    ;

  hostName = "${cfg.subdomain}.${sp.domain}";
  auth-passthru = config.selfprivacy.passthru.auth;
  cfg = sp.modules.nextcloud;
  is-auth-enabled = cfg.enableSso && config.selfprivacy.sso.enable;
  ldap_scheme_and_host = "ldaps://${auth-passthru.ldap-host}";

  occ = "${config.services.nextcloud.occ}/bin/nextcloud-occ";

  nextcloud-secret-file = "/var/lib/nextcloud/secrets.json";
  nextcloud-setup-group =
    config.systemd.services.nextcloud-setup.serviceConfig.Group;

  admins-group = "sp.nextcloud.admins";
  users-group = "sp.nextcloud.users";
  wildcard-group = "sp.nextcloud.*";

  oauth-client-id = "nextcloud";
  kanidm-service-account-name = "sp.${oauth-client-id}.service-account";
  kanidm-service-account-token-name = "${oauth-client-id}-service-account-token";
  kanidm-service-account-token-fp =
    "/run/keys/${oauth-client-id}/kanidm-service-account-token"; # FIXME sync with auth module
  # TODO rewrite to tmpfiles.d, but make sure the group exists first!
  kanidmExecStartPreScriptRoot = pkgs.writeShellScript
    "${oauth-client-id}-kanidm-ExecStartPre-root-script.sh"
    ''
      # set-group-ID bit allows for kanidm user to create files,
      mkdir -p -v --mode=u+rwx,g+rs,g-w,o-rwx /run/keys/${oauth-client-id}
      chown kanidm:${nextcloud-setup-group} /run/keys/${oauth-client-id}
    '';
  kanidm-oauth-client-secret-fp =
    "/run/keys/${oauth-client-id}/kanidm-oauth-client-secret";
  kanidmExecStartPreScript = pkgs.writeShellScript
    "${oauth-client-id}-kanidm-ExecStartPre-script.sh" ''
    [ -f "${kanidm-oauth-client-secret-fp}" ] || \
      "${lib.getExe pkgs.openssl}" rand -base64 -out "${kanidm-oauth-client-secret-fp}" 32
  '';
  kanidmExecStartPostScript = pkgs.writeShellScript
    "${oauth-client-id}-kanidm-ExecStartPost-script.sh"
    ''
      export HOME=$RUNTIME_DIRECTORY/client_home
      readonly KANIDM="${pkgs.kanidm}/bin/kanidm"

      # get Kanidm service account for mailserver
      KANIDM_SERVICE_ACCOUNT="$($KANIDM service-account list --name idm_admin | grep -E "^name: ${kanidm-service-account-name}$")"
      echo KANIDM_SERVICE_ACCOUNT: "$KANIDM_SERVICE_ACCOUNT"
      if [ -n "$KANIDM_SERVICE_ACCOUNT" ]
      then
          echo "kanidm service account \"${kanidm-service-account-name}\" is found"
      else
          echo "kanidm service account \"${kanidm-service-account-name}\" is not found"
          echo "creating new kanidm service account \"${kanidm-service-account-name}\""
          if $KANIDM service-account create --name idm_admin "${kanidm-service-account-name}" "${kanidm-service-account-name}" idm_admin
          then
              echo "kanidm service account \"${kanidm-service-account-name}\" created"
          else
              echo "error: cannot create kanidm service account \"${kanidm-service-account-name}\""
              exit 1
          fi
      fi

      # add Kanidm service account to `idm_mail_servers` group
      $KANIDM group add-members idm_mail_servers "${kanidm-service-account-name}"

      # create a new read-only token for kanidm
      if ! KANIDM_SERVICE_ACCOUNT_TOKEN_JSON="$($KANIDM service-account api-token generate --name idm_admin "${kanidm-service-account-name}" "${kanidm-service-account-token-name}" --output json)"
      then
          echo "error: kanidm CLI returns an error when trying to generate service-account api-token"
          exit 1
      fi
      if ! KANIDM_SERVICE_ACCOUNT_TOKEN="$(echo "$KANIDM_SERVICE_ACCOUNT_TOKEN_JSON" | ${lib.getExe pkgs.jq} -r .result)"
      then
          echo "error: cannot get service-account API token from JSON"
          exit 1
      fi

      if ! install --mode=640 \
      <(printf "%s" "$KANIDM_SERVICE_ACCOUNT_TOKEN") \
      ${kanidm-service-account-token-fp}
      then
          echo "error: cannot write token to \"${kanidm-service-account-token-fp}\""
          exit 1
      fi
    '';
in
{
  options.selfprivacy.modules.nextcloud = with lib; {
    enable = (lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable Nextcloud";
    }) // {
      meta = {
        type = "enable";
      };
    };
    enableSso = (lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable SSO for Nextcloud";
    }) // {
      meta = {
        type = "enable";
      };
    };
    location = (lib.mkOption {
      type = lib.types.str;
      description = "Nextcloud location";
    }) // {
      meta = {
        type = "location";
      };
    };
    subdomain = (lib.mkOption {
      default = "cloud";
      type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
      description = "Subdomain";
    }) // {
      meta = {
        widget = "subdomain";
        type = "string";
        regex = "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
        weight = 0;
      };
    };
    enableImagemagick = (lib.mkOption {
      type = types.bool;
      default = true;
      description = "Enable ImageMagick";
    }) // {
      meta = {
        type = "bool";
        weight = 1;
      };
    };
    debug = lib.mkOption {
      default = false;
      type = lib.types.bool;
    };
  };

  # config = lib.mkIf sp.modules.nextcloud.enable
  config = lib.mkIf sp.modules.nextcloud.enable (lib.mkMerge [
    {
      fileSystems = lib.mkIf sp.useBinds {
        "/var/lib/nextcloud" = {
          device = "/volumes/${cfg.location}/nextcloud";
          options = [
            "bind"
            "x-systemd.required-by=nextcloud-setup.service"
            "x-systemd.required-by=nextcloud-secrets.service"
            "x-systemd.before=nextcloud-setup.service"
            "x-systemd.before=nextcloud-secrets.service"
          ];
        };
      };

      # for ExecStartPost script to have access to /run/keys/*
      users.groups.keys.members =
        lib.mkIf is-auth-enabled [ nextcloud-setup-group ];

      # not needed, due to turnOffCertCheck=1 in used_ldap
      # users.groups.${config.security.acme.certs.${domain}.group}.members =
      #   [ config.services.phpfpm.pools.nextcloud.user ];

      systemd = {
        services = {
          phpfpm-nextcloud.serviceConfig.Slice = lib.mkForce "nextcloud.slice";
          nextcloud-setup = {
            serviceConfig.Slice = "nextcloud.slice";
            serviceConfig.Group = config.services.phpfpm.pools.nextcloud.group;
          };
          kanidm.serviceConfig.ExecStartPre = lib.mkIf is-auth-enabled
            (lib.mkAfter [
              ("-+" + kanidmExecStartPreScriptRoot)
              ("-" + kanidmExecStartPreScript)
            ]);
          kanidm.serviceConfig.ExecStartPost = lib.mkIf is-auth-enabled
            (lib.mkAfter [ ("-" + kanidmExecStartPostScript) ]);
          nextcloud-cron.serviceConfig.Slice = "nextcloud.slice";
          nextcloud-update-db.serviceConfig.Slice = "nextcloud.slice";
          nextcloud-update-plugins.serviceConfig.Slice = "nextcloud.slice";
          nextcloud-secrets = {
            before = [ "nextcloud-setup.service" ];
            requiredBy = [ "nextcloud-setup.service" ];
            serviceConfig.Type = "oneshot";
            path = with pkgs; [ coreutils jq ];
            script = ''
              databasePassword=$(jq -re '.modules.nextcloud.databasePassword' ${secrets-filepath})
              adminPassword=$(jq -re '.modules.nextcloud.adminPassword' ${secrets-filepath})

              install -C -m 0440 -o nextcloud -g nextcloud -DT \
              <(printf "%s\n" "$databasePassword") \
              ${db-pass-filepath}

              install -C -m 0440 -o nextcloud -g nextcloud -DT \
              <(printf "%s\n" "$adminPassword") \
              ${admin-pass-filepath}
            '';
          };
        };
        slices.nextcloud = {
          description = "Nextcloud service slice";
        };
      };
      services.nextcloud = {
        enable = true;
        package = pkgs.nextcloud29;
        inherit hostName;

        # Use HTTPS for links
        https = true;

        # auto-update Nextcloud Apps
        autoUpdateApps.enable = true;
        # set what time makes sense for you
        autoUpdateApps.startAt = "05:00:00";

        phpOptions.display_errors = "Off";

        settings = {
          # further forces Nextcloud to use HTTPS
          overwriteprotocol = "https";
        } // lib.attrsets.optionalAttrs is-auth-enabled {
          loglevel = 0;
          # log_type = "file";
          social_login_auto_redirect = false;

          allow_local_remote_servers = true;
          allow_user_to_change_display_name = false;
          lost_password_link = "disabled";
          allow_multiple_user_backends = false;

          user_oidc = {
            single_logout = true;
            use_pkce = true;
            auto_provision = true;
            soft_auto_provision = true;
            disable_account_creation = false;
          };
        };

        config = {
          dbtype = "sqlite";
          dbuser = "nextcloud";
          dbname = "nextcloud";
          dbpassFile = db-pass-filepath;
          # TODO review whether admin user is needed at all - admin group works
          adminpassFile = admin-pass-filepath;
          adminuser = "admin";
        };

        secretFile = lib.mkIf is-auth-enabled nextcloud-secret-file;
      };
      services.nginx.virtualHosts.${hostName} = {
        useACMEHost = sp.domain;
        forceSSL = true;
        #locations."/".extraConfig = lib.mkIf is-auth-enabled ''
        #  # FIXME does not work
        #  rewrite ^/login$ /apps/user_oidc/login/1 last;
        #'';
        # show an error instead of a blank page on Nextcloud PHP/FastCGI error
        locations."~ \\.php(?:$|/)".extraConfig = ''
          error_page 500 502 503 504 ${pkgs.nginx}/html/50x.html;
        '';
      };
    }
    # the following part is active only when "auth" module is enabled
    (lib.mkIf is-auth-enabled {
      systemd.services.nextcloud-setup = {
        path = [ pkgs.jq ];
        script = ''
          set -o errexit
          set -o nounset
          ${lib.strings.optionalString cfg.debug "set -o xtrace"}

          ${occ} app:install user_ldap || :
          ${occ} app:enable  user_ldap

          # The following code tries to match an existing config or creates a new one.
          # The criteria for matching is the ldapHost value.

          # remove broken link after previous nextcloud (un)installation
          [[ ! -f "${override-config-fp}" && -L "${override-config-fp}" ]] && \
            rm -v "${override-config-fp}"

          ALL_CONFIG="$(${occ} ldap:show-config --output=json)"

          MATCHING_CONFIG_IDs="$(jq '[to_entries[] | select(.value.ldapHost=="${ldap_scheme_and_host}") | .key]' <<<"$ALL_CONFIG")"
          if [[ $(jq 'length' <<<"$MATCHING_CONFIG_IDs") > 0 ]]; then
            CONFIG_ID="$(jq --raw-output '.[0]' <<<"$MATCHING_CONFIG_IDs")"
          else
            CONFIG_ID="$(${occ} ldap:create-empty-config --only-print-prefix)"
          fi

          echo "Using configId $CONFIG_ID"

          # The following CLI commands follow
          # https://github.com/lldap/lldap/blob/main/example_configs/nextcloud.md#nextcloud-config--the-cli-way

          # StartTLS is not supported in Kanidm due to security risks, whereas
          # user_ldap doesn't support SASL. Importing certificate doesn't
          # help:
          # ${occ} security:certificates:import "${config.security.acme.certs.${domain}.directory}/cert.pem"
          ${occ} ldap:set-config "$CONFIG_ID" 'turnOffCertCheck' '1'

          ${occ} ldap:set-config "$CONFIG_ID" 'ldapHost' '${ldap_scheme_and_host}'
          ${occ} ldap:set-config "$CONFIG_ID" 'ldapPort' '${toString auth-passthru.ldap-port}'
          ${occ} ldap:set-config "$CONFIG_ID" 'ldapAgentName' 'dn=token'
          ${occ} ldap:set-config "$CONFIG_ID" 'ldapAgentPassword' "$(<${kanidm-service-account-token-fp})"
          ${occ} ldap:set-config "$CONFIG_ID" 'ldapBase' '${auth-passthru.ldap-base-dn}'
          ${occ} ldap:set-config "$CONFIG_ID" 'ldapBaseGroups' '${auth-passthru.ldap-base-dn}'
          ${occ} ldap:set-config "$CONFIG_ID" 'ldapBaseUsers' '${auth-passthru.ldap-base-dn}'
          ${occ} ldap:set-config "$CONFIG_ID" 'ldapEmailAttribute' 'mail'
          ${occ} ldap:set-config "$CONFIG_ID" 'ldapGroupFilter' \
                    '(&(class=group)(${wildcard-group})'
          ${occ} ldap:set-config "$CONFIG_ID" 'ldapGroupFilterGroups' \
                    '(&(class=group)(${wildcard-group}))'
          # ${occ} ldap:set-config "$CONFIG_ID" 'ldapGroupFilterObjectclass' \
          #           'groupOfUniqueNames'
          # ${occ} ldap:set-config "$CONFIG_ID" 'ldapGroupMemberAssocAttr' \
          #           'uniqueMember'
          ${occ} ldap:set-config "$CONFIG_ID" 'ldapLoginFilter' \
                    '(&(class=person)(memberof=${users-group})(uid=%uid))'
          ${occ} ldap:set-config "$CONFIG_ID" 'ldapLoginFilterAttributes' \
                    'uid'
          ${occ} ldap:set-config "$CONFIG_ID" 'ldapUserDisplayName' \
                    'displayname'
          ${occ} ldap:set-config "$CONFIG_ID" 'ldapUserFilter' \
                    '(&(class=person)(memberof=${users-group})(name=%s))'
          ${occ} ldap:set-config "$CONFIG_ID" 'ldapUserFilterMode' \
                    '1'
          ${occ} ldap:set-config "$CONFIG_ID" 'ldapUserFilterObjectclass' \
                    'person'

          ${occ} ldap:test-config -- "$CONFIG_ID"

          # delete all configs except "$CONFIG_ID"
          for configid in $(jq --raw-output "keys[] | select(. != \"$CONFIG_ID\")" <<<"$ALL_CONFIG"); do
            echo "Deactivating $configid"
            ${occ} ldap:set-config "$configid" 'ldapConfigurationActive' '0'
            echo "Deactivated $configid"
            echo "Deleting $configid"
            ${occ} ldap:delete-config "$configid"
            echo "Deleted $configid"
          done

          ${occ} ldap:set-config "$CONFIG_ID" 'ldapConfigurationActive' '1'

          ############################################################################
          # OIDC app
          ############################################################################
          ${occ} app:install user_oidc || :
          ${occ} app:enable  user_oidc

          ${occ} user_oidc:provider ${auth-passthru.oauth2-provider-name} \
          --clientid="${oauth-client-id}" \
          --clientsecret="$(<${kanidm-oauth-client-secret-fp})" \
          --discoveryuri="${auth-passthru.oauth2-discovery-url "nextcloud"}" \
          --unique-uid=0 \
          --scope="email openid profile" \
          --mapping-uid=preferred_username \
          --no-interaction \
          --mapping-groups=groups \
          --group-provisioning=1 \
          -vvv
        '';
        # TODO consider passing oauth consumer service to auth module instead
        after = [ auth-passthru.oauth2-systemd-service ];
        requires = [ auth-passthru.oauth2-systemd-service ];
      };
      services.kanidm.provision = {
        groups = {
          "${admins-group}".members = [ auth-passthru.admins-group ];
          "${users-group}".members =
            [ admins-group auth-passthru.full-users-group ];
        };
        systems.oauth2.${oauth-client-id} = {
          displayName = "Nextcloud";
          originUrl = "https://${cfg.subdomain}.${domain}/apps/user_oidc/code";
          originLanding = "https://${cfg.subdomain}.${domain}/";
          basicSecretFile = kanidm-oauth-client-secret-fp;
          # when true, name is passed to a service instead of name@domain
          preferShortUsername = true;
          allowInsecureClientDisablePkce = false;
          scopeMaps.${users-group} = [ "email" "openid" "profile" ];
          removeOrphanedClaimMaps = true;
          claimMaps.groups = {
            joinType = "array";
            valuesByGroup.${admins-group} = [ "admin" ];
          };
        };
      };
    })
  ]);
}
