{
  description = "User authentication and authorization module";

  # TODO remove when Kanidm provisioning without groups assertion lands in NixOS
  # inputs.nixos-unstable.url = github:alexoundos/nixpkgs/679fd3fd318ce2d57d0cabfbd7f4b8857d78ae95;
  # inputs.nixos-unstable.url = git+file:/data/nixpkgs?ref=kanidm-1.4.0&rev=1bac99358baea6a3268027b4e585c68cd4ef107d;
  inputs.nixos-unstable.url = github:nixos/nixpkgs/7ffd9ae656aec493492b44d0ddfb28e79a1ea25d;

  outputs = { self, nixos-unstable }: {
    overlays.default = _final: prev: {
      inherit (nixos-unstable.legacyPackages.${prev.system})
        kanidm oauth2-proxy;
      kanidm-provision =
        nixos-unstable.legacyPackages.${prev.system}.kanidm-provision.overrideAttrs (_: {
          version = "git";
          src = prev.fetchFromGitHub {
            owner = "oddlama";
            repo = "kanidm-provision";
            rev = "d1f55c9247a6b25d30bbe90a74307aaac6306db4";
            hash = "sha256-cZ3QbowmWX7j1eJRiUP52ao28xZzC96OdZukdWDHfFI=";
          };
        });
    };

    nixosModules.default = { ... }: {
      disabledModules = [
        "services/security/kanidm.nix"
        "services/security/oauth2-proxy.nix"
        "services/security/oauth2-proxy-nginx.nix"
      ];
      imports = [
        ./kanidm.nix
        (nixos-unstable.legacyPackages.x86_64-linux.path
          + /nixos/modules/services/security/oauth2-proxy.nix)
        (nixos-unstable.legacyPackages.x86_64-linux.path
          + /nixos/modules/services/security/oauth2-proxy-nginx.nix)
        ./module.nix
      ];
      nixpkgs.overlays = [ self.overlays.default ];
    };

    configPathsNeeded =
      builtins.fromJSON (builtins.readFile ./config-paths-needed.json);

    meta = { lib, ... }: {
      spModuleSchemaVersion = 1;
      id = "auth";
      name = "Auth";
      description = "Temporary auth module.";
      svgIcon = builtins.readFile ./icon.svg;
      isMovable = false;
      isRequired = false;
      backupDescription = "Useless service.";
      systemdServices = [ "kanidm.service" ];
      folders = [ ];
      license = [ ];
      homepage = "https://kanidm.com";
      sourcePage = "https://github.com/kanidm";
      supportLevel = "hallucinatory";
    };
  };
}
