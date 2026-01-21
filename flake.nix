{
  description = "SelfPrivacy NixOS configuration flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    selfprivacy-api.url = "git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-rest-api.git";
    # make selfprivacy-api use the same shared nixpkgs
    selfprivacy-api.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      selfprivacy-api,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      mkTreeFmt =
        pkgs:
        pkgs.nixfmt-tree.override {
          runtimeInputs = [
            pkgs.black
          ];
          settings = {
            formattter.python = {
              includes = [ "*.py" ];
              command = "black";
            };
          };
        };
    in
    {
      nixosConfigurations-fun =
        {
          hardware-configuration,
          deployment,
          userdata,
          top-level-flake,
          sp-modules,
        }:
        {
          default = nixpkgs.lib.nixosSystem {
            modules = [
              hardware-configuration
              deployment
              ./configuration.nix
              selfprivacy-api.nixosModules.default
              (
                { pkgs, lib, ... }:
                {
                  environment.etc =
                    (lib.attrsets.mapAttrs' (name: sp-module: {
                      name = "sp-modules/${name}";
                      value.text = import ./lib/meta.nix { inherit pkgs sp-module; };
                    }) sp-modules)
                    // {
                      suggested-sp-modules.text = builtins.toJSON (builtins.attrNames (builtins.readDir ./sp-modules));
                    };
                }
              )
              (
                let
                  deepOptionsFilter =
                    ref: attrset:
                    builtins.foldl' (
                      acc: key:
                      if builtins.hasAttr key ref then
                        let
                          value = attrset.${key};
                          refValue = ref.${key};
                        in
                        acc
                        // {
                          ${key} =
                            if builtins.isAttrs value && builtins.isAttrs refValue then
                              (if refValue ? _type && refValue._type == "option" then value else deepOptionsFilter refValue value)
                            else
                              value;
                        }
                      else
                        acc
                    ) { } (builtins.attrNames attrset);
                in
                { options, ... }:
                {
                  # pass userdata (parsed from JSON) options to selfprivacy module
                  selfprivacy = deepOptionsFilter options.selfprivacy userdata;

                  # embed top-level flake source folder into the build
                  environment.etc."selfprivacy/nixos-config-source".source = top-level-flake;

                  # for running "nix search nixpkgs", "nix shell nixpkgs#PKG... etc
                  nix.registry.nixpkgs.flake = nixpkgs;

                  # embed commit sha1 for `nixos-version --configuration-revision`
                  system.configurationRevision = self.rev or "@${self.lastModifiedDate}"; # for development
                  # TODO assertion to forbid dirty builds caused by top-level-flake

                  # reset contents of /etc/nixos to match running NixOS generation
                  system.activationScripts.selfprivacy-nixos-config-source = ''
                    rm -rf /etc/nixos/{*,.[!.]*}
                    cp -r --no-preserve=all ${top-level-flake}/ -T /etc/nixos/
                  '';
                }
              )
            ]
            ++
              # add SP modules, but constrain available config attributes for each
              # (TODO revise evaluation performance of the code below)
              nixpkgs.lib.attrsets.mapAttrsToList (
                name: sp-module:
                args@{ config, pkgs, ... }:
                let
                  lib = nixpkgs.lib;
                  configPathsNeeded =
                    sp-module.configPathsNeeded or (abort "allowed config paths not set for module \"${name}\"");
                  constrainConfigArgs =
                    args'@{ pkgs, ... }:
                    args'
                    // {
                      config =
                        # TODO use lib.attrsets.mergeAttrsList from nixpkgs 23.05
                        (
                          builtins.foldl' lib.attrsets.recursiveUpdate { } (
                            map (p: lib.attrsets.setAttrByPath p (lib.attrsets.getAttrFromPath p config)) configPathsNeeded
                          )
                        );
                    };
                  constrainImportsArgsRecursive = lib.attrsets.mapAttrsRecursive (
                    p: v:
                    # TODO traverse only imports and imports of imports, etc
                    # without traversing all attributes
                    if lib.lists.last p == "imports" then
                      map (
                        m:
                        (
                          args'@{ pkgs, ... }:
                          constrainImportsArgsRecursive (
                            if builtins.isPath m then
                              import m (constrainConfigArgs args')
                            else if builtins.isFunction m then
                              m (constrainConfigArgs args')
                            else
                              m
                          )
                        )
                      ) v
                    else
                      v
                  );
                in
                constrainImportsArgsRecursive (sp-module.nixosModules.default (constrainConfigArgs args))
              ) sp-modules;
          };
        };
      formatter = nixpkgs.lib.genAttrs systems (system: mkTreeFmt nixpkgs.legacyPackages.${system});

      checks = nixpkgs.lib.genAttrs systems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          treefmt = mkTreeFmt pkgs;
        in
        {
          # nixfmt returns cryptic error when ran from read-only directory and when directory isn't a git repo:
          # (openTempFileWithDefaultPermissions: permission denied)
          # so we need to copy source tree inside build directory and make it r/w
          # (inspired by https://github.com/numtide/treefmt-nix/blob/5eb7434820f549f58c12a384b87ee73359c04c7b/module-options.nix#L312)
          fmt-check =
            pkgs.runCommandLocal "fmt-check"
              {
                buildInputs = [
                  treefmt
                  pkgs.git
                ];
              }
              "
            set -e
            cp -r ${self} src
            chmod -R a+w src
            cd src
            export HOME=$TMPDIR
            git init --quiet
            git config user.name SelfPrivacy
            git config user.email sp@localhost
            git add .
            git commit -m init --quiet
            treefmt --ci
            touch $out
          ";

          system-eval = (import ./checks/system-eval.nix) { inherit self nixpkgs system; };
        }
      );
    };
}
