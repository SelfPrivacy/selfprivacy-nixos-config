{
  description = "PoC SP module for Pleroma lightweight fediverse server";

  outputs =
    { self }:
    {
      nixosModules.default = import ./module.nix;
      configPathsNeeded = builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
      meta =
        { lib, ... }:
        {
          spModuleSchemaVersion = 1;
          id = "pleroma";
          name = "Pleroma";
          description = "Pleroma is a microblogging service that offers a web interface and a desktop client.";
          svgIcon = builtins.readFile ./icon.svg;
          isMovable = true;
          isRequired = false;
          canBeBackedUp = true;
          backupDescription = "Your Pleroma accounts, posts and media.";
          systemdServices = [
            "pleroma.service"
          ];
          folders = [
            "/var/lib/pleroma"
          ];
          postgreDatabases = [
            "pleroma"
          ];
          license = [
            lib.licenses.agpl3Only
          ];
          homepage = "https://pleroma.social/";
          sourcePage = "https://git.pleroma.social/pleroma/pleroma";
          supportLevel = "deprecated";
        };
    };
}
