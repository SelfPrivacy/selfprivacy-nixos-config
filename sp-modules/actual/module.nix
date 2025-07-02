{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Just for convenience, this module's config values
  sp = config.selfprivacy;
  cfg = sp.modules.actual;

  is-auth-enabled = cfg.enableSso && config.selfprivacy.sso.enable;
  oauthClientID = "actual";
  auth-passthru = config.selfprivacy.passthru.auth;
  full-domain = "https://${cfg.subdomain}.${sp.domain}";
  redirect-uri = "${full-domain}/openid/callback";
  landing-uri = "${full-domain}/login";
  oauthDiscoveryURL = auth-passthru.oauth2-discovery-url oauthClientID;
  adminsGroup = "sp.${oauthClientID}.admins";
  usersGroup = "sp.${oauthClientID}.users";

  linuxUserOfService = "actual";
  linuxGroupOfService = "actual";

  oauthClientSecretFP = auth-passthru.mkOAuth2ClientSecretFP linuxGroupOfService;
  oauthSecretDir = "/run/actual/shh";
  oauthSecretFile = "${oauthSecretDir}/totallynotasecretfile.env";
  # creates an env file with the oauth client secret and configures permissions for the actual user/group
  oauthClientInjectScript = pkgs.writeShellScript "inject-oidc-secrets" ''
    mkdir -p ${oauthSecretDir}
    echo "ACTUAL_OPENID_CLIENT_SECRET=$(<${oauthClientSecretFP})" > ${oauthSecretFile}
    chown actual:actual ${oauthSecretFile}
    chmod 600 ${oauthSecretFile}
  '';
in
{
  # Here go the options you expose to the user.
  options.selfprivacy.modules.actual = {
    # This is required and must always be named "enable"
    enable =
      (lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Enable the Actual Budget server";
      })
      // {
        meta = {
          type = "enable";
        };
      };
    # This is required if your service stores data on disk
    location =
      (lib.mkOption {
        type = lib.types.str;
        description = "Data location";
      })
      // {
        meta = {
          type = "location";
        };
      };
    # This is required if your service needs a subdomain
    subdomain =
      (lib.mkOption {
        default = "actual";
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
    # Other options, that user sees directly.
    # Refer to Module options reference to learn more.
    enableSso =
      (lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Enable Single Sign-On";
      })
      // {
        meta = {
          type = "bool";
          weight = 2;
        };
      };
    enableDebug =
      (lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Enable Debug Logging";
      })
      // {
        meta = {
          type = "bool";
          weight = 3;
        };
      };
  };

  # All your changes to the system must go to this config attrset.
  # It MUST use lib.mkIf with an enable option.
  # This makes sure your module only makes changes to the system
  # if the module is enabled.
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # prevent SSO from being enabled in the module config if SSO isn't available/is disabled
        assertions = [
          {
            assertion = cfg.enableSso -> sp.sso.enable;
            message = "SSO cannot be enabled for Actual when SSO is disabled globally.";
          }
        ];
        # If your service stores data on disk, you have to mount a folder
        # for this. useBinds is always true on modern SelfPrivacy installations
        # but we keep this mkIf to keep migration flow possible.
        fileSystems = lib.mkIf sp.useBinds {
          "/var/lib/actual" = {
            device = "/volumes/${cfg.location}/actual";
            # Make sure that your service does not start before folder mounts
            options = [
              "bind"
              "x-systemd.required-by=actual.service"
              "x-systemd.before=actual.service"
            ];
          };
        };

        # actual service config
        services.actual = {
          enable = true;
          settings = {
            port = 5006;
            # default to only password logins
            allowedLoginMethods = [ "password" ];
          };
        };
        # adding the user/group to be used by the service
        users = {
          users.actual = {
            isSystemUser = true;
            group = "actual";
          };
          groups.actual = {};
        };

        systemd = {
          services = {
            actual = {
              # extra guard against the service starting before the bind has been mounted
              unitConfig.RequiresMountsFor = lib.mkIf sp.useBinds "/volumes/${cfg.location}/actual";
              serviceConfig = {
                Slice = "actual.slice";
                # override dynamic user since service from nixpkgs enables by default, but it doesn't work in the selfprivacy environment
                DynamicUser = lib.mkForce false;
                # use service user
                User = "actual";
                # use service group
                Group = "actual";
              };
              environment = 
                # tell actual to log debug info to the console if option is enabled
                (lib.mkIf cfg.enableDebug {
                  DEBUG = "actual:config,actual-sensitive:config";
                }
              );
            };
          };
          # Define the slice itself
          slices.actual = {
            description = "Actual server service slice";
          };
        };

        # You can define a reverse proxy for your service like this
        services.nginx.virtualHosts."${cfg.subdomain}.${sp.domain}" = {
          useACMEHost = sp.domain;
          forceSSL = true;
          locations = {
            "/" = {
              proxyPass = "http://127.0.0.1:5006";
            };
          };
        };
      }
      # SSO config
      (lib.mkIf is-auth-enabled {
        services.actual = {
          settings = {
            # only permit openid logins
            allowedLoginMethods = lib.mkForce [ "openid" ];
            # default to openid if enabled
            loginMethod = "openid";
            # SSO config
            openId = {
              discoveryURL = oauthDiscoveryURL;
              client_id = oauthClientID;
              server_hostname = full-domain;
              authMethod = "openid";
            };
          };
        };
        systemd.services.actual = {
          serviceConfig={
            # run inject script with root privileges
            ExecStartPre = "+${oauthClientInjectScript}";
            # use the file generated by the inject script, even if it doesn't yet exist
            EnvironmentFile = "-${oauthSecretFile}";
            RuntimeDirectory = "actual";
          };
        };

        # OIDC for Actual is currently in beta and requires legacy cryptography algorithms
        services.kanidm.provision.systems.oauth2."${oauthClientID}".enableLegacyCrypto = true;
        # Configure the OIDC client
        selfprivacy.auth.clients."${oauthClientID}" = {
          inherit adminsGroup usersGroup;
          imageFile = ./icon-lg.svg;
          displayName = "Actual";
          subdomain = cfg.subdomain;
          originLanding = landing-uri;
          originUrl = redirect-uri;
          clientSystemdUnits = [ "actual.service" ];
          enablePkce = true;
          linuxUserOfClient = linuxUserOfService;
          linuxGroupOfClient = linuxGroupOfService;
          useShortPreferredUsername = true;
          scopeMaps.${usersGroup} = [ "email" "openid" "profile" ];
        };
      })
    ]
  );

}
