{
  config,
  lib,
  pkgs,
  ...
}:
let
  sp = config.selfprivacy;
  cfg = sp.modules.gotosocial;
  oauthClientID = "gotosocial";
  auth-passthru = config.selfprivacy.passthru.auth;
  oauth2-provider-name = auth-passthru.oauth2-provider-name;
  oauthDiscoveryURL = auth-passthru.oauth2-discovery-url oauthClientID;
  oauthClientSecretFP = auth-passthru.mkOAuth2ClientSecretFP oauthClientID;

in
{
  options.selfprivacy.modules.gotosocial = {
    enable =
      (lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Enable GoToSocial";
      })
      // {
        meta = {
          type = "enable";
        };
      };
    location =
      (lib.mkOption {
        type = lib.types.str;
        description = "GoToSocial location";
      })
      // {
        meta = {
          type = "location";
        };
      };
    subdomain =
      (lib.mkOption {
        default = "gts";
        type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
        description = "Subdomain";
      })
      // {
        meta = {
          widget = "subdomain";
          type = "string";
          regex = "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
          weight = 0;
        };
      };

    appName =
      (lib.mkOption {
        default = "GoToSocial";
        type = lib.types.str;
        description = "Name of the GoToSocial instance";
      })
      // {
        meta = {
          type = "string";
          weight = 1;
        };
      };
  };

  config = lib.mkIf cfg.enable {
    fileSystems = lib.mkIf sp.useBinds {
      "/var/lib/gotosocial" = {
        device = "/volumes/${cfg.location}/gotosocial";
        options = [ "bind" ];
      };
    };

    users = {
      users.gotosocial = {
        isSystemUser = true;
        group = "gotosocial";
      };
      groups.gotosocial = { };
    };

    systemd.services.gotosocial = {
      environment.GTS_WAZERO_COMPILATION_CACHE = "/var/lib/gotosocial/wazerocache";
      wants = [ "kanidm.service" ];
      after = [ "kanidm.service" ];
      serviceConfig = {
        # - is required because file doesn't exist on first start, as its populated by ExecStartPre.
        EnvironmentFile = lib.mkForce "-/var/lib/gotosocial/env";
        ExecStartPre = "+${pkgs.writeShellScript "gts-read-oidc-client-secret" ''
          echo -n "GTS_OIDC_CLIENT_SECRET=" > /var/lib/gotosocial/env
          cat ${oauthClientSecretFP} >> /var/lib/gotosocial/env
          chown gotosocial:gotosocial /var/lib/gotosocial/env
          chmod 640  /var/lib/gotosocial/env
        ''}";
      };
    };

    services.gotosocial = {
      enable = true;
      setupPostgresqlDB = true;
      settings = {
        application-name = cfg.appName;
        host = "${cfg.subdomain}.${sp.domain}";
        port = 4935;

        oidc-enabled = true;
        oidc-idp-name = oauth2-provider-name;
        oidc-issuer = lib.strings.removeSuffix "/.well-known/openid-configuration" oauthDiscoveryURL;
        oidc-client-id = "gotosocial";
        oidc-scopes = [
          "openid"
          "email"
          "profile"
        ];
        oidc-admin-groups = [ "admin" ];
      };
    };

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
          proxyPass = "http://127.0.0.1:4935";
        };
      };
    };

    selfprivacy.auth.clients.${oauthClientID} = {
      usersGroup = "sp.gotosocial.users";
      adminsGroup = "sp.gotosocial.admins";
      subdomain = cfg.subdomain;
      isTokenNeeded = false;
      originLanding = "https://${cfg.subdomain}.${sp.domain}/";
      originUrl = "https://${cfg.subdomain}.${sp.domain}/auth/callback";
      clientSystemdUnits = [ "gotosocial.service" ];
      enablePkce = false;
      linuxUserOfClient = "gotosocial";
      linuxGroupOfClient = "gotosocial";
      scopeMaps."sp.gotosocial.users" = [
        "email"
        "openid"
        "profile"
      ];
      claimMaps.groups = {
        joinType = "array";
        valuesByGroup."sp.gotosocial.admins" = [ "admin" ];
      };
    };
  };
}
