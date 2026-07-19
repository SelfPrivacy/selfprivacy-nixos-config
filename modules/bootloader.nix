{ lib, config, ... }:

let
  bootloader = config.selfprivacy.server.bootloader;
in
{
  config = lib.mkMerge [
    (lib.mkIf (bootloader.type == "grub-mbr") {
      assertions = [
        {
          assertion = bootloader.device != null;
          message = "selfprivacy.server.bootloader.device is required for grub-mbr.";
        }
      ];

      boot.loader.grub = {
        enable = true;

        # lib.mkForce because old SelfPrivacy installations
        # included boot.loader.grub.device in hardware-configuration.nix
        device = lib.mkForce bootloader.device;
      };
    })
  ];
}
