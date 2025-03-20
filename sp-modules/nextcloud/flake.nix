{
  description = "PoC SP module for nextcloud";

  outputs = { self }: {
    nixosModules.default = _:
      { imports = [ ./module.nix ./cleanup-module.nix ]; };
    configPathsNeeded =
      builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
    meta = { lib, ... }: {
      spModuleSchemaVersion = 1;
      id = "nextcloud";
      name = "Nextcloud";
      description = "Nextcloud is a cloud storage service that offers a web interface and a desktop client.";
      svgIcon = builtins.readFile ./icon.svg;
      isMovable = true;
      isRequired = false;
      canBeBackedUp = true;
      backupDescription = "All the files and other data stored in Nextcloud.";
      systemdServices = [
        "phpfpm-nextcloud.service"
      ];
      folders = [
        "/var/lib/nextcloud"
      ];
      license = [
        lib.licenses.agpl3Plus
      ];
      homepage = "https://nextcloud.com/";
      sourcePage = "https://github.com/nextcloud";
      supportLevel = "normal";
      sso = {
        accessGroup = "sp.nextcloud.users";
        adminGroup = "sp.nextcloud.admins";
      };
    };
  };
}
