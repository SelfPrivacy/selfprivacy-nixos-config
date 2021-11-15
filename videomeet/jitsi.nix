{ pkgs, config, ... }:
let
  domain = config.services.userdata.domain;
in
{
  services.jitsi-meet = {
    enable = config.services.userdata.jitsi.enable;
    hostName = "meet.${domain}";
    nginx.enable = false;
    interfaceConfig = {
      SHOW_JITSI_WATERMARK = false;
      SHOW_WATERMARK_FOR_GUESTS = false;
    };
  };
}
