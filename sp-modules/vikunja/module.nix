latestPkgs: {
  config,
  lib,
  ...
}: let
  sp = config.selfprivacy;
  cfg = sp.modules.vikunja;
  oauthClientID = "vikunja";
  auth-passthru = config.selfprivacy.passthru.auth;
  oauth2-provider-name = auth-passthru.oauth2-provider-name;
  oauthDiscoveryURL = auth-passthru.oauth2-discovery-url oauthClientID;

  # SelfPrivacy uses SP Module ID to identify the group!
  usersGroup = "sp.vikunja.users";

  oauthClientSecretFP =
    auth-passthru.mkOAuth2ClientSecretFP oauthClientID;

  vikunjaPackage = latestPkgs.vikunja.overrideAttrs (old: {
    doCheck = false; # Tests are slow.
    patches =
      (old.patches or [])
      ++ [
        ./load-client-secret-from-env.patch
      ];
  });
in {
  options.selfprivacy.modules.vikunja = {
    enable =
      (lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Enable Vikunja";
      })
      // {
        meta = {
          type = "enable";
        };
      };
    location =
      (lib.mkOption {
        type = lib.types.str;
        description = "Vikunja location";
      })
      // {
        meta = {
          type = "location";
        };
      };
    subdomain =
      (lib.mkOption {
        default = "vikunja";
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
  };

  config =
    lib.mkIf cfg.enable
    {
      assertions = [
        {
          assertion = sp.sso.enable;
          message = "Vikunja cannot be enabled when SSO is disabled.";
        }
      ];

      fileSystems = lib.mkIf sp.useBinds {
        "/var/lib/vikunja" = {
          device = "/volumes/${cfg.location}/vikunja";
          options = ["bind"];
        };
      };

      users = {
        users.vikunja = {
          isSystemUser = true;
          group = "vikunja";
        };
        groups.vikunja = {};
      };

      services.postgresql = {
        ensureDatabases = ["vikunja"];
        ensureUsers = [
          {
            name = "vikunja";
            ensureDBOwnership = true;
          }
        ];
      };

      services.vikunja = {
        enable = true;
        package = vikunjaPackage;
        frontendScheme = "https";
        frontendHostname = "${cfg.subdomain}.${sp.domain}";
        port = 4835;

        database = {
          type = "postgres";
          host = "/run/postgresql";
        };

        settings = {
          service = {
            enableregistration = false;
            enabletotp = false;
            enableuserdeletion = true;
          };

          auth = {
            local.enabled = false;
            openid = {
              enabled = true;
              providers = [
                {
                  name = oauth2-provider-name;
                  authurl = lib.strings.removeSuffix "/.well-known/openid-configuration" oauthDiscoveryURL;
                  clientid = oauthClientID;
                  clientsecret = ""; # There's patch for our Vikunja to make it load client secret from environment variable.
                  scope = "openid profile email";
                }
              ];
            };
          };
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
            proxyPass = "http://127.0.0.1:4835";
          };
        };
      };

      systemd = {
        services.vikunja = {
          unitConfig.RequiresMountsFor = lib.mkIf sp.useBinds "/volumes/${cfg.location}/vikunja";
          serviceConfig = {
            Slice = "vikunja.slice";
            LoadCredential = "oauth2-secret:${oauthClientSecretFP}";
            DynamicUser = lib.mkForce false;
            User = "vikunja";
            Group = "vikunja";

            AmbientCapabilities = [""];

            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            NoNewPrivileges = true;
            PrivateDevices = true;
            PrivateTmp = true;

            PrivateUsers = true;
            ProcSubset = "pid";
            ProtectClock = true;
            ProtectControlGroups = true;
            ProtectHome = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;

            ProtectProc = "invisible";

            ProtectSystem = "strict";

            RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];

            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";

            RemoveIPC = true;

            SystemCallFilter = ["@system-service" "~@cpu-emulation" "~@debug" "~@keyring" "~@memlock" "~@obsolete" "~@privileged" "~@setuid"];
          };
          environment.SP_VIKUNJA_CLIENT_SECRET_PATH = "%d/oauth2-secret";
        };
        slices.vikunja = {
          description = "Vikunja service slice";
        };
      };

      selfprivacy.auth.clients.${oauthClientID} = {
        inherit usersGroup;
        subdomain = cfg.subdomain;
        isTokenNeeded = false;
        originLanding = "https://${cfg.subdomain}.${sp.domain}/";
        originUrl = "https://${cfg.subdomain}.${sp.domain}/auth/openid/${lib.strings.toLower oauth2-provider-name}";
        clientSystemdUnits = ["vikunja.service"];
        enablePkce = false;
        linuxUserOfClient = "vikunja";
        linuxGroupOfClient = "vikunja";
      };
    };
}
