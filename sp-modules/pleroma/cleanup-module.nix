{ config, lib, ... }:
let
  inherit (import ./common.nix config) secrets-exs sp;
in
# FIXME do we really want to delete passwords on module deactivation!?
{
  config = lib.mkIf (!sp.modules.pleroma.enable) {
    system.activationScripts.pleroma =
      lib.trivial.warn
        (
          "pleroma service is disabled, ${secrets-exs} will be removed!"
        )
        ''
          rm -f -v ${secrets-exs}
        '';
  };
}
