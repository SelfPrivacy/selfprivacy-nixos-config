{
  config,
  lib,
  selfprivacy,
  ...
}:
let
  domain = config.selfprivacy.domain;
  cfg = config.selfprivacy.modules.jitsi-meet;

  jitsiMeetModule =
    { pkgs, ... }@args:
    import "${selfprivacy.config.inputs.nixpkgs}/nixos/modules/services/web-apps/jitsi-meet.nix" (
      args
      // {
        pkgs = pkgs // {
          jitsi-meet = pkgs.jitsi-meet.overrideAttrs (old: {
            meta = old.meta // {
              # The insecure marking concerns libolm-based E2EE, which we disable.
              knownVulnerabilities = [ ];
            };
          });
        };
      }
    );
in
{
  disabledModules = [ "services/web-apps/jitsi-meet.nix" ];
  imports = [ jitsiMeetModule ];

  options.selfprivacy.modules.jitsi-meet = {
    enable = selfprivacy.types.enableOption "JitsiMeet";
    subdomain = selfprivacy.types.subdomainOption "meet";
    appName =
      (lib.mkOption {
        default = "Jitsi Meet";
        type = lib.types.str;
        description = "The name displayed in the web interface";
      })
      // {
        meta = {
          type = "string";
          weight = 1;
        };
      };
  };

  config = lib.mkIf cfg.enable {
    services.jitsi-meet = {
      enable = true;
      hostName = "${cfg.subdomain}.${domain}";
      nginx.enable = true;
      interfaceConfig = {
        SHOW_JITSI_WATERMARK = false;
        SHOW_WATERMARK_FOR_GUESTS = false;
        APP_NAME = cfg.appName;
      };
      config = {
        prejoinConfig = {
          enabled = true;
        };
        e2ee.disabled = true; # libolm is vulnerable and E2E is generally broken.
      };
    };
    services.prosody.extraConfig = ''
      log = {
        info = "*syslog";
      }
    '';
    services.nginx.virtualHosts."${cfg.subdomain}.${domain}" = {
      forceSSL = true;
      useACMEHost = domain;
      enableACME = false;
    };
    systemd = {
      services = {
        jicofo.serviceConfig.Slice = "jitsi_meet.slice";
        jitsi-videobridge2.serviceConfig.Slice = "jitsi_meet.slice";
        prosody.serviceConfig.Slice = "jitsi_meet.slice";
      };
      slices.jitsi_meet = {
        description = "Jitsi Meet service slice";
      };
    };
  };
}
