{
  description = "SelfPrivacy NixOS configuration flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    selfprivacy-graphql-api.url =
      "git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-rest-api.git";
    selfprivacy-graphql-api.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, selfprivacy-graphql-api }: {
    nixosConfigurations-fun =
      { system
      , hardware-configuration
      , userdata
      , top-level-flake
      , sp-modules
      }:
      let
        lib = nixpkgs.legacyPackages.${system}.lib;
      in
      {
        just-nixos = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit system; };
          modules = [
            hardware-configuration
            ./configuration.nix
            (import ./userdata-variables.nix userdata)
            (import ./api/api-module.nix
              selfprivacy-graphql-api.packages.${system}.default)
            {
              # embed top-level flake source folder into the build
              environment.etc."selfprivacy-config-source".source =
                top-level-flake.outPath;
              # for running "nix search nixpkgs", etc
              nix.registry.nixpkgs.flake = nixpkgs;
              # embed commit sha1; FIXME dirty builds must be intentionally forbidden
              system.configurationRevision = self.rev or ("#" + self.lastModifiedDate + "-" + toString self.lastModified);
            }
          ]
          ++
          # add SP modules, but filter available config attributes for each
          map
            (sp-module: args@{ pkgs, ... }: (sp-module.nixosModules.default
              (args // {
                config =
                  # TODO use lib.attrsets.mergeAttrsList from nixpkgs 23.05
                  (builtins.foldl' lib.trivial.mergeAttrs { }
                    (map
                      (p: lib.attrsets.setAttrByPath p
                        (lib.attrsets.getAttrFromPath p args.config))
                      sp-module.configPathsNeeded));
              }))
            )
            # (sp-module: sp-module.nixosModules.default)
            (lib.attrsets.attrValues sp-modules);
        };
      };
  };
}
