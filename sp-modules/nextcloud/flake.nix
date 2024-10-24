{
  description = "PoC SP module for nextcloud";

  inputs.nixpkgs-old.url = "nixpkgs/nixos-23.11";

  outputs = { self, nixpkgs-old }:
    let
      oldPkgs = import nixpkgs-old {
        system = "x86_64-linux"; # Same architecture as above
      };
    in
    {
      nixosModules.default = _:
        {
          imports = [ ./module.nix ./cleanup-module.nix ];
          services.nextcloud.package = oldPkgs.nextcloud26;
        };
      configPathsNeeded =
        builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
    };
}
