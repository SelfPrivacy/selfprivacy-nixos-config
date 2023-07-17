{
  description = "Selfprivacy NixOS configuration flake";

  inputs = {
    #nixpkgs.url = "https://github.com/NixOS/nixpkgs/archive/eef86b8a942913a828b9ef13722835f359deef29.tar.gz";
    nixpkgs.url = "github:nixos/nixpkgs";
    selfprivacy-overlay.url =
      "git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-nix-repo.git";
  };

  outputs = { self, nixpkgs, selfprivacy-overlay }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations-fun = userdata: {
        just-nixos = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit system selfprivacy-overlay userdata; };

          modules = [ ./configuration.nix ];
        };
      };
    };
}
