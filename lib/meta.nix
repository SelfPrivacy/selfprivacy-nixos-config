{
  selfprivacyConfig,
  sp-module,
  pkgs,
  selfprivacy ? null,
}:
let
  lib = pkgs.lib;

  moduleMeta = sp-module.meta { inherit lib; };

  fallbackSelfprivacy =
    let
      selfFlake.outPath = selfprivacyConfig;
      nixpkgsFlake = {
        outPath = pkgs.path;
        inherit lib;
        legacyPackages.${pkgs.stdenv.hostPlatform.system} = pkgs;
      };
    in
    {
      types =
        (import (selfprivacyConfig + "/nixos/types.nix") { inherit lib; }).selfprivacy.passthru.types;
      modules.${moduleMeta.id} = sp-module;
      topLevelFlake = selfFlake;
      config = {
        source = selfprivacyConfig;
        inputs = {
          self = selfFlake;
          nixpkgs = nixpkgsFlake;
        };
      };
    };

  selfprivacyArgs = if selfprivacy == null then fallbackSelfprivacy else selfprivacy;

  options =
    (lib.evalModules {
      specialArgs.selfprivacy = selfprivacyArgs;
      modules = [
        { _module.check = false; }
        sp-module.nixosModules.default
      ];
    }).options;

  # Transform a Nix option to a JSON structure with metadata
  optionToMeta = name: option: {
    name = name;
    description = if option ? description then option.description else null;
    loc = option.loc;
    meta = if option ? meta then option.meta else null;
    default = if option ? default then option.default else null;
  };
in
builtins.toJSON {
  meta = moduleMeta;
  options = lib.mapAttrs optionToMeta (
    builtins.head (lib.mapAttrsToList (_name: value: value) options.selfprivacy.modules)
  );
}
