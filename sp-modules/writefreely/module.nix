{
  config,
  lib,
  pkgs,
  selfprivacy,
  ...
}:
let
  sp = config.selfprivacy;
  cfg = sp.modules.writefreely;

  oauthClientID = "writefreely";
  auth-passthru = config.selfprivacy.passthru.auth;
  oauth2-provider-origin = config.services.kanidm.server.settings.origin;
  usersGroup = "sp.writefreely.users";
  oauthClientSecretFP = auth-passthru.mkOAuth2ClientSecretFP oauthClientID;
in
{
  options.selfprivacy.modules.writefreely = {
    enable = selfprivacy.types.enableOption "WriteFreely";
    location = selfprivacy.types.locationOption;
    subdomain = selfprivacy.types.subdomainOption "writefreely" {
      option.description = "Subdomain (changing subdomain after enabling the federation will cause its breakage!)";
    };
    appName =
      (lib.mkOption {
        default = "WriteFreely";
        type = lib.types.str;
        description = "Name of the WriteFreely instance";
      })
      // {
        meta = {
          type = "string";
          weight = 1;
        };
      };
    description =
      (lib.mkOption {
        default = "";
        type = lib.types.str;
        description = "Description of the WriteFreely instance";
      })
      // {
        meta = {
          type = "string";
          weight = 2;
        };
      };
    enableFederation =
      (lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Enable ActivityPub federation";
      })
      // {
        meta = {
          type = "bool";
          weight = 3;
        };
      };
  };

  config = lib.mkIf cfg.enable {
    fileSystems = lib.mkIf sp.useBinds {
      "/var/lib/writefreely" = {
        fsType = "auto";
        device = "/volumes/${cfg.location}/writefreely";
        options = [ "bind" ];
      };
    };

    services.writefreely = {
      enable = true;
      database.type = "sqlite3";
      host = "${cfg.subdomain}.${sp.domain}";
      package = pkgs.callPackage ./package.nix { };
      settings = {
        server.port = 8081;
        app = {
          host = lib.mkForce "https://${cfg.subdomain}.${sp.domain}";
          site_name = cfg.appName;
          site_description = cfg.description;
          single_user = false;
          federation = cfg.enableFederation;
          disable_password_auth = true;
          open_registration = true;
        };

        "oauth.generic" = {
          client_id = oauthClientID;
          host = oauth2-provider-origin;
          display_name = "SSO";
          token_endpoint = "/oauth2/token";
          inspect_endpoint = "/oauth2/openid/${oauthClientID}/userinfo";
          auth_endpoint = "/ui/oauth2";
          client_secret = "@replace_oauth_secret@";
          map_user_id = "preferred_username";
          map_username = "preferred_username";
          scope = "openid email profile";
        };
      };
    };

    systemd = {
      services.writefreely = {
        requires = [ "writefreely-sqlite-init.service" ];
        path = [ pkgs.openssl ]; # OpenSSL is used by WriteFreely to generate ActivityPub federation key
        unitConfig.RequiresMountsFor = lib.mkIf sp.useBinds "/volumes/${cfg.location}/writefreely";
        serviceConfig.Slice = "writefreely.slice";
        restartTriggers = [
          (pkgs.writeText "writefreely-restart-trigger" (
            builtins.toJSON config.services.writefreely.settings
          ))
        ];
      };

      services.writefreely-sqlite-init =
        let
          cfgFile = "${config.services.writefreely.stateDir}/config.ini";
        in
        {
          postStart = ''
            chmod 660 '${cfgFile}'
            ${lib.getExe pkgs.replace-secret} "@replace_oauth_secret@" "${oauthClientSecretFP}" "${cfgFile}"
            chmod 440 '${cfgFile}'
          '';

          unitConfig.RequiresMountsFor = lib.mkIf sp.useBinds "/volumes/${cfg.location}/writefreely";
          serviceConfig = {
            Slice = "writefreely.slice";
            ExecStartPre = [
              "+${pkgs.coreutils}/bin/chown writefreely:writefreely /var/lib/writefreely"
            ];
          };
        };

      slices.writefreely = {
        description = "WriteFreely service slice";
      };
    };

    services.nginx.virtualHosts."${cfg.subdomain}.${sp.domain}" = {
      useACMEHost = sp.domain;
      forceSSL = true;
      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:8081";
        };
        "/auth/signup".extraConfig = "deny all;";
      };
    };

    selfprivacy.auth.clients.${oauthClientID} = {
      inherit usersGroup;
      subdomain = cfg.subdomain;
      originLanding = "https://${cfg.subdomain}.${sp.domain}/";
      originUrl = "https://${cfg.subdomain}.${sp.domain}/oauth/callback/generic";
      clientSystemdUnits = [ "writefreely-sqlite-init.service" ];
      enablePkce = false;
      scopeMaps = {
        "${usersGroup}" = [
          "email"
          "openid"
          "profile"
        ];
      };
      linuxUserOfClient = "writefreely";
      linuxGroupOfClient = "writefreely";
    };
  };
}
