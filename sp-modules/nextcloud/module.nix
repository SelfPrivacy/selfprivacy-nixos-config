{
  config,
  lib,
  pkgs,
  selfprivacy,
  ...
}:
let
  inherit (import ./common.nix config)
    admin-pass-filepath
    domain
    override-config-fp
    sp
    ;

  hostName = "${cfg.subdomain}.${sp.domain}";
  auth-passthru = config.selfprivacy.passthru.auth;
  deleteNextcloudAdmin = config.selfprivacy.workarounds.deleteNextcloudAdmin;
  cfg = sp.modules.nextcloud;
  ldap_scheme_and_host = "ldaps://${auth-passthru.ldap-host}";

  occ = "${config.services.nextcloud.occ}/bin/nextcloud-occ";

  linuxUserOfService = config.services.phpfpm.pools.nextcloud.user;
  linuxGroupOfService = config.services.phpfpm.pools.nextcloud.group;

  oauthClientID = "nextcloud";

  adminsGroup = "sp.${oauthClientID}.admins";
  usersGroup = "sp.${oauthClientID}.users";
  wildcardGroup = "sp.${oauthClientID}.*";

  serviceAccountTokenFP = auth-passthru.mkServiceAccountTokenFP linuxUserOfService;
  oauthClientSecretFP = auth-passthru.mkOAuth2ClientSecretFP linuxUserOfService;

  updater-page-substitute = pkgs.runCommand "nextcloud-updater-page-substitute" { } ''
    install -m644 ${./updater.html} -DT $out/index.html
  '';
