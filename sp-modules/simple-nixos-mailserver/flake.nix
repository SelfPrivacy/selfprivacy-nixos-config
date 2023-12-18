{
  description = "PoC SP module for the simple-nixos-mailserver";

  inputs.mailserver.url =
    gitlab:simple-nixos-mailserver/nixos-mailserver;

  outputs = { self, mailserver }: {
    nixosModules.default = _: {
      imports = [
        mailserver.nixosModules.default
        ./options.nix
        ./config.nix
      ];
    };
    configPathsNeeded =
      builtins.fromJSON (builtins.readFile ./config-paths-needed.json);

    # TODO generate json docs from module? something like:
    # nix eval --impure --expr 'let flake = builtins.getFlake (builtins.toPath ./.); pkgs = flake.inputs.mailserver.inputs.nixpkgs.legacyPackages.x86_64-linux; in (pkgs.nixosOptionsDoc { inherit (pkgs.lib.evalModules { modules = [ flake.nixosModules.default ]; }) options; }).optionsJSON'
    # (doesn't work because of `assertions`)
  };
}
