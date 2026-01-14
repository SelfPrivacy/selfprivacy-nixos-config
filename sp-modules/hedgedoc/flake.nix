{
  description = "HedgeDoc module";

  outputs =
    { ... }:
    {
      nixosModules.default = import ./module.nix;
      configPathsNeeded = builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
      meta =
        { lib, ... }:
        {
          spModuleSchemaVersion = 1;
          id = "hedgedoc";
          name = "HedgeDoc";
          description = "HedgeDoc is an open-source, web-based, self-hosted, collaborative markdown editor.";
          svgIcon = builtins.readFile ./icon.svg;
          isMovable = true;
          isRequired = false;
          backupDescription = "Notes and attachments.";
          systemdServices = [
            "hedgedoc.service"
          ];
          folders = [
            "/var/lib/hedgedoc"
          ];
          postgreDatabases = [
            "hedgedoc"
          ];
          license = [
            lib.licenses.agpl3Only
          ];
          homepage = "https://hedgedoc.org";
          sourcePage = "https://github.com/hedgedoc/hedgedoc";
          supportLevel = "normal";
          sso = {
            userGroup = "sp.hedgedoc.users";
          };
        };
    };
}
