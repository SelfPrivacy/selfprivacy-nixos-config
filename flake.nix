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

          testLib = import ./lib/nixos-test.nix { inherit inputs nixpkgs self; };

          mkFirstBoot =
            testHooks:
            import ./checks/first-boot.nix {
              inherit
                inputs
                self
                nixpkgs
                system
                testHooks
                ;
            };
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

          first-boot-no-legacy-unix-user = mkFirstBoot {
            userdataOverrides = { };
            testScript = ''machine.fail("getent passwd legacy-user")'';
          };

          first-boot-legacy-unix-user = mkFirstBoot {
            userdataOverrides = {
              username = "legacy-user";
              hashedMasterPassword = "$6$aaaaaaaaaaaaaaa$aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
            };
            testScript = ''machine.succeed("getent passwd legacy-user")'';
          };

          mail =
            let
              mailIntegrationTest = pkgs.writers.writePython3Bin "mail-integration-test" {
                libraries = with pkgs.python3Packages; [
                  pyotp
                  requests
                ];
                flakeIgnore = [
                  "E501"
                ];
              } (builtins.readFile ./checks/mail-integration.py);
            in
            mkFirstBoot {
              extraModules = [
                {
                  environment.systemPackages = [ mailIntegrationTest ];
                  virtualisation.memorySize = 2048;
                  virtualisation.cores = 2;
                }
              ];
              testScript = ''
                machine.succeed("mail-integration-test")
              '';
            };

          first-boot-with-all-modules = mkFirstBoot {
            userdataOverrides = {
              modules = nixpkgs.lib.recursiveUpdate testLib.allModulesConfiguration {
                nextcloud.enable = false;
                pleroma.enable = false;
              };
            };
            spModules = testLib.spModules;
            extraModules = [
              {
                virtualisation.memorySize = 6096;
                virtualisation.cores = 3;
              }
            ];
            testScript = ''
              synapse_versions = json.loads(wait_for_https("synapse", "/_matrix/client/versions"))
              assert synapse_versions["versions"], synapse_versions

              assert "A painless, self-hosted Git service" in wait_for_https("git")
              assert json.loads(wait_for_https("git", "/api/healthz"))["status"] == "pass"

              wait_for_https("password", "/alive")
              wait_for_https("actual")
              assert "uri" in json.loads(wait_for_https("gts", "/api/v1/instance"))
              wait_for_https("hedgedoc", "/status")
              assert "Jitsi Meet" in wait_for_https("meet")
              assert "version" in json.loads(wait_for_https("vikunja", "/api/v1/info"))
              assert "WriteFreely" in wait_for_https("writefreely")

              machine.wait_until_succeeds(
                "curl --fail --silent --show-error http://localhost:9001/-/ready",
                timeout=120,
              )
            '';
          };
        }
      );
    };
}
