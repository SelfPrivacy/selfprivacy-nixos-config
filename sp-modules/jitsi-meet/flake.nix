{
  description = "PoC SP module for Jitsi Meet video conferences server";

  inputs.nixpkgs-2405.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs =
    { self, nixpkgs-2405 }:
    {
      nixosModules.default = import ./module.nix nixpkgs-2405.legacyPackages;
      configPathsNeeded = builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
      meta =
        { lib, ... }:
        {
          spModuleSchemaVersion = 1;
          id = "jitsi-meet";
          name = "JitsiMeet";
          description = "Jitsi Meet is a free and open-source video conferencing solution.";
          svgIcon = builtins.readFile ./icon.svg;
          isMovable = false;
          isRequired = false;
          backupDescription = "Secrets that are used to encrypt the communication.";
          systemdServices = [
            "prosody.service"
            "jitsi-videobridge2.service"
            "jicofo.service"
          ];
          folders = [
            "/var/lib/jitsi-meet"
          ];
          license = [
            lib.licenses.asl20
          ];
          homepage = "https://jitsi.org/meet";
          sourcePage = "https://github.com/jitsi/jitsi-meet";
          supportLevel = "normal";
        };
    };
}
