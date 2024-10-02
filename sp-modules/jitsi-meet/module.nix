{ config, lib, ... }:
let
  domain = config.selfprivacy.domain;
  cfg = config.selfprivacy.modules.jitsi-meet;
in
{
  options.selfprivacy.modules.jitsi-meet = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
    };
    subdomain = lib.mkOption {
      default = "meet";
      type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
    };
    appName = lib.mkOption {
      default = "Jitsi Meet";
      type = lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.permittedInsecurePackages = [
      "jitsi-meet-1.0.7952"
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
