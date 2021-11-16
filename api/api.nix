{ config, pkgs, ... }:
{
  services.selfprivacy-api = {
    enable = true;
    token = config.services.userdata.api.token;
  };

  users.users."selfprivacy-api" = {
    isNormalUser = false;
    isSystemUser = true;
    extraGroups = [ "opendkim" ];
  };
  users.groups."selfprivacy-api" = {
    members = [ "selfprivacy-api" ];
  };
}
