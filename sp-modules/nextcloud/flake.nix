{
  description = "PoC SP module for nextcloud";

  outputs = { self }: {
    nixosModules.default = _:
      { imports = [ ./module.nix ./cleanup-module.nix ]; };
    configPathsNeeded =
      builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
  };
}