in
{
  options.selfprivacy.modules.nextcloud = with lib; {
    enable = selfprivacy.types.enableOption "Nextcloud";
    location = selfprivacy.types.locationOption;
    subdomain = selfprivacy.types.subdomainOption "cloud";
    enableImagemagick =
      (lib.mkOption {
        type = types.bool;
        default = true;
        description = "Enable ImageMagick";
      })
      // {
        meta = {
          type = "bool";
          weight = 1;
        };
      };
    enableSambaFeatures =
      (lib.mkOption {
        type = types.bool;
        default = false;
        description = "Enable support for Samba/CIFS features";
      })
      // {
        meta = {
          type = "bool";
          weight = 2;
        };
      };
    debug =
      (lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Enable debug logging";
      })
      // {
        meta = {
          type = "bool";
          weight = 3;
        };
      };
    disableMaintenanceModeAtStart =
      (lib.mkOption {
        type = types.bool;
        default = false;
        description = "Disable maintenance mode at Nextcloud service startup";
      })
      // {
        meta = {
          type = "bool";
          weight = 4;
        };
      };
  };

  # config = lib.mkIf sp.modules.nextcloud.enable
  config = lib.mkIf sp.modules.nextcloud.enable (
    lib.mkMerge [
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
        users.groups.keys.members = [ linuxUserOfService ];

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
            nextcloud-cron.serviceConfig.Slice = "nextcloud.slice";
            nextcloud-update-db.serviceConfig.Slice = "nextcloud.slice";
            nextcloud-update-plugins.serviceConfig.Slice = "nextcloud.slice";
            nextcloud-secrets = {
              before = [ "nextcloud-setup.service" ];
              requiredBy = [ "nextcloud-setup.service" ];
              serviceConfig.Type = "oneshot";
              path = with pkgs; [
                coreutils
              ];
              script = ''
                if [ ! -f "${admin-pass-filepath}" ]; then
                  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32 > ${admin-pass-filepath}
                  chown nextcloud:nextcloud ${admin-pass-filepath}
                  chmod 440 ${admin-pass-filepath}
                fi
              '';
            };
          };
          slices.nextcloud = {
            description = "Nextcloud service slice";
          };
        };
        services.nextcloud = {
          enable = true;
          package = pkgs.nextcloud32;
          inherit hostName;

          # Use HTTPS for links
          https = true;

          # auto-update Nextcloud Apps
          autoUpdateApps.enable = true;
          # set what time makes sense for you
          autoUpdateApps.startAt = "05:00:00";

          phpOptions.display_errors = "Off";
          phpOptions."opcache.interned_strings_buffer" = "32";

          configureRedis = true;

          settings = {
            # further forces Nextcloud to use HTTPS
            overwriteprotocol = "https";

            loglevel = 0;
            # log_type = "file";
            social_login_auto_redirect = false;

            allow_local_remote_servers = true;
            allow_user_to_change_display_name = false;
            lost_password_link = "disabled";
            allow_multiple_user_backends = false;

            updatechecker = false; # nixpkgs handles updates for us, update via web ui will fail on nixos.

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
            # TODO review whether admin user is needed at all - admin group works
            adminpassFile = admin-pass-filepath;
            adminuser = "admin";
          };
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
          locations."^~ /updater/" = {
            alias = updater-page-substitute + "/";
            extraConfig = ''
              error_page 410 /index.html;
              # otherwise, nginx returns 405 for POST requests to static content
              error_page 405 =200 $uri;
            '';
          };
        };

        systemd.services.nextcloud-setup = {
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = "60";
          };
          path = [ pkgs.jq ];
          script = lib.mkMerge [
            (lib.strings.optionalString cfg.disableMaintenanceModeAtStart (
              lib.mkBefore "${occ} maintenance:mode --no-interaction --off"
            ))
            ''
              set -o errexit
              set -o nounset
              ${lib.strings.optionalString cfg.debug "set -o xtrace"}

              ${occ} app:disable logreader

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
              ${occ} ldap:set-config "$CONFIG_ID" 'ldapAgentPassword' "$(<${serviceAccountTokenFP})"
              ${occ} ldap:set-config "$CONFIG_ID" 'ldapBase' '${auth-passthru.ldap-base-dn}'
              ${occ} ldap:set-config "$CONFIG_ID" 'ldapBaseGroups' '${auth-passthru.ldap-base-dn}'
              ${occ} ldap:set-config "$CONFIG_ID" 'ldapBaseUsers' '${auth-passthru.ldap-base-dn}'
              ${occ} ldap:set-config "$CONFIG_ID" 'ldapEmailAttribute' 'mail'
              ${occ} ldap:set-config "$CONFIG_ID" 'ldapGroupFilter' \
                        '(&(class=group)(${wildcardGroup})'
              ${occ} ldap:set-config "$CONFIG_ID" 'ldapGroupFilterGroups' \
                        '(&(class=group)(${wildcardGroup}))'
              # ${occ} ldap:set-config "$CONFIG_ID" 'ldapGroupFilterObjectclass' \
              #           'groupOfUniqueNames'
              # ${occ} ldap:set-config "$CONFIG_ID" 'ldapGroupMemberAssocAttr' \
              #           'uniqueMember'
              ${occ} ldap:set-config "$CONFIG_ID" 'ldapLoginFilter' \
                        '(&(class=person)(memberof=${usersGroup})(uid=%uid))'
              ${occ} ldap:set-config "$CONFIG_ID" 'ldapLoginFilterAttributes' \
                        'uid'
              ${occ} ldap:set-config "$CONFIG_ID" 'ldapUserDisplayName' \
                        'displayname'
              ${occ} ldap:set-config "$CONFIG_ID" 'ldapUserFilter' \
                        '(&(class=person)(memberof=${usersGroup})(name=%s))'
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
              --clientid="${oauthClientID}" \
              --clientsecret="$(<${oauthClientSecretFP})" \
              --discoveryuri="${auth-passthru.oauth2-discovery-url "nextcloud"}" \
              --unique-uid=0 \
              --scope="email openid profile" \
              --mapping-uid=preferred_username \
              --no-interaction \
              --mapping-groups=groups \
              --group-provisioning=1 \
              -vvv

            ''
            (lib.optionalString deleteNextcloudAdmin ''
              if [[ ! -f /var/lib/nextcloud/.admin-user-deleted ]]; then
                ${occ} user:delete admin
                touch /var/lib/nextcloud/.admin-user-deleted
              fi
            '')
          ];
        };
        selfprivacy.auth.clients."${oauthClientID}" = {
          inherit adminsGroup usersGroup;
          imageFile = ./icon.svg;
          displayName = "Nextcloud";
          subdomain = cfg.subdomain;
          isTokenNeeded = true;
          originUrl = "https://${cfg.subdomain}.${domain}/apps/user_oidc/code";
          originLanding = "https://${cfg.subdomain}.${domain}/apps/user_oidc/login/1";
          useShortPreferredUsername = true;
          clientSystemdUnits = [
            "nextcloud-setup.service"
            "phpfpm-nextcloud.service"
          ];
          enablePkce = true;
          linuxUserOfClient = linuxUserOfService;
          linuxGroupOfClient = linuxGroupOfService;
          scopeMaps.${usersGroup} = [
            "email"
            "openid"
            "profile"
          ];
          claimMaps.groups = {
            joinType = "array";
            valuesByGroup.${adminsGroup} = [ "admin" ];
          };
        };
      }
      # enables samba features when requested
      (lib.mkIf cfg.enableSambaFeatures {
        # only apply cifs-utils package to this module
        services.phpfpm.pools.nextcloud.phpEnv.PATH =
          lib.mkForce "${pkgs.samba}/bin:${pkgs.cifs-utils}/bin:/run/wrappers/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin:/bin";
        systemd.services.nextcloud-cron.path = [
          pkgs.samba
          pkgs.cifs-utils
        ];
      })
    ]
  );
}
