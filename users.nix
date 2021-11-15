{ pkgs, config, ... }:
let
  cfg = config.services.userdata;
in
{
  users.mutableUsers = false;
  users = {
    users = {
      "${cfg.username}" = {
        isNormalUser = true;
        hashedPassword = cfg.hashedMasterPassword;
      };
    } // builtins.listToAttrs (builtins.map
      (user: {
        name = "${user.username}";
        value = {
          isNormalUser = true;
          hashedPassword = user.hashedPassword;
        };
      })
      cfg.users);
  };
}
