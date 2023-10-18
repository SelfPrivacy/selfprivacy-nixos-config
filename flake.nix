{
  description = "Selfprivacy NixOS configuration flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    selfprivacy-overlay.url =
      "git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-nix-repo.git";

    # these inputs are expected to be set by the caller
    # for example, upon nix build using --override-input
    userdata-json.flake = false; # userdata.json
    hardware-configuration-nix.flake = false; # hardware-configuration.nix
  };

  outputs =
    { self
    , nixpkgs
    , selfprivacy-overlay
    , userdata-json
    , hardware-configuration-nix
    }:
    let
      system = "x86_64-linux";
      userdata = builtins.fromJSON (builtins.readFile userdata-json);
      hardware-configuration = import hardware-configuration-nix;
    in
    {
      nixosConfigurations = {
        just-nixos = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit system userdata; };
          modules = [
            # SelfPrivacy overlay
            { nixpkgs.overlays = [ selfprivacy-overlay.overlay ]; }
            # machine specifics
            hardware-configuration
            # main configuration part
            ./configuration.nix
          ];
        };
      };
    };
}
