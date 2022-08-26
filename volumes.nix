{ pkgs, config, ... }:
let
  cfg = config.services.userdata;
in
{
  fileSystems = { } // builtins.listToAttrs (builtins.map
    (volume: {
      name = "${volume.mountPoint}";
      value = {
        device = "${volume.device}";
        fsType = "${volume.fsType}";
      };
    })
    cfg.volumes);
}
