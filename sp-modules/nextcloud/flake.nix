{
  description = "PoC SP module for nextcloud";

  outputs =
    { ... }:
    {
      nixosModules.default = import ./module.nix;
      configPathsNeeded = builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
      meta =
        { lib, ... }:
        {
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
            "redis-nextcloud.service"
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
            userGroup = "sp.nextcloud.users";
            adminGroup = "sp.nextcloud.admins";
          };
        };
    };
}
