{nixpkgs, self, system}: let
  lib = nixpkgs.lib;

  # builtins.getFlake doesn't work with /nix/store paths... Let's use call-flake for now.
  callFlake = (builtins.getFlake "github:divnix/call-flake/1abb37095a152e0e8ba4315c57c84905bc8bf93c");

  sp-modules = lib.mapAttrs (name: _: callFlake "${self}/sp-modules/${name}") (builtins.readDir ../sp-modules);
in (self.nixosConfigurations-fun {
  hardware-configuration = {
    system.stateVersion = lib.trivial.release;
    nixpkgs.hostPlatform = system;
    boot.loader.grub.device = "/dev/sda";
    fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
  };
  userdata = {
    dns = {
      provider = "CLOUDFLARE";
      useStagingACME = false;
    };
    server.provider = "HETZNER";
    domain = "dummy.site";
    hashedMasterPassword = "$6$aaaaaaaaaaaaaaa$aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    hostname = "dummysite";
    timezone = "Etc/UTC";
    username = "user";
    useBinds = true;
    sshKeys = [];
    users = [];
    autoUpgrade.enable = true;
    postgresql.location = "sda";
    modules = lib.mapAttrs (_: _: {
      enable = true;
      location = "sda";
    }) sp-modules;
  };
  deployment = {};
  top-level-flake = self;
  inherit sp-modules;
}).default.config.system.build.toplevel
