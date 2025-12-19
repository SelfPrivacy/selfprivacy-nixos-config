{ config, lib, ... }:
let
  cfg = config.selfprivacy;
in
{
  config = lib.mkMerge [
    {
      users = {
        mutableUsers = false;
        allowNoPasswordLogin = true;
        users = builtins.listToAttrs (
          builtins.map (user: {
            name = "${user.username}";
            value = {
              isNormalUser = true;
              hashedPassword = user.hashedPassword;
              openssh.authorizedKeys.keys = (if user ? sshKeys then user.sshKeys else [ ]);
            };
          }) cfg.users
        );
      };
    }

    (lib.mkIf (!builtins.isNull cfg.username) {
      users.users = {
        "${cfg.username}" = {
          isNormalUser = true;
          hashedPassword = cfg.hashedMasterPassword;
          openssh.authorizedKeys.keys = cfg.sshKeys;
        };
      };
    })
  ];
}
