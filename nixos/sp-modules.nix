{
  selfprivacy,
  lib,
  pkgs,
  ...
}:
let
  sp-modules = selfprivacy.modules;
in
{
  environment.etc =
    (lib.attrsets.mapAttrs' (name: sp-module: {
      name = "sp-modules/${name}";
      value.text = import ../lib/meta.nix {
        selfprivacyConfig = selfprivacy.config.source;
        inherit pkgs sp-module;
      };
    }) sp-modules)
    // {
      "suggested-sp-modules".text = builtins.toJSON (builtins.attrNames (builtins.readDir ../sp-modules));
      "sp-fetch-remote-module.nix" = {
        text = ''
          { flakeURL }: let
            sp-module = builtins.getFlake flakeURL;
            pkgs = import ${pkgs.path} {};
          in (import ${selfprivacy.config.source}/lib/meta.nix) {
            selfprivacyConfig = ${selfprivacy.config.source};
            inherit pkgs sp-module;
          }
        '';
      };
    };
}
