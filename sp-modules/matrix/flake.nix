{
  description = "PoC SP module for Matrix service";

  outputs =
    { ... }:
    {
      nixosModules.default = import ./module.nix;
      configPathsNeeded = builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
      meta =
        { lib, ... }:
        {
          spModuleSchemaVersion = 1;
          id = "matrix";
          name = "Matrix";
          description = "An open network for secure, decentralised communication";
          svgIcon = builtins.readFile ./icon.svg;
          primarySubdomain = "elementSubdomain";
          isMovable = true;
          isRequired = false;
          backupDescription = "Messages, sessions, server signing keys and attachments";
          systemdServices = [
            "matrix-synapse.service"
            "matrix-authentication-service.service"
            "mas-kanidm-sync.service"
          ];
          ownedFolders = [
            {
              path = "/var/lib/matrix-synapse";
              owner = "matrix-synapse";
              group = "matrix-synapse";
            }
            {
              path = "/var/lib/matrix-authentication-service";
              owner = "matrix-authentication-service";
              group = "matrix-authentication-service";
            }
          ];
          folders = [];
          postgreDatabases = [
            "matrix-synapse"
            "matrix-authentication-service"
          ];
          license = [
            lib.licenses.agpl3Plus
          ];
          homepage = "https://matrix.org";
          sourcePage = "https://github.com/element-hq";
          supportLevel = "experimental";
          sso = {
            userGroup = "sp.matrix.users";
            adminGroup = "sp.matrix.admins";
          };
        };
    };
}
