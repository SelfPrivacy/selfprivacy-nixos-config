{ config, ... }:
{
  services.jitsi-meet = {
    enable = config.selfprivacy.userdata.jitsi.enable;
    hostName = "meet.${config.selfprivacy.userdata.domain}";
    nginx.enable = true;
    interfaceConfig = {
      SHOW_JITSI_WATERMARK = false;
      SHOW_WATERMARK_FOR_GUESTS = false;
    };
  };
}
