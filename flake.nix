{
  description = "Selfprivacy NixOS configuration flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    selfprivacy-overlay.url =
      "git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-nix-repo.git";

    # the /etc/nixos folder input is expected to be set by the caller
    # for example, upon nix build using --override-input
    etc-nixos.flake = false;
  };

  outputs =
    { self
    , etc-nixos
    , nixpkgs
    , selfprivacy-overlay
    } @ inputs:
    let
      system = "x86_64-linux";
      userdata =
        builtins.fromJSON (builtins.readFile "${etc-nixos}/userdata.json");
      lib = nixpkgs.legacyPackages.${system}.lib;
    in
    {
      nixosConfigurations.just-nixos = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit system userdata; };
        modules = [
          # SelfPrivacy overlay
          {
            nixpkgs.overlays = [ selfprivacy-overlay.overlay ];
            environment.etc.selfprivacy-nixos-config-source.source =
              etc-nixos.outPath;
            nix.registry = lib.mapAttrs (_n: flake: { inherit flake; }) inputs;
          }
          # machine specifics
          "${etc-nixos}/hardware-configuration.nix"
          # main configuration part
          ./configuration.nix
        ];
      };
    };
}
