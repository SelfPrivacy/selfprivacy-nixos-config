{
  description = "PoC SP module for Gitea forge service";

  outputs = { self }: {
    nixosModules.default = import ./module.nix;
    configPathsNeeded =
      builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
    meta = { lib, ... }: {
      spModuleSchemaVersion = 1;
      id = "gitea";
      name = "Forgejo";
      description = "Forgejo is a Git forge.";
      svgIcon = builtins.readFile ./icon.svg;
      isMovable = true;
      isRequired = false;
      backupDescription = "Git repositories, database and user data.";
      systemdServices = [
        "forgejo.service"
      ];
      folders = [
        "/var/lib/gitea"
      ];
      license = [
        lib.licenses.gpl3Plus
      ];
      homepage = "https://forgejo.org";
      sourcePage = "https://codeberg.org/forgejo/forgejo";
      supportLevel = "normal";
      sso = {
        accessGroup = "sp.forgejo.users";
        adminGroup = "sp.forgejo.admins";
      };
    };
  };
}
