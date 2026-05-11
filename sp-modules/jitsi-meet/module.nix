{
  config,
  lib,
  pkgs,
  selfprivacy,
  ...
}:
let
  domain = config.selfprivacy.domain;
  cfg = config.selfprivacy.modules.jitsi-meet;
in
{
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
    nixpkgs.overlays = [
      (final: prev: {
        jitsi-meet = prev.jitsi-meet.overrideAttrs (old: {
          meta = old.meta // {
            # we disable e2ee.
            knownVulnerabilities = [ ];
          };
        });
      })
    ];
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
