{ lib, ... }:
{
  options.selfprivacy.modules.simple-nixos-mailserver = {
    enable = (lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable mail server";
    }) // {
      meta = {
        type = "enable";
      };
    };
    location = (lib.mkOption {
      type = lib.types.str;
      description = "Location";
    }) // {
      meta = {
        type = "location";
      };
    };
    enableSso = (lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable SSO for mail server";
    }) // {
      meta = {
        type = "enable";
      };
    };
  };
}
