{
  description = "SelfPrivacy NixOS configuration flake";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs;

    selfprivacy-api.url =
      git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-rest-api.git;
    # make selfprivacy-api use the same shared nixpkgs
    selfprivacy-api.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, selfprivacy-api }: {
    nixosConfigurations-fun =
      { hardware-configuration
      , deployment
      , userdata
      , top-level-flake
      , sp-modules
      }:
      {
        sp-nixos = nixpkgs.lib.nixosSystem {
          modules = [
            hardware-configuration
            deployment
            ./configuration.nix
            selfprivacy-api.nixosModules.default
            {
              # pass userdata (parsed from JSON) options to selfprivacy module
              selfprivacy = userdata;

              # embed top-level flake source folder into the build
              environment.etc."selfprivacy/nixos-config-source".source =
                top-level-flake;

              # for running "nix search nixpkgs", etc
              nix.registry.nixpkgs.flake = nixpkgs;

              # embed commit sha1 for `nixos-version --configuration-revision`
              system.configurationRevision = self.rev
                or "@${self.lastModifiedDate}"; # for development
              # TODO assertion to forbid dirty builds caused by top-level-flake

              # reset contents of /etc/nixos to match running NixOS generation
              system.activationScripts.selfprivacy-nixos-config-source = ''
                rm -rf /etc/nixos/{*,.[!.]*}
                cp -r --no-preserve=all ${top-level-flake}/ -T /etc/nixos/
              '';
            }
          ]
          ++
          # add SP modules, but contrain available config attributes for each
          # (TODO revise evaluation performance of the code below)
          nixpkgs.lib.attrsets.mapAttrsToList
            (name: sp-module: args@{ config, pkgs, ... }:
              let
                lib = nixpkgs.lib;
                configPathsNeeded = sp-module.configPathsNeeded or
                  (abort "allowed config paths not set for module \"${name}\"");
                constrainConfigArgs = args'@{ pkgs, ... }: args' // {
                  config =
                    # TODO use lib.attrsets.mergeAttrsList from nixpkgs 23.05
                    (builtins.foldl' lib.attrsets.recursiveUpdate { }
                      (map
                        (p: lib.attrsets.setAttrByPath p
                          (lib.attrsets.getAttrFromPath p config))
                        configPathsNeeded
                      )
                    );
                };
                constrainImportsArgsRecursive = lib.attrsets.mapAttrsRecursive
                  (p: v:
                    # TODO traverse only imports and imports of imports, etc
                    # without traversing all attributes
                    if lib.lists.last p == "imports"
                    then
                      map
                        (m:
                          (args'@{ pkgs, ... }: constrainImportsArgsRecursive
                            (if builtins.isPath m
                            then import m (constrainConfigArgs args')
                            else
                              if builtins.isFunction m
                              then m (constrainConfigArgs args')
                              else m))
                        )
                        v
                    else v);
              in
              constrainImportsArgsRecursive
                (sp-module.nixosModules.default (constrainConfigArgs args))
            )
            sp-modules;
        };
      };
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
  };
}
