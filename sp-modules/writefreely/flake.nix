{
  description = "WriteFreely module";

  outputs = { ... }:
    {
      nixosModules.default = import ./module.nix;
      configPathsNeeded = builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
      meta =
        { lib, ... }:
        {
          spModuleSchemaVersion = 1;
          id = "writefreely";
          name = "WriteFreely";
          description = "An open source platform for building your own blog on the web. Notice that the first signed in user will become the only admin automatically, and there is no possibility to change this.";
          user = "writefreely";
          group = "writefreely";
          svgIcon = builtins.readFile ./icon.svg;
          isMovable = true;
          isRequired = false;
          backupDescription = "Your articles and attachments.";
          systemdServices = [
            "writefreely.service"
          ];
          folders = [
            "/var/lib/writefreely"
          ];
          license = [
            lib.licenses.agpl3Only
          ];
          homepage = "https://writefreely.org";
          sourcePage = "https://github.com/writefreely/writefreely";
          supportLevel = "experimental";
          sso = {
            userGroup = "sp.writefreely.users";
          };
        };
    };
}
