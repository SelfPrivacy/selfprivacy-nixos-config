{
  config,
  lib,
  pkgs,
  ...
}:
let
  sp = config.selfprivacy;
  cfg = sp.modules.matrix;
  oauthClientID = "matrix";
  auth-passthru = config.selfprivacy.passthru.auth;
  oauth2-provider-name = auth-passthru.oauth2-provider-name;
  oauthDiscoveryURL = auth-passthru.oauth2-discovery-url oauthClientID;

  # TODO: Make background in Element configurable. This will require new option type in the app.
  backgroundImage = builtins.fetchurl {
    url = "https://git.selfprivacy.org/SelfPrivacy/imagery/raw/commit/44004ccc4467e22f5d6014bbf6b10b28fb8d511a/social/mastodon_instance_cover.png";
    sha256 = "sha256-em9+IkG1OIgH6+Pi00dtrw1yfFp85X6LNsP5y/r/T7o=";
  };

  # SelfPrivacy uses SP Module ID to identify the group!
  adminsGroup = "sp.matrix.admins";
  usersGroup = "sp.matrix.users";

  serviceAccountFP = auth-passthru.mkServiceAccountTokenFP "matrix-authentication-service";
  oauthClientSecretFP = auth-passthru.mkOAuth2ClientSecretFP "matrix-authentication-service";

  synapseBase = "${cfg.subdomain}.${sp.domain}";
  synapseBaseURL = "https://" + synapseBase;

  clientConfig."m.homeserver" = {
    base_url = synapseBaseURL;
    server_name = sp.domain;
  };
  serverConfig."m.server" = "${synapseBase}:443";
  mkWellKnown = data: ''
    default_type application/json;
    add_header Access-Control-Allow-Origin *;
    add_header Strict-Transport-Security $hsts_header;
    add_header 'Referrer-Policy' 'origin-when-cross-origin';
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    return 200 '${builtins.toJSON data}';
  '';

  elementConfig = {
    default_server_config = clientConfig;
    disable_guests = true;
    disable_login_language_selector = false;
    default_country_code = "US";
    show_labs_settings = true;
    default_theme = "light";

    room_directory.servers = [
      "selfprivacy.org"
      "matrix.org"
    ];

    jitsi.preffered_domain = lib.mkIf config.services.jitsi-meet.enable "https://${config.services.jitsi-meet.hostName}";

    branding.welcome_background_url = "https://${cfg.elementSubdomain}.${sp.domain}/background.png";

    setting_defaults = {
      "UIFeature.feedback" = false;
      "UIFeature.passwordReset" = false;
      "UIFeature.deactivate" = false;
    };
  };

  yamlFormat = pkgs.formats.yaml { };

  kanidmUlid = "01G65Z755AFWAKHE12NY0CQ9FH";
  synapseUlid = "0000000000000000000SYNAPSE";
  masKanidmSyncClientId = "01JZQSK4HXHXR2QATT40Y7497J";

  masConfig = {
    policy.data.admin_clients = lib.singleton masKanidmSyncClientId;
    http = {
      public_base = "https://${cfg.masSubdomain}.${sp.domain}";

      listeners = [
        {
          name = "web";
          resources = [
            { name = "discovery"; }
            { name = "human"; }
            { name = "oauth"; }
            { name = "compat"; }
            { name = "graphql"; }
            { name = "adminapi"; }
            {
              name = "assets";
              path = "${pkgs.matrix-authentication-service}/share/matrix-authentication-service/assets";
            }
          ];

          binds = [
            {
              host = "127.0.0.1";
              port = 8068;
            }
          ];
          proxy_protocol = false;
        }
      ];
    };
    database = {
      uri = "postgresql:///matrix-authentication-service?host=/run/postgresql";
    };
    matrix = {
      homeserver = sp.domain;
      endpoint = "http://127.0.0.1:8078";
    };
    passwords = {
      enabled = true;
      schemes = [
        {
          version = 1;
          algorithm = "argon2id";
        }
      ];
    };
  };

  upstreamOauth2Template = pkgs.writeText "upstream_oauth2_template" (
    builtins.toJSON {
      id = kanidmUlid;
      issuer = lib.strings.removeSuffix "/.well-known/openid-configuration" oauthDiscoveryURL;
      token_endpoint_auth_method = "client_secret_basic";
      human_name = oauth2-provider-name;
      client_id = oauthClientID;
      scope = "openid email profile";
      pkce_method = "always";

      claims_imports.email.action = "force";
    }
  );

  experimentalMsc3861Template = pkgs.writeText "experimental_msc3861_template" (
    builtins.toJSON {
      enabled = true;
      issuer = "http://localhost:8068";
      client_id = synapseUlid;
      client_auth_method = "client_secret_basic";
    }
  );

  masConfigFile = yamlFormat.generate "config.yaml" masConfig;

  masCliWithConfigs = "${pkgs.matrix-authentication-service}/bin/mas-cli ${
    lib.concatMapStringsSep " " (x: "--config ${x}") [
      masConfigFile
      "${masDataDir}/secrets.yaml"
      "${masDataDir}/oauth2_secrets.yaml"
    ]
  }";

  masCliUserWrapper = pkgs.writeShellScriptBin "mas-cli" ''
    su matrix-authentication-service -s /bin/sh -c "${masCliWithConfigs} $*"
  '';

  synapseDataDir = "/var/lib/matrix-synapse";
  masDataDir = "/var/lib/matrix-authentication-service";

  # jitsi pollutes pkgs causing element-web to rebuild.
  element-web =
    (import config.nixpkgs.flake.source {
      system = pkgs.stdenv.hostPlatform.system;
    }).element-web.override
      {
        conf = elementConfig;
      };
