{ config, lib, ... }:
let
  inherit (import ./common.nix config) sp db-pass-filepath admin-pass-filepath;
in
# FIXME do we really want to delete passwords on module deactivation!?
{
  config = lib.mkIf (!sp.modules.nextcloud.enable) {
    system.activationScripts.nextcloudSecrets =
      lib.trivial.warn
        (
          "nextcloud service is disabled, " +
          "${db-pass-filepath} and ${admin-pass-filepath} will be removed!"
        )
        ''
          rm -f ${db-pass-filepath}
          rm -f ${admin-pass-filepath}
        '';
  };
}
