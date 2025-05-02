{ sp-module, pkgs }:
let
  lib = pkgs.lib;
  options =
    (pkgs.lib.evalModules {
      modules = [
        { _module.check = false; }
        sp-module.nixosModules.default
      ];
    }).options;
  # Transform a Nix option to a JSON structure with metadata
  optionToMeta = (
    name: option: {
      name = name;
      description = if builtins.hasAttr "description" option then option.description else null;
      loc = option.loc;
      meta = if builtins.hasAttr "meta" option then option.meta else null;
      default = if builtins.hasAttr "default" option then option.default else null;
    }
  );
in
builtins.toJSON ({
  meta = if builtins.hasAttr "meta" sp-module then sp-module.meta { inherit lib; } else null;
  configPathsNeeded = sp-module.configPathsNeeded;
  options = pkgs.lib.mapAttrs optionToMeta (
    builtins.head (lib.mapAttrsToList (name: value: value) options.selfprivacy.modules)
  );
})
