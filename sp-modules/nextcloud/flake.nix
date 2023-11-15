{
  description = "PoC SP module for nextcloud";

  outputs = { self }: {
    nixosModules.default = import ./module.nix;
    configPathsNeeded =
      builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
  };
}
