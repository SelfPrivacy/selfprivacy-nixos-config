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

    (lib.mkIf (bootloader.type == "systemd-boot-efi") {
      assertions = [
        {
          assertion = bootloader.device == null;
          # we just need mounted /boot, infect takes care of that.
          message = "selfprivacy.server.bootloader.device is not valid for systemd-boot-efi.";
        }
      ];

      boot.loader.grub.enable = lib.mkForce false;

      boot.loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
    })
  ];
}
