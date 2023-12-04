{ config, lib, ... }:
{
  options.selfprivacy.modules.jitsi-meet = {
    enable = lib.mkOption {
      default = false;
      type = with lib.types; nullOr bool;
    };
  };

  config = lib.mkIf config.selfprivacy.modules.jitsi-meet.enable {
    services.jitsi-meet = {
      enable = true;
      hostName = "meet.${config.selfprivacy.domain}";
      nginx.enable = true;
      interfaceConfig = {
        SHOW_JITSI_WATERMARK = false;
        SHOW_WATERMARK_FOR_GUESTS = false;
      };
    };
  };
}
