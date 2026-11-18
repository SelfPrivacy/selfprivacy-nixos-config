{
  inputs,
  nixpkgs,
  self,
  system,
}:
let
  lib = nixpkgs.lib;
  testLib = import ../lib/nixos-test.nix { inherit inputs nixpkgs self; };
  sp-modules = testLib.spModules;
in
let
  config =
    (self.nixosConfigurations-fun {
      hardware-configuration = {
        nixpkgs.hostPlatform = system;
        system.stateVersion = lib.trivial.release;
        boot.loader.grub.device = "/dev/sda";
        fileSystems."/" = {
          device = "/dev/sda1";
          fsType = "ext4";
        };
      };
      userdata = testLib.mkTestUserdata {
        modules = testLib.allModulesConfiguration;
        autoUpgrade.enable = true;
        postgresql.location = "sda";
      };
      deployment = { };
      top-level-flake = self;
      inherit sp-modules;
    }).default;
in
assert lib.assertMsg (lib.all (vhost: !vhost.http2) (
  lib.attrValues config.config.services.nginx.virtualHosts
)) "HTTP/2 must remain disabled until the nginx2root mitigation is removed";
config.config.system.build.toplevel // { config = config; }
