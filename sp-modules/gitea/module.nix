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
  oauthClientID = "forgejo";
  auth-passthru = config.selfprivacy.passthru.auth;
  oauth2-provider-name = auth-passthru.oauth2-provider-name;
  redirect-uri =
    "https://${cfg.subdomain}.${sp.domain}/user/oauth2/${oauth2-provider-name}/callback";
  oauthDiscoveryURL = auth-passthru.oauth2-discovery-url oauthClientID;

  # SelfPrivacy uses SP Module ID to identify the group!
  adminsGroup = "sp.gitea.admins";
  usersGroup = "sp.gitea.users";

  linuxUserOfService = "gitea";
  linuxGroupOfService = "gitea";
  forgejoPackage = pkgs.forgejo;

  serviceAccountTokenFP =
    auth-passthru.mkServiceAccountTokenFP oauthClientID;
  oauthClientSecretFP =
    auth-passthru.mkOAuth2ClientSecretFP oauthClientID;
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
      description = "Enable Single Sign-On";
    }) // {
      meta = {
        type = "bool";
        weight = 7;
      };
    };
    debug = (lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable debug logging";
    }) // {
      meta = {
        type = "bool";
        weight = 8;
      };
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
        package = forgejoPackage;
        inherit stateDir;
        user = linuxUserOfService;
        group = linuxGroupOfService;
        database = {
          type = "sqlite3";
          host = "127.0.0.1";
          name = "gitea";
          user = linuxUserOfService;
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
        group = linuxGroupOfService;
        isSystemUser = true;
      };
      users.groups.${linuxGroupOfService} = { };
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
    # the following part is active only when enableSso = true
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
            waitForURL = url: maxRetries: delaySec: ''
              for ((i=1; i<=${toString maxRetries}; i++))
              do
                  if ${lib.getExe pkgs.curl} -X GET --silent --fail "${url}" > /dev/null
                  then
                      echo "${url} responds to GET HTTP request (attempt #$i)"
                      exit 0
                  else
                      echo "${url} does not respond to GET HTTP request (attempt #$i)"
                      echo sleeping for ${toString delaySec} seconds
                  fi
                  sleep ${toString delaySec}
              done
              echo "error, max attempts to access "${url}" have been used unsuccessfully!"
              exit 124
            '';

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
              --user-filter '(&(class=person)(memberof=${usersGroup})(name=%s))' \
              --admin-filter '(&(class=person)(memberof=${adminsGroup})' \
              --username-attribute name \
              --firstname-attribute name \
              --surname-attribute displayname \
              --email-attribute mail \
              --public-ssh-key-attribute sshPublicKey \
              --bind-dn 'dn=token' \
              --bind-password "$(< ${serviceAccountTokenFP})" \
              --synchronize-users
            '';
            oauthConfigArgs = ''
              --name "${oauth2-provider-name}" \
              --provider openidConnect \
              --key forgejo \
              --secret "$(< ${oauthClientSecretFP})" \
              --group-claim-name groups \
              --admin-group admins \
              --auto-discover-url '${oauthDiscoveryURL}'
            '';
          in
          lib.mkMerge [
            (waitForURL oauthDiscoveryURL 10 10)
            (lib.mkAfter ''
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
            '')
          ];
      };

      services.nginx.virtualHosts."${cfg.subdomain}.${sp.domain}" = {
        extraConfig = lib.mkAfter ''
          rewrite ^/user/login$ /user/oauth2/${oauth2-provider-name} last;
          # FIXME is it needed?
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        '';
      };

      selfprivacy.auth.clients."${oauthClientID}" = {
        inherit adminsGroup usersGroup;
        imageFile = "${pkgs.forgejo.data}/public/assets/img/logo.svg";
        subdomain = cfg.subdomain;
        isTokenNeeded = true;
        originLanding =
          "https://${cfg.subdomain}.${sp.domain}/user/login?redirect_to=%2f";
        originUrl = redirect-uri;
        clientSystemdUnits = [ "forgejo.service" ];
        enablePkce = false; # FIXME maybe Forgejo supports PKCE?
        linuxUserOfClient = linuxUserOfService;
        linuxGroupOfClient = linuxGroupOfService;
        claimMaps.groups = {
          joinType = "array";
          valuesByGroup.${adminsGroup} = [ "admins" ];
        };
      };
    })
  ]);
}
