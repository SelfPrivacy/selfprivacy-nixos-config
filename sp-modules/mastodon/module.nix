{
  config,
  lib,
  pkgs,
  selfprivacy,
  ...
}:
let
  sp = config.selfprivacy;
  cfg = sp.modules.mastodon;
  oauthClientID = "mastodon";
  auth-passthru = config.selfprivacy.passthru.auth;
  oauthDiscoveryURL = auth-passthru.oauth2-discovery-url oauthClientID;
  issuer = lib.strings.removeSuffix "/.well-known/openid-configuration" oauthDiscoveryURL;
  oauthRedirectURL = "https://${cfg.subdomain}.${sp.domain}/auth/auth/openid_connect/callback";

  usersGroup = "sp.mastodon.users";
  adminsGroup = "sp.mastodon.admins";

  oauthClientSecretFP = auth-passthru.mkOAuth2ClientSecretFP config.services.mastodon.group;
  serviceAccountFP = auth-passthru.mkServiceAccountTokenFP config.services.mastodon.group;
in
{
  options.selfprivacy.modules.mastodon = {
    enable = selfprivacy.types.enableOption "Mastodon";
    location = selfprivacy.types.locationOption;
    subdomain = selfprivacy.types.subdomainOption "mastodon" {
      option.description = "Subdomain (changing subdomain after setup will cause breakage)";
    };
    disallowUnauthenticatedAccess =
      (lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Disallow unauthenticated view of users and toots. Note that disallowing unauthenticated access will cause profile and post permalinks to return an error to logged-out users, essentially making it so that the only way to view content is to either log in locally or fetch it via ActivityPub.";
      })
      // {
        meta = {
          type = "bool";
          weight = 1;
        };
      };
  };

  config = lib.mkIf cfg.enable {
    fileSystems = lib.mkIf sp.useBinds {
      "/var/lib/mastodon" = {
        fsType = "auto";
        device = "/volumes/${cfg.location}/mastodon";
        options = [ "bind" ];
      };
    };

    security.sudo.enable = lib.mkForce true; # FIXME: mastodon-tootctl uses sudo.
    services.mastodon = {
      enable = true;
      localDomain = "${cfg.subdomain}.${sp.domain}";
      enableUnixSocket = false;
      configureNginx = true;
      streamingProcesses = 2; # TODO(nhnn): make configurable

      smtp = {
        createLocally = false;

        fromAddress = "noreply.mastodon@${sp.domain}";
        user = "noreply.mastodon@${sp.domain}";
        inherit (sp.emails."noreply.mastodon") passwordFile;
        authenticate = true;

        host = sp.domain;
        port = 587;
      };
      extraConfig = {
        "SMTP_ENABLE_STARTTLS_AUTO" = "true";
        "SMTP_ENABLE_STARTTLS" = "always";
        "SMTP_TLS" = "false";
        "SMTP_SSL" = "false";

        "DISALLOW_UNAUTHENTICATED_API_ACCESS" = lib.boolToString cfg.disallowUnauthenticatedAccess;
        "AUTHORIZED_FETCH" = "true";
      };
    };

    selfprivacy.emails."noreply.mastodon" = {
      systemdServices = [ "mastodon-init-dirs" ];
      inherit (config.services.mastodon) user group;
      sendOnly = true;
    };

    systemd = {
      services.mastodon-kanidm-sync = {
        after = [
          "kanidm.service"
          "mastodon-init-db.service"
        ];
        requires = [
          "kanidm.service"
          "mastodon-init-db.service"
        ];
        wantedBy = [ "multi-user.target" ];
        environment =
          let
            db = config.services.mastodon.database;
          in
          {
            KANIDM_URL = config.services.kanidm.server.settings.origin;
            KANIDM_TOKEN_PATH = serviceAccountFP;
            POSTGRES_DBNAME = db.name;
            POSTGRES_USER = db.user;
            POSTGRES_HOST = db.host;
            USER_ROLES_CACHE_PATH = "/var/lib/mastodon/user-roles-cache.json";
            PYTHONUNBUFFERED = "1";
          };
        serviceConfig = {
          Slice = "mastodon.slice";
          User = config.services.mastodon.user;
          Group = config.services.mastodon.group;
          Restart = "on-failure";
          RestartSec = 30;
          ExecStart = pkgs.writers.writePython3 "mastodon-kanidm-sync" {
            doCheck = false;
            libraries = with pkgs.python3Packages; [
              requests
              psycopg
            ];
          } (builtins.readFile ./mastodon-kanidm-sync.py);
        };
      };

      services.mastodon-web = {
        wants = [ "kanidm.service" ];
        after = [ "kanidm.service" ];
        unitConfig.RequiresMountsFor = lib.mkIf sp.useBinds "/volumes/${cfg.location}/mastodon";
        serviceConfig = {
          Slice = "mastodon.slice";
          LoadCredential = [ "client-secret:${oauthClientSecretFP}" ];
          ExecStart = lib.mkForce (
            pkgs.writeShellScript "run-mastodon-with-client-secret" ''
              export OIDC_CLIENT_SECRET=$(cat $CREDENTIALS_DIRECTORY/client-secret)
              ${config.services.mastodon.package}/bin/puma -C config/puma.rb
            ''
          );
        };
        environment = {
          OIDC_ENABLED = "true";
          OIDC_DISPLAY_NAME = "Kanidm";
          OIDC_ISSUER = issuer;
          OIDC_DISCOVERY = "true";
          OIDC_SCOPE = "openid,profile,email";
          OIDC_UID_FIELD = "preferred_username";
          OIDC_CLIENT_ID = oauthClientID;
          OIDC_REDIRECT_URI = oauthRedirectURL;
          OIDC_SECURITY_ASSUME_EMAIL_IS_VERIFIED = "false";
        };
      };

      slices.mastodon = {
        description = "Mastodon service slice";
      };
    };

    services.kanidm.provision.groups = {
      "sp.mastodon.owners".overwriteMembers = false;
      "${usersGroup}".members = [ "sp.mastodon.owners" ];
      "sp.mastodon.moderators" = { };
    };
    selfprivacy.auth.clients.${oauthClientID} = {
      inherit usersGroup;
      inherit adminsGroup;
      isTokenNeeded = true;
      serviceAccountGroups = [ "idm_people_pii_read" ];

      subdomain = cfg.subdomain;
      originLanding = "https://${cfg.subdomain}.${sp.domain}/";
      originUrl = oauthRedirectURL;
      clientSystemdUnits = [
        "mastodon-web.service"
        "mastodon-kanidm-sync.service"
      ];
      linuxUserOfClient = config.services.mastodon.user;
      linuxGroupOfClient = config.services.mastodon.group;
    };

    services.nginx.virtualHosts."${cfg.subdomain}.${sp.domain}" = {
      enableACME = false;
      useACMEHost = sp.domain;
    };
  };
}