in
{
  options.selfprivacy.modules.matrix = {
    enable =
      (lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Enable Matrix";
      })
      // {
        meta = {
          type = "enable";
        };
      };
    location =
      (lib.mkOption {
        type = lib.types.str;
        description = "Matrix location";
      })
      // {
        meta = {
          type = "location";
        };
      };

    subdomain =
      (lib.mkOption {
        default = "synapse";
        type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
        description = "Matrix server subdomain";
      })
      // {
        meta = {
          widget = "subdomain";
          type = "string";
          regex = "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
          weight = 0;
        };
      };

    elementSubdomain =
      (lib.mkOption {
        default = "element";
        type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
        description = "Element client subdomain";
      })
      // {
        meta = {
          widget = "subdomain";
          type = "string";
          regex = "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
          weight = 1;
        };
      };

    masSubdomain =
      (lib.mkOption {
        default = "mas";
        type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
        description = "Matrix Authentication Service subdomain";
      })
      // {
        meta = {
          widget = "subdomain";
          type = "string";
          regex = "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
          weight = 2;
        };
      };

    allowToPublishRoomsIntoDirectory =
      (lib.mkOption {
        default = false;
        description = "Allow all users to publish rooms into server room directory";
      })
      // {
        meta = {
          type = "bool";
          weight = 3;
        };
      };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.subdomain != cfg.elementSubdomain;
        message = "Element should be hosted on separate subdomain";
      }
      {
        assertion = cfg.subdomain != cfg.masSubdomain;
        message = "MAS should be hosted on separate subdomain";
      }
      {
        assertion = cfg.elementSubdomain != cfg.masSubdomain;
        message = "MAS should be hosted on separate subdomain, not on Element domain";
      }
      {
        assertion = sp.sso.enable;
        message = "Matrix cannot be enabled when SSO is disabled as Matrix uses OIDC for user authentication.";
      }
    ];

    fileSystems = lib.mkIf sp.useBinds {
      ${synapseDataDir} = {
        device = "/volumes/${cfg.location}/matrix-synapse";
        options = [ "bind" ];
      };
      ${masDataDir} = {
        device = "/volumes/${cfg.location}/matrix-authentication-service";
        options = [ "bind" ];
      };
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "matrix-authentication-service" ];
      ensureUsers = [
        {
          name = "matrix-synapse";
          ensureClauses.createdb = true;
        }
        {
          name = "matrix-authentication-service";
          ensureDBOwnership = true;
        }
      ];
    };

    services.matrix-synapse = {
      enable = true;
      extras = [ "oidc" ]; # add authlib to PYTHONPATH
      settings.server_name = sp.domain;
      settings.public_baseurl = synapseBaseURL;
      settings.allow_guest_access = false;
      settings.listeners = [
        {
          port = 8078;
          bind_addresses = [ "127.0.0.1" ];
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            {
              names = [
                "client"
                "federation"
              ];
              compress = true;
            }
          ];
        }
      ];
      settings.room_list_publication_rules = lib.mkIf cfg.allowToPublishRoomsIntoDirectory (
        lib.singleton {
          action = "allow";
        }
      );

      extraConfigFiles = [
        "${synapseDataDir}/mas_secrets.yaml"
      ];
    };

    services.nginx.virtualHosts.${sp.domain} = {
      locations."= /.well-known/matrix/server".extraConfig = mkWellKnown serverConfig;
      locations."= /.well-known/matrix/client".extraConfig = mkWellKnown clientConfig;
    };

    services.nginx.virtualHosts.${synapseBase} = {
      useACMEHost = sp.domain;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:8078";
      locations."= /.well-known/matrix/client".extraConfig = mkWellKnown clientConfig;
      locations."~ ^/_matrix/client/(.*)/(login|logout|refresh)".proxyPass = "http://127.0.0.1:8068";
    };

    services.nginx.virtualHosts."${cfg.masSubdomain}.${sp.domain}" = {
      useACMEHost = sp.domain;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:8068";
    };

    services.nginx.virtualHosts."${cfg.elementSubdomain}.${sp.domain}" = {
      useACMEHost = sp.domain;
      forceSSL = true;

      root = element-web;

      locations."= /.well-known/matrix/client".extraConfig = mkWellKnown clientConfig;
      locations."= /background.png" = {
        extraConfig = ''
          alias ${backgroundImage};
        '';
      };
    };

    users.users.matrix-authentication-service = {
      group = "matrix-authentication-service";
      isSystemUser = true;
    };
    users.groups.matrix-authentication-service = { };

    systemd = {
      services.matrix-authentication-service = {
        after = [
          "postgresql.service"
          "kanidm.service"
        ];
        wants = [
          "postgresql.service"
          "kanidm.service"
        ];
        wantedBy = [ "multi-user.target" ];
        path = [
          pkgs.matrix-authentication-service
          pkgs.yq
        ];
        serviceConfig = {
          Slice = "matrix.slice";
          User = "matrix-authentication-service";
          Group = "matrix-authentication-service";
          ExecStartPre = [
            (
              "+"
              + (pkgs.writeShellScript "matrix-authentication-service-prepare-secrets" ''
                set -eu

                mkdir -p ${synapseDataDir}
                mkdir -p ${masDataDir}
                if [ ! -f ${masDataDir}/sync-client-secret ]; then
                  SYNC_CLIENT_SECRET=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 50)
                  echo -n "$SYNC_CLIENT_SECRET" > ${masDataDir}/sync-client-secret
                fi
                if [ ! -f ${masDataDir}/matrix-token ]; then
                  MATRIX_TOKEN=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 50)
                  echo -n "$MATRIX_TOKEN" > ${masDataDir}/matrix-token
                fi
                if [ ! -f ${masDataDir}/secrets.yaml ]; then
                  mas-cli config generate > ${masDataDir}/secrets.yaml
                fi
                cat ${masDataDir}/secrets.yaml | yq --arg matrixtoken "$(cat ${masDataDir}/matrix-token)" --arg syncclientsecret "$(cat ${masDataDir}/sync-client-secret)" --slurpfile template ${experimentalMsc3861Template} '{
                  secrets: .secrets,
                  matrix: {secret: .matrix.secret},
                  clients: [
                    { client_id: "${synapseUlid}", client_auth_method: "client_secret_basic", client_secret: $matrixtoken },
                    { client_id: "${masKanidmSyncClientId}", client_auth_method: "client_secret_basic", client_secret: $syncclientsecret }
                  ]
                }' > ${masDataDir}/secrets.yaml
                cat ${upstreamOauth2Template} | yq --rawfile clientsecret ${oauthClientSecretFP} '{upstream_oauth2: {providers: [ . * {client_secret: $clientsecret}]}}' > ${masDataDir}/oauth2_secrets.yaml
                cat ${masDataDir}/secrets.yaml | yq --slurpfile template ${experimentalMsc3861Template} '{experimental_features: {msc3861: ($template[0] * {client_secret: .clients[0].client_secret, admin_token: .matrix.secret })}}' > ${synapseDataDir}/mas_secrets.yaml
                chown matrix-authentication-service:matrix-authentication-service ${masDataDir} -R
                chmod 640 ${masDataDir}/*
                chown matrix-synapse:matrix-synapse ${synapseDataDir}
                chown matrix-synapse:matrix-synapse ${synapseDataDir}/mas_secrets.yaml
                chmod 640 ${synapseDataDir}/mas_secrets.yaml
              '')
            )
          ];
          ExecStart = ''
            ${masCliWithConfigs} server
          '';
          Restart = "on-failure";
          RestartSec = "1s";
        };
      };
      services.matrix-synapse-prepare-db = {
        description = "Create Synapse database";
        after = [ "postgresql.service" ];
        requires = [ "postgresql.service" ];
        serviceConfig = {
          Slice = "matrix.slice";
          User = "postgres";
          Group = "postgres";
        };
        script = ''
          ${config.services.postgresql.package}/bin/psql -d postgres -f ${pkgs.writeText "create-synapse-db.sql" ''
            CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
              TEMPLATE template0
              LC_COLLATE = "C"
              LC_CTYPE = "C";
          ''} || true
        '';
      };
      services.mas-kanidm-sync = {
        after = [
          "matrix-authentication-service.service"
          "matrix-synapse-prepare-db.service"
          "kanidm.service"
        ];
        requires = [
          "kanidm.service"
          "matrix-authentication-service.service"
        ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          PYTHONUNBUFFERED = "1";
          KANIDM_TOKEN_PATH = "%d/kanidm-token";
          MAS_URL = "https://${cfg.masSubdomain}.${sp.domain}";
          KANIDM_URL = "https://auth.${sp.domain}";
          KANIDM_ULID = kanidmUlid;
          CLIENT_ID = masKanidmSyncClientId;
          CLIENT_SECRET_PATH = "%d/client-secret";
          MAS_POSTGRES_URL = "postgresql:///matrix-authentication-service?host=/run/postgresql";
        };
        serviceConfig = {
          Slice = "matrix.slice";
          User = "matrix-authentication-service";
          Group = "matrix-authentication-service";
          LoadCredential = ["kanidm-token:${serviceAccountFP}" "client-secret:${masDataDir}/sync-client-secret"];
          ExecStart = pkgs.writers.writePython3 "mas-kanidm-sync" {
            doCheck = false;
            libraries = with pkgs.python3Packages; [
              requests
              psycopg
              python-ulid
            ];
          } (builtins.readFile ./mas-kanidm-sync.py);
        };
      };
      services.matrix-synapse = {
        after = [
          "matrix-authentication-service.service"
          "matrix-synapse-prepare-db.service"
        ];
        wants = [
          "matrix-authentication-service.service"
        ];
        requires = [
          "matrix-synapse-prepare-db.service"
        ];
        unitConfig.RequiresMountsFor = lib.mkIf sp.useBinds "/volumes/${cfg.location}/matrix-synapse";
        serviceConfig.Slice = "matrix.slice";
      };
      slices.matrix = {
        description = "Matrix server";
      };
    };

    environment.systemPackages = [
      masCliUserWrapper
    ];

    selfprivacy.auth.clients.${oauthClientID} = {
      inherit adminsGroup usersGroup;
      subdomain = cfg.masSubdomain;
      isTokenNeeded = true;
      originLanding = "https://${cfg.masSubdomain}.${sp.domain}/";
      originUrl = "https://${cfg.masSubdomain}.${sp.domain}/upstream/callback/${kanidmUlid}";
      clientSystemdUnits = [ "matrix-authentication-service.service" ];
      enablePkce = true;
      linuxUserOfClient = "matrix-authentication-service";
      linuxGroupOfClient = "matrix-authentication-service";
    };

    services.kanidm.provision.systems.oauth2.${oauthClientID}.enableLegacyCrypto = true;
  };
}
