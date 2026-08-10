{
  description = "PoC SP module for Vikunja service";

  outputs =
    { ... }:
    {
      nixosModules.default = import ./module.nix;

      meta =
        { lib, ... }:
        {
          spModuleSchemaVersion = 1;
          id = "vikunja";
          name = "Vikunja";
          description = "Vikunja, the fluffy, open-source, self-hostable to-do app.";
          svgIcon = builtins.readFile ./icon.svg;
          isMovable = true;
          isRequired = false;
          backupDescription = "Tasks and attachments.";
          systemdServices = [
            "vikunja.service"
          ];
          folders = [
            "/var/lib/vikunja"
          ];
          postgreDatabases = [
            "vikunja"
          ];
          license = [
            lib.licenses.agpl3Plus
          ];
          homepage = "https://vikunja.io";
          sourcePage = "https://github.com/go-vikunja/vikunja";
          supportLevel = "normal";
          sso = {
            userGroup = "sp.vikunja.users";
          };
        };
    };
}
