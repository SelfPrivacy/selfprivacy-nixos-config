{
  selfprivacyConfig,
  sp-module,
  pkgs,
  selfprivacy ? null,
}:
let
  lib = pkgs.lib;

  spModuleMeta = if sp-module ? meta then sp-module.meta { inherit lib; } else null;
  spModuleId = if spModuleMeta != null then spModuleMeta.id else "module";

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
      modules.${spModuleId} = sp-module;
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
    description = if builtins.hasAttr "description" option then option.description else null;
    loc = option.loc;
    meta = if builtins.hasAttr "meta" option then option.meta else null;
    default = if builtins.hasAttr "default" option then option.default else null;
  };
in
builtins.toJSON {
  meta = spModuleMeta;
  configPathsNeeded = sp-module.configPathsNeeded;
  options = lib.mapAttrs optionToMeta (
    builtins.head (lib.mapAttrsToList (_name: value: value) options.selfprivacy.modules)
  );
}
