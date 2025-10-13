{ config, lib, ... }:
let
  inherit (import ./common.nix config)
    admin-pass-filepath
    override-config-fp
    sp
    ;
in
# FIXME do we really want to delete passwords on module deactivation!?
{
  config = lib.mkIf (!sp.modules.nextcloud.enable) {
    system.activationScripts.nextcloudSecrets =
      lib.trivial.warn
        (
          "nextcloud service is disabled, "
          + "${override-config-fp} and ${admin-pass-filepath} will be removed!"
        )
        ''
          rm -f -v ${admin-pass-filepath}
          [[ ! -f "${override-config-fp}" && -L "${override-config-fp}" ]] && \
            rm -v "${override-config-fp}"
        '';
  };
}
