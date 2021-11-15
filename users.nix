{ pkgs, config, ... }:
{
  users.mutableUsers = false;
  users = {
    users = {
      "${config.services.userdata.username}" = {
        isNormalUser = true;
        hashedPassword = config.services.userdata.hashedMasterPassword;
      };
    };
  };
}
