{
  description = "Selfprivacy NixOS configuration flake";

  inputs = {
    #nixpkgs.url = "https://github.com/NixOS/nixpkgs/archive/eef86b8a942913a828b9ef13722835f359deef29.tar.gz";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    # selfprivacy-overlay.url = "https://git.selfprivacy.org/SelfPrivacy/selfprivacy-nix-repo/archive/22-11.tar.gz";
    selfprivacy-overlay.url = "git+file:///data/selfprivacy/selfprivacy-nix-repo";
    # userdata-json.url = ./userdata/userdata.json;
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
