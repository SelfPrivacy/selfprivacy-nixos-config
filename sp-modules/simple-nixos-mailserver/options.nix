{
  lib,
  selfprivacy,
  ...
}:
{
  options.selfprivacy.modules.simple-nixos-mailserver = {
    enable = selfprivacy.types.enableOption "mail server";
    location = selfprivacy.types.locationOption;
  };
}
