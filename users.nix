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
        openssh.authorizedKeys.keys = cfg.sshKeys;
      };
    } // builtins.listToAttrs (builtins.map
      (user: {
        name = "${user.username}";
        value = {
          isNormalUser = true;
          hashedPassword = user.hashedPassword;
          openssh.authorizedKeys.keys = (if user ? sshKeys then user.sshKeys else [ ]);
        };
      })
      cfg.users);
  };
}
