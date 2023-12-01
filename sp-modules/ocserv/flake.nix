{
  description = "PoC SP module for OpenConnect VPN server (ocserv)";

  outputs = { self }: {
    nixosModules.default = import ./module.nix;
    configPathsNeeded =
      builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
  };
}
