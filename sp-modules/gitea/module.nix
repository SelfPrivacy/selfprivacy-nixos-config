{ config, lib, pkgs, ... }:
let
  sp = config.selfprivacy;
  stateDir =
    if sp.useBinds
    then "/volumes/${cfg.location}/gitea"
    else "/var/lib/gitea";
  cfg = sp.modules.gitea;
  themes = [
    "forgejo-auto"
    "forgejo-light"
    "forgejo-dark"
    "gitea-auto"
    "gitea-light"
    "gitea-dark"
  ];
  is-auth-enabled = cfg.enableSso && config.selfprivacy.sso.enable;
  oauth-client-id = "forgejo";
  auth-passthru = config.selfprivacy.passthru.auth;
  oauth2-provider-name = auth-passthru.oauth2-provider-name;
  redirect-uri =
    "https://${cfg.subdomain}.${sp.domain}/user/oauth2/${oauth2-provider-name}/callback";

  admins-group = "sp.forgejo.admins";
  users-group = "sp.forgejo.users";

  kanidm-service-account-name = "sp.${oauth-client-id}.service-account";
  kanidm-service-account-token-name = "${oauth-client-id}-service-account-token";
  kanidm-service-account-token-fp =
    "/run/keys/${oauth-client-id}/kanidm-service-account-token"; # FIXME sync with auth module
  # TODO rewrite to tmpfiles.d
  kanidmExecStartPreScriptRoot = pkgs.writeShellScript
    "${oauth-client-id}-kanidm-ExecStartPre-root-script.sh"
    ''
      # set-group-ID bit allows kanidm user to create files with another group
      mkdir -p -v --mode=u+rwx,g+rs,g-w,o-rwx /run/keys/${oauth-client-id}
      chown kanidm:${config.services.forgejo.group} /run/keys/${oauth-client-id}
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
  options.selfprivacy.modules.gitea = {
    enable = (lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable Forgejo";
    }) // {
      meta = {
        type = "enable";
      };
    };
    location = (lib.mkOption {
      type = lib.types.str;
      description = "Forgejo location";
    }) // {
      meta = {
        type = "location";
      };
    };
    subdomain = (lib.mkOption {
      default = "git";
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
    appName = (lib.mkOption {
      default = "SelfPrivacy git Service";
      type = lib.types.str;
      description = "The name displayed in the web interface";
    }) // {
      meta = {
        type = "string";
        weight = 1;
      };
    };
    enableLfs = (lib.mkOption {
      default = true;
      type = lib.types.bool;
      description = "Enable Git LFS";
    }) // {
      meta = {
        type = "bool";
        weight = 2;
      };
    };
    forcePrivate = (lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Force all new repositories to be private";
    }) // {
      meta = {
        type = "bool";
        weight = 3;
      };
    };
    disableRegistration = (lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Disable registration of new users";
    }) // {
      meta = {
        type = "bool";
        weight = 4;
      };
    };
    requireSigninView = (lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Force users to log in to view any page";
    }) // {
      meta = {
        type = "bool";
        weight = 5;
      };
    };
    defaultTheme = (lib.mkOption {
      default = "forgejo-auto";
      type = lib.types.enum themes;
      description = "Default theme";
    }) // {
      meta = {
        type = "enum";
        options = themes;
        weight = 6;
      };
    };
    enableSso = (lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable SSO for Forgejo";
    }) // {
      meta = {
        type = "enable";
      };
    };
    debug = lib.mkOption {
      default = false;
      type = lib.types.bool;
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.enableSso -> sp.sso.enable;
          message =
            "SSO cannot be enabled for Forgejo when SSO is disabled globally.";
        }
      ];
      fileSystems = lib.mkIf sp.useBinds {
        "/var/lib/gitea" = {
          device = "/volumes/${cfg.location}/gitea";
          options = [ "bind" ];
        };
      };
      services.gitea.enable = false;
      services.forgejo = {
        enable = true;
        package = pkgs.forgejo;
        inherit stateDir;
        user = "gitea";
        group = "gitea";
        database = {
          type = "sqlite3";
          host = "127.0.0.1";
          name = "gitea";
          user = "gitea";
          path = "${stateDir}/data/gitea.db";
          createDatabase = true;
        };
        # ssh = {
        #   enable = true;
        #   clonePort = 22;
        # };
        lfs = {
          enable = cfg.enableLfs;
          contentDir = "${stateDir}/lfs";
        };
        repositoryRoot = "${stateDir}/repositories";
        #      cookieSecure = true;
        settings = {
          DEFAULT = {
            APP_NAME = "${cfg.appName}";
          };
          server = {
            DOMAIN = "${cfg.subdomain}.${sp.domain}";
            ROOT_URL = "https://${cfg.subdomain}.${sp.domain}/";
            HTTP_ADDR = "0.0.0.0";
            HTTP_PORT = 3000;
          };
          mailer = {
            ENABLED = false;
          };
          ui = {
            DEFAULT_THEME = cfg.defaultTheme;
            SHOW_USER_EMAIL = false;
          };
          picture = {
            DISABLE_GRAVATAR = true;
          };
          admin = {
            ENABLE_KANBAN_BOARD = true;
          };
          repository = {
            FORCE_PRIVATE = cfg.forcePrivate;
          };
          session = {
            COOKIE_SECURE = true;
          };
          log = {
            ROOT_PATH = "${stateDir}/log";
            LEVEL = if cfg.debug then "Warn" else "Trace";
          };
          service = {
            DISABLE_REGISTRATION = cfg.disableRegistration;
            REQUIRE_SIGNIN_VIEW = cfg.requireSigninView;
          };
        };
      };

      users.users.gitea = {
        home = "${stateDir}";
        useDefaultShell = true;
        group = "gitea";
        isSystemUser = true;
      };
      users.groups.gitea = { };
      services.nginx.virtualHosts."${cfg.subdomain}.${sp.domain}" = {
        useACMEHost = sp.domain;
        forceSSL = true;
        extraConfig = ''
          add_header Strict-Transport-Security $hsts_header;
          #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;
          add_header 'Referrer-Policy' 'origin-when-cross-origin';
          add_header X-Frame-Options DENY;
          add_header X-Content-Type-Options nosniff;
          add_header X-XSS-Protection "1; mode=block";
          proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
        '';
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:3000";
          };
        };
      };
      systemd = {
        services.forgejo = {
          unitConfig.RequiresMountsFor = lib.mkIf sp.useBinds "/volumes/${cfg.location}/gitea";
          serviceConfig = {
            Slice = "gitea.slice";
          };
        };
        slices.gitea = {
          description = "Forgejo service slice";
        };
      };
    }
    # the following part is active only when "auth" module is enabled
    (lib.mkIf is-auth-enabled {
      services.forgejo.settings = {
        auth.DISABLE_LOGIN_FORM = true;
        service = {
          DISABLE_REGISTRATION = cfg.disableRegistration;
          REQUIRE_SIGNIN_VIEW = cfg.requireSigninView;
          ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
          SHOW_REGISTRATION_BUTTON = false;
          ENABLE_BASIC_AUTHENTICATION = false;
        };

        # disallow explore page and access to private repositories, but allow public
        "service.explore".REQUIRE_SIGNIN_VIEW = true;

        # TODO control via selfprivacy parameter
        # "service.explore".DISABLE_USERS_PAGE = true;

        oauth2_client = {
          REDIRECT_URI = redirect-uri;
          ACCOUNT_LINKING = "auto";
          ENABLE_AUTO_REGISTRATION = true;
          OPENID_CONNECT_SCOPES = "email openid profile";
        };
        # doesn't work if LDAP auth source is not active!
        "cron.sync_external_users" = {
          ENABLED = true;
          RUN_AT_START = true;
          NOTICE_ON_SUCCESS = true;
        };
      };
      systemd.services.forgejo = {
        preStart =
          let
            exe = lib.getExe config.services.forgejo.package;
            # FIXME skip-tls-verify, bind-password
            ldapConfigArgs = ''
              --name LDAP \
              --active \
              --security-protocol LDAPS \
              --skip-tls-verify \
              --host '${auth-passthru.ldap-host}' \
              --port '${toString auth-passthru.ldap-port}' \
              --user-search-base '${auth-passthru.ldap-base-dn}' \
              --user-filter '(&(class=person)(memberof=${users-group})(name=%s))' \
              --admin-filter '(&(class=person)(memberof=${admins-group})' \
              --username-attribute name \
              --firstname-attribute name \
              --surname-attribute displayname \
              --email-attribute mail \
              --public-ssh-key-attribute sshPublicKey \
              --bind-dn 'dn=token' \
              --bind-password "$(cat ${kanidm-service-account-token-fp})" \
              --synchronize-users
            '';
            oauthConfigArgs = ''
              --name "${oauth2-provider-name}" \
              --provider openidConnect \
              --key forgejo \
              --secret "$(<${kanidm-oauth-client-secret-fp})" \
              --group-claim-name groups \
              --admin-group admins \
              --auto-discover-url '${auth-passthru.oauth2-discovery-url oauth-client-id}'
            '';
          in
          lib.mkAfter ''
            set -o xtrace

            # Check if LDAP is already configured
            ldap_line="$(${exe} admin auth list | grep LDAP | head -n 1)"

            if [[ -n "$ldap_line" ]]; then
              # update ldap config
              id="$(echo "$ldap_line" | ${pkgs.gawk}/bin/awk '{print $1}')"
              ${exe} admin auth update-ldap --id "$id" ${ldapConfigArgs}
            else
              # initially configure ldap
              ${exe} admin auth add-ldap ${ldapConfigArgs}
            fi

            oauth_line="$(${exe} admin auth list | grep "${oauth2-provider-name}" | head -n 1)"
            if [[ -n "$oauth_line" ]]; then
              id="$(echo "$oauth_line" | ${pkgs.gawk}/bin/awk '{print $1}')"
              ${exe} admin auth update-oauth --id "$id" ${oauthConfigArgs}
            else
              ${exe} admin auth add-oauth ${oauthConfigArgs}
            fi
          '';
        # TODO consider passing oauth consumer service to auth module instead
        after = [ auth-passthru.oauth2-systemd-service ];
        requires = [ auth-passthru.oauth2-systemd-service ];
      };

      # for ExecStartPost script to have access to /run/keys/*
      users.groups.keys.members = [ config.services.forgejo.group ];

      systemd.services.kanidm.serviceConfig.ExecStartPre = [
        ("-+" + kanidmExecStartPreScriptRoot)
        ("-" + kanidmExecStartPreScript)
      ];
      systemd.services.kanidm.serviceConfig.ExecStartPost =
        lib.mkAfter [ ("-" + kanidmExecStartPostScript) ];

      services.nginx.virtualHosts."${cfg.subdomain}.${sp.domain}" = {
        extraConfig = lib.mkAfter ''
          rewrite ^/user/login$ /user/oauth2/${oauth2-provider-name} last;
          # FIXME is it needed?
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        '';
      };

      services.kanidm.provision = {
        groups = {
          "${admins-group}".members = [ auth-passthru.admins-group ];
          "${users-group}".members =
            [ admins-group auth-passthru.full-users-group ];
        };
        systems.oauth2.forgejo = {
          displayName = "Forgejo";
          originUrl = redirect-uri;
          originLanding = "https://${cfg.subdomain}.${sp.domain}/";
          basicSecretFile = kanidm-oauth-client-secret-fp;
          # when true, name is passed to a service instead of name@domain
          preferShortUsername = true;
          allowInsecureClientDisablePkce = true; # FIXME is it needed?
          scopeMaps = {
            "${users-group}" = [
              "email"
              "openid"
              "profile"
            ];
          };
          removeOrphanedClaimMaps = true;
          # NOTE https://github.com/oddlama/kanidm-provision/issues/15
          # add more scopes when a user is a member of specific group
          # currently not possible due to https://github.com/kanidm/kanidm/issues/2882#issuecomment-2564490144
          # supplementaryScopeMaps."${admins-group}" =
          #   [ "read:admin" "write:admin" ];
          claimMaps.groups = {
            joinType = "array";
            valuesByGroup.${admins-group} = [ "admins" ];
          };
        };
      };
    })
  ]);
}
