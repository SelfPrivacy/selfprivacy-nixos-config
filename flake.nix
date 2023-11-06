{
  description = "SelfPrivacy NixOS configuration flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    selfprivacy-overlay.url =
      "git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-nix-repo.git";
  };

  outputs = { self, nixpkgs, selfprivacy-overlay }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations-fun = { hardware-configuration, userdata }: {
        just-nixos = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit system selfprivacy-overlay userdata; };
          modules = [ hardware-configuration ./configuration.nix ];
        };
      };
    };
}
