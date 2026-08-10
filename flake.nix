{
  description = "SelfPrivacy NixOS configuration flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    selfprivacy-api.url = "git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-rest-api.git";
    # make selfprivacy-api use the same shared nixpkgs
    selfprivacy-api.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
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
            formatter.python = {
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
            specialArgs = {
              selfprivacy = {
                inherit ((import ./nixos/types.nix { lib = nixpkgs.lib; }).selfprivacy.passthru) types;
                modules = sp-modules;
                topLevelFlake = top-level-flake;
                config.source = self;
                config.inputs = inputs;
              };
            };
            modules = [
              hardware-configuration
              deployment
              ./nixos
              ./configuration.nix
              selfprivacy-api.nixosModules.default
              (
                let
                  deepOptionsFilter =
                    ref: attrset:
                    nixpkgs.lib.attrsets.mergeAttrsList (
                      map (
                        key:
                        if builtins.hasAttr key ref then
                          let
                            value = attrset.${key};
                            refValue = ref.${key};
                          in
                          {
                            ${key} =
                              if builtins.isAttrs value && builtins.isAttrs refValue then
                                (if refValue ? _type && refValue._type == "option" then value else deepOptionsFilter refValue value)
                              else
                                value;
                          }
                        else
                          { }
                      ) (builtins.attrNames attrset)
                    );
                in
                { options, ... }:
                {
                  # pass userdata (parsed from JSON) options to selfprivacy module
                  selfprivacy = deepOptionsFilter options.selfprivacy userdata;
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
                  mergeAttrsListRecursive =
                    attrsList:
                    lib.attrsets.zipAttrsWith (
                      _: values:
                      if builtins.all builtins.isAttrs values then
                        mergeAttrsListRecursive values
                      else
                        lib.lists.last values
                    ) attrsList;
                  constrainConfigArgs =
                    args'@{ pkgs, ... }:
                    args'
                    // {
                      config = mergeAttrsListRecursive (
                        map (p: lib.attrsets.setAttrByPath p (lib.attrsets.getAttrFromPath p config)) configPathsNeeded
                      );
                    };
                  applyConstrainedModule =
                    m: args':
                    let
                      imported = if builtins.isPath m then import m else m;
                    in
                    if builtins.isFunction imported then imported (constrainConfigArgs args') else imported;
                  constrainImportsArgsRecursive = lib.attrsets.mapAttrsRecursive (
                    p: v:
                    # TODO traverse only imports and imports of imports, etc
                    # without traversing all attributes
                    if lib.lists.last p == "imports" then
                      map (m: (args'@{ pkgs, ... }: constrainImportsArgsRecursive (applyConstrainedModule m args'))) v
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
