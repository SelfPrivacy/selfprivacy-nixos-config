{
  description = "PoC SP module for OpenConnect VPN server (ocserv)";

  outputs =
    { ... }:
    {
      nixosModules.default = import ./module.nix;

      meta =
        { lib, ... }:
        {
          spModuleSchemaVersion = 1;
          id = "ocserv";
          name = "OpenConnect VPN";
          description = "OpenConnect VPN to connect your devices and access the internet.";
          svgIcon = builtins.readFile ./icon.svg;
          isMovable = false;
          isRequired = false;
          canBeBackedUp = false;
          backupDescription = "Backups are not available for OpenConnect VPN.";
          systemdServices = [
            "ocserv.service"
          ];
          license = [
            lib.licenses.gpl2Plus
          ];
          homepage = "https://gitlab.com/openconnect/ocserv";
          sourcePage = "https://gitlab.com/openconnect/ocserv";
          supportLevel = "deprecated";
        };
    };
}
