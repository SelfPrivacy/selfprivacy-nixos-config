{ config, pkgs, ... }:
{
  services.selfprivacy-api = {
    enable = true;
    token = config.services.userdata.api.token;
    enableSwagger = config.services.userdata.api.enableSwagger;
    b2AccountId = config.services.userdata.backblaze.accountId;
    b2AccountKey = config.services.userdata.backblaze.accountKey;
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
