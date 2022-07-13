{ config, pkgs, ... }:
{
  services.selfprivacy-api = {
    enable = true;
    token = config.services.userdata.api.token;
    enableSwagger = config.services.userdata.api.enableSwagger;
    b2Bucket = config.services.userdata.backblaze.bucket;
    resticPassword = config.services.userdata.resticPassword;
  };

  users.users."selfprivacy-api" = {
    isNormalUser = false;
    isSystemUser = true;
    extraGroups = [ "opendkim" ];
    group = "selfprivacy-api";
  };
  users.groups."selfprivacy-api" = {
    members = [ "selfprivacy-api" ];
  };
}
