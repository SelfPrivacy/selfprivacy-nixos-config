{
  description = "SelfPrivacy NixOS configuration flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    selfprivacy-graphql-api.url =
      "git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-rest-api.git";
    # make selfprivacy-graphql-api use the same shared nixpkgs
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
      {
        sp-nixos = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit system; };
          modules = [
            hardware-configuration
            ./configuration.nix
            (import ./userdata-variables.nix userdata)
            (import ./api/api-module.nix
              selfprivacy-graphql-api.packages.${system}.default)
            {
              # embed top-level flake source folder into the build
              environment.etc."selfprivacy/current-config-source".source =
                top-level-flake.outPath;
              # for running "nix search nixpkgs", etc
              nix.registry.nixpkgs.flake = nixpkgs;
              # embed commit sha1 for `nixos-version --configuration-revision`
              system.configurationRevision = self.rev
                or "@${self.lastModifiedDate}"; # for development
              # TODO assertion to forbid dirty builds caused by top-level-flake
            }
          ]
          ++
          # add SP modules, but contrain available config attributes for each
          # (TODO revise evaluation performance of the code below)
          map
            (sp-module: args@{ config, pkgs, ... }:
              let
                lib = nixpkgs.lib;
                constrainConfigArgs = args'@{ pkgs, ... }: args' // {
                  config =
                    # TODO use lib.attrsets.mergeAttrsList from nixpkgs 23.05
                    (builtins.foldl' lib.attrsets.recursiveUpdate { }
                      (map
                        (p: lib.attrsets.setAttrByPath p
                          (lib.attrsets.getAttrFromPath p config))
                        sp-module.configPathsNeeded));
                };
                constrainImportsArgsRecursive = lib.attrsets.mapAttrsRecursive
                  (p: v:
                    if lib.lists.last p == "imports"
                    then
                      map
                        (m:
                          (args'@{ pkgs, ... }: constrainImportsArgsRecursive
                            (if builtins.isPath m
                            then import m (constrainConfigArgs args')
                            else
                              if builtins.isFunction m
                              then constrainConfigArgs args'
                              else m))
                        )
                        v
                    else v);
              in
              constrainImportsArgsRecursive
                (sp-module.nixosModules.default (constrainConfigArgs args))
            )
            (nixpkgs.lib.attrsets.attrValues sp-modules);
        };
      };
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
  };
}
