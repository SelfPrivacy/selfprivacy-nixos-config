{
  description = "User authentication and authorization module";

  # TODO remove when working Kanidm lands in nixpkgs and Hydra
  inputs.nixpkgs-unstable.url = github:alexoundos/nixpkgs/b84444cbd57e934312f6a03d2d783ed0b7f94957;

  outputs = { self, nixpkgs-unstable }: {
    overlays.default = _final: prev: {
      inherit (nixpkgs-unstable.legacyPackages.${prev.system})
        kanidm kanidm-provision oauth2-proxy;
    };

    nixosModules.default = { ... }: {
      disabledModules = [
        "services/security/kanidm.nix"
        "services/security/oauth2-proxy.nix"
        "services/security/oauth2-proxy-nginx.nix"
      ];
      imports = [
        (nixpkgs-unstable.legacyPackages.x86_64-linux.path
          + /nixos/modules/services/security/kanidm.nix)
        (nixpkgs-unstable.legacyPackages.x86_64-linux.path
          + /nixos/modules/services/security/oauth2-proxy.nix)
        (nixpkgs-unstable.legacyPackages.x86_64-linux.path
          + /nixos/modules/services/security/oauth2-proxy-nginx.nix)
        ./module.nix
      ];
      nixpkgs.overlays = [ self.overlays.default ];
    };

    configPathsNeeded =
      builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
  };
}
