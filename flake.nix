{
  description = "SelfPrivacy NixOS configuration flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    selfprivacy-graphql-api.url =
      "git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-rest-api.git";
    selfprivacy-graphql-api.inputs.nixpkgs.follows = "nixpkgs";
    # TODO nixpkgs inputs of selfprivacy-graphql-api and this flake must match!
  };

  outputs = { self, nixpkgs, selfprivacy-graphql-api }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations-fun = { hardware-configuration, userdata }: {
        just-nixos = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit
              system
              hardware-configuration
              userdata;
            selfprivacy-graphql-api =
              selfprivacy-graphql-api.packages.${system}.default;
          };
          modules = [
            hardware-configuration
            ./configuration.nix
          ];
        };
      };
    };
}
