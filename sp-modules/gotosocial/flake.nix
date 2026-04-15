{
  description = "GoToSocial module";

  outputs =
    { ... }:
    {
      nixosModules.default = import ./module.nix;
      configPathsNeeded = builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
      meta =
        { lib, ... }:
        {
          spModuleSchemaVersion = 1;
          id = "gotosocial";
          name = "GoToSocial";
          description = "Fast, fun, ActivityPub server, powered by Go. Beta software.";
          user = "gotosocial";
          group = "gotosocial";
          svgIcon = builtins.readFile ./icon.svg;
          isMovable = true;
          isRequired = false;
          backupDescription = "Posts, users and user interactions.";
          systemdServices = [
            "gotosocial.service"
          ];
          folders = [
            "/var/lib/gotosocial"
          ];
          license = [
            lib.licenses.agpl3Only
          ];
          homepage = "https://gotosocial.org";
          sourcePage = "https://codeberg.org/superseriousbusiness/gotosocial";
          supportLevel = "experimental";
          sso = {
            userGroup = "sp.gotosocial.users";
            adminGroup = "sp.gotosocial.admins";
          };
        };
    };
}
