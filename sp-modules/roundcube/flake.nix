{
  description = "Roundcube is a web-based email client.";

  outputs = { self }: {
    nixosModules.default = import ./module.nix;
    configPathsNeeded =
      builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
    meta = { lib, ... }: {
      spModuleSchemaVersion = 1;
      id = "roundcube";
      name = "Roundcube";
      description = "Roundcube is an open source webmail software.";
      svgIcon = builtins.readFile ./icon.svg;
      isMovable = false;
      isRequired = false;
      canBeBackedUp = true;
      backupDescription = "Users' settings.";
      postgreDatabases = [
        "roundcube"
      ];
      systemdServices = [
        "phpfpm-roundcube.service"
      ];
      license = [
        lib.licenses.gpl3
      ];
      homepage = "https://roundcube.net/";
      sourcePage = "https://github.com/roundcube/roundcubemail";
      supportLevel = "normal";
      sso = {
        accessGroup = "sp.roundcube.users";
        adminGroup = "sp.roundcube.admins";
      };
    };
  };
}
