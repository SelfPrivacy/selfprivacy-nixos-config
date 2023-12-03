{ config, lib, ... }:
let
  inherit (import ./common.nix config) bitwarden-env sp;
in
# FIXME do we really want to delete passwords on module deactivation!?
{
  config = lib.mkIf (!sp.modules.bitwarden.enable) {
    system.activationScripts.bitwarden =
      lib.trivial.warn
        (
          "bitwarden service is disabled, ${bitwarden-env} will be removed!"
        )
        ''
          rm -f -v ${bitwarden-env}
        '';
  };
}
