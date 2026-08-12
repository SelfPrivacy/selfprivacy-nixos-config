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
          default =
            (import ./lib/nixos-system.nix { inherit inputs; } {
              inherit userdata;
              topLevelFlake = top-level-flake;
              spModules = sp-modules;
              extraModules = [
                hardware-configuration
                deployment
              ];
            }).system;
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

          system-eval = (import ./checks/system-eval.nix) {
            inherit
              inputs
              self
              nixpkgs
              system
              ;
          };

          first-boot = (import ./checks/first-boot.nix) {
            inherit
              inputs
              self
              nixpkgs
              system
              ;
          };
        }
      );
    };
}
