{ lib, ... }:
{
  options.selfprivacy.modules.simple-nixos-mailserver = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
    };
    location = lib.mkOption {
      type = lib.types.str;
    };
  };
}
