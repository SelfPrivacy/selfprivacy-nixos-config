{
  inputs,
  ...
}:
{
  topLevelFlake,
  extraModules,
  spModules,
  userdata,
}:
let
  nixpkgs = inputs.nixpkgs;
  lib = nixpkgs.lib;
in
lib.fix (self: {
  system = inputs.nixpkgs.lib.nixosSystem {
    inherit (self) specialArgs modules;
  };
  specialArgs = {
    selfprivacy = {
      inherit ((import ../nixos/types.nix { lib = nixpkgs.lib; }).selfprivacy.passthru) types;
      modules = spModules;
      topLevelFlake = topLevelFlake;
      config.source = inputs.self;
      config.inputs = inputs;
    };
  };
  modules = extraModules ++ [
    ../nixos
    ../configuration.nix
    inputs.selfprivacy-api.nixosModules.default
    (
      let
        deepOptionsFilter =
          ref: attrset:
          nixpkgs.lib.attrsets.mergeAttrsList (
            map (
              key:
              if builtins.hasAttr key ref then
                let
                  value = attrset.${key};
                  refValue = ref.${key};
                in
                {
                  ${key} =
                    if builtins.isAttrs value && builtins.isAttrs refValue then
                      (if refValue ? _type && refValue._type == "option" then value else deepOptionsFilter refValue value)
                    else
                      value;
                }
              else
                { }
            ) (builtins.attrNames attrset)
          );
      in
      { options, ... }:
      {
        # pass userdata (parsed from JSON) options to selfprivacy module
        selfprivacy = deepOptionsFilter options.selfprivacy userdata;
      }
    )
  ];
})
