{
  description = "PoC SP module for Gitea forge service";

  outputs =
    { ... }:
    {
      nixosModules.default = import ./module.nix;

      meta =
        { lib, ... }:
        {
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
            userGroup = "sp.gitea.users";
            adminGroup = "sp.gitea.admins";
          };
        };
    };
}
