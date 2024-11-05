{
  description = "User authentication and authorization module";

  # TODO remove when Kanidm provisioning without groups assertion lands in NixOS
  inputs.nixos-unstable.url = github:alexoundos/nixpkgs/679fd3fd318ce2d57d0cabfbd7f4b8857d78ae95;
  # inputs.nixos-unstable.url = git+file:/data/nixpkgs?ref=kanidm-1.4.0&rev=3feae1d8a2681b57c07d3a212a083988da6b96d2;

  outputs = { self, nixos-unstable }: {
    overlays.default = _final: prev: {
      inherit (nixos-unstable.legacyPackages.${prev.system})
        kanidm oauth2-proxy;
      kanidm-provision =
        nixos-unstable.legacyPackages.${prev.system}.kanidm-provision.overrideAttrs (_: {
          # version = "git";
          # src = prev.fetchFromGitHub {
          #   owner = "oddlama";
          #   repo = "kanidm-provision";
          #   rev = "d1f55c9247a6b25d30bbe90a74307aaac6306db4";
          #   hash = "sha256-cZ3QbowmWX7j1eJRiUP52ao28xZzC96OdZukdWDHfFI=";
          # };
        });
    };

    nixosModules.default = { ... }: {
      disabledModules = [
        "services/security/kanidm.nix"
        "services/security/oauth2-proxy.nix"
        "services/security/oauth2-proxy-nginx.nix"
      ];
      imports = [
        (nixos-unstable.legacyPackages.x86_64-linux.path
          + /nixos/modules/services/security/kanidm.nix)
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
  };
}
