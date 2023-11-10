{ config, pkgs, ... }:
{
  services.selfprivacy-api = {
    enable = true;
    enableSwagger = config.selfprivacy.userdata.api.enableSwagger;
    b2Bucket = config.selfprivacy.userdata.backup.bucket;
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
