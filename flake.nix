{
  description = "SelfPrivacy NixOS configuration flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    selfprivacy-graphql-api.url =
      "git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-rest-api.git";
    selfprivacy-graphql-api.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, selfprivacy-graphql-api }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations-fun =
        { hardware-configuration
        , userdata
        , top-level-flake
        }: {
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
              {
                # embed top-level flake source folder into the build
                environment.etc."selfprivacy-config-source" =
                  top-level-flake.outPath;
                # for running "nix search nixpkgs", etc
                nix.registry.nixpkgs.flake = nixpkgs;
                # embed commit sha1; dirty builds are intentionally forbidden
                system.configurationRevision = top-level-flake.rev; # FIXME
                # system.configurationRevision = self.rev;
              }
            ];
            inherit system;
          };
        };
    };
}
