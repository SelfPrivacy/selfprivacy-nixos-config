{
  config,
  lib,
  pkgs,
  selfprivacy,
  ...
}:
let
  sp = config.selfprivacy;
  cfg = sp.modules.hedgedoc;

  oauthClientID = "hedgedoc";
  auth-passthru = config.selfprivacy.passthru.auth;
  oauth2-provider-origin = config.services.kanidm.server.settings.origin;
  usersGroup = "sp.hedgedoc.users";
  oauthClientSecretFP = auth-passthru.mkOAuth2ClientSecretFP oauthClientID;

  secretsDir = "/run/keys/hedgedoc";
  envFile = "${secretsDir}/oauth-clientsecret.env";
in
{
  options.selfprivacy.modules.hedgedoc = {
    enable = selfprivacy.types.enableOption "HedgeDoc";
    location = selfprivacy.types.locationOption;
    subdomain = selfprivacy.types.subdomainOption "hedgedoc";
    allowAnonymous =
      (lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Allow usage (e.g., notes creation) without an account";
      })
      // {
        meta = {
          type = "bool";
          weight = 1;
        };
      };
    allowLibravatar =
      (lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Use Libravatar as profile picture source";
      })
      // {
        meta = {
          type = "bool";
          weight = 2;
        };
      };
  };

  config = lib.mkIf cfg.enable {
    fileSystems = lib.mkIf sp.useBinds {
      "/var/lib/hedgedoc" = {
        device = "/volumes/${cfg.location}/hedgedoc";
        options = [ "bind" ];
      };
    };

    services.postgresql = {
      ensureDatabases = [ "hedgedoc" ];
      ensureUsers = [
        {
          name = "hedgedoc";
          ensureDBOwnership = true;
        }
      ];
    };

    services.hedgedoc = {
      enable = true;
      environmentFile = envFile;

      settings = {
        port = 3001;
        protocolUseSSL = true;
        useSSL = false;
        domain = "${cfg.subdomain}.${sp.domain}";
        host = "127.0.0.1";

        # HedgeDoc saves the old option name for compatibility, even though it fetches avatars from Libravatar
        allowGravatar = cfg.allowLibravatar;

        db = {
          username = "hedgedoc";
          database = "hedgedoc";
          host = "/run/postgresql";
          dialect = "postgresql";
        };
        uploadsPath = "/var/lib/hedgedoc/uploads";

        allowEmailRegister = false;
        email = false;
        allowAnonymous = cfg.allowAnonymous;

        oauth2 = {
          baseURL = oauth2-provider-origin;
          clientID = "hedgedoc";
          authorizationURL = "${oauth2-provider-origin}/ui/oauth2";
          tokenURL = "${oauth2-provider-origin}/oauth2/token";
          userProfileURL = "${oauth2-provider-origin}/oauth2/openid/${oauthClientID}/userinfo";
          scope = "openid email profile";
          userProfileUsernameAttr = "sub";
          userProfileDisplayNameAttr = "name";
          userProfileEmailAttr = "email";
        };

        loglevel = "error";
      };
    };

    services.nginx.virtualHosts."${cfg.subdomain}.${sp.domain}" = {
      useACMEHost = sp.domain;
      forceSSL = true;
      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:3001";
          proxyWebsockets = true;
        };
      };
    };

    systemd = {
      services.hedgedoc-secrets =
        let
          hedgedoc-service-config = config.systemd.services.hedgedoc.serviceConfig;
        in
        {
          enable = true;
          wantedBy = [
            "multi-user.target"
            "hedgedoc.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "gen-hedgedoc-oauth2clientsecret-envfile" ''
              mkdir -p ${secretsDir} || true
              echo "CMD_OAUTH2_CLIENT_SECRET=$(cat ${oauthClientSecretFP})" > ${envFile}
              chmod 400 ${envFile}
              chown ${hedgedoc-service-config.User}:${hedgedoc-service-config.Group} ${envFile}
            '';
          };
        };
      services.hedgedoc = {
        wants = [ "hedgedoc-secrets.service" ];
        unitConfig.RequiresMountsFor = lib.mkIf sp.useBinds "/volumes/${cfg.location}/hedgedoc";
        serviceConfig.Slice = "hedgedoc.slice";
      };
      slices.hedgedoc = {
        description = "HedgeDoc service slice";
      };
    };

    selfprivacy.auth.clients.${oauthClientID} = {
      inherit usersGroup;
      subdomain = cfg.subdomain;
      originLanding = "https://${cfg.subdomain}.${sp.domain}/";
      originUrl = "https://${cfg.subdomain}.${sp.domain}/auth/oauth2/callback";
      clientSystemdUnits = [ "hedgedoc.service" ];
      enablePkce = false;
      linuxUserOfClient = "hedgedoc";
      linuxGroupOfClient = "hedgedoc";
    };
  };
}
