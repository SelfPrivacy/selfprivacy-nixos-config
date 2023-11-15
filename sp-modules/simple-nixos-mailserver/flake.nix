{
  description = "PoC SP module for the simple-nixos-mailserver";

  inputs.mailserver.url =
    gitlab:simple-nixos-mailserver/nixos-mailserver;

  outputs = { self, mailserver }: {
    # tricks to rename (alias) the original module
    nixosModules.default = args@{ pkgs, config, ... }:
      let
        module = mailserver.nixosModules.default args;
      in
      module // {
        imports = module.imports ++ [
          ./config.nix
          { mailserver = config.selfprivacy.userdata.simple-nixos-mailserver; }
        ];
        options = module.options // {
          selfprivacy.userdata.simple-nixos-mailserver =
            module.options.mailserver;
        };
      };
    configPathsNeeded =
      builtins.fromJSON (builtins.readFile ./config-paths-needed.json);

    # TODO generate json docs from module? something like:
    # nix eval --impure --expr 'let flake = builtins.getFlake (builtins.toPath ./.); pkgs = flake.inputs.mailserver.inputs.nixpkgs.legacyPackages.x86_64-linux; in (pkgs.nixosOptionsDoc { inherit (pkgs.lib.evalModules { modules = [ flake.nixosModules.default ]; }) options; }).optionsJSON'
    # (doesn't work because of `assertions`)
  };
}
