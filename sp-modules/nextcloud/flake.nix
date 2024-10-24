{
  description = "PoC SP module for nextcloud";

  inputs.nixpkgs-old.url = "nixpkgs/nixos-23.11";

  outputs = { self, nixpkgs-old }: {
    nixosModules.default = _:
      { imports = [ ./module.nix ./cleanup-module.nix ]; };
    configPathsNeeded =
      builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
  };
}
