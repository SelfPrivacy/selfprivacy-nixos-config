{ config, lib, ... }:
let
  domain = config.selfprivacy.domain;
in
{
  options.selfprivacy.modules.jitsi-meet = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
    };
  };

  config = lib.mkIf config.selfprivacy.modules.jitsi-meet.enable {
    services.jitsi-meet = {
      enable = true;
      hostName = "meet.${domain}";
      nginx.enable = true;
      interfaceConfig = {
        SHOW_JITSI_WATERMARK = false;
        SHOW_WATERMARK_FOR_GUESTS = false;
      };
    };
    services.nginx.virtualHosts."meet.${domain}" = {
      forceSSL = true;
      useACMEHost = domain;
      enableACME = false;
    };
  };
}
