{
  inputs,
  nixpkgs ? inputs.nixpkgs,
  self ? inputs.self,
}:
let
  lib = nixpkgs.lib;

  # builtins.getFlake does not work with /nix/store paths.
  callFlake = builtins.getFlake "github:divnix/call-flake/1abb37095a152e0e8ba4315c57c84905bc8bf93c";

  spModules = lib.mapAttrs (name: _: callFlake "${self}/sp-modules/${name}") (
    builtins.readDir ../sp-modules
  );

  baseServiceNames = [
    "nextcloud"
    "monitoring"
    "simple-nixos-mailserver"
  ];

  baseSpModules = lib.filterAttrs (name: _: lib.elem name baseServiceNames) spModules;

  mkServiceSettings =
    modules: enable:
    lib.mapAttrs (_: _: {
      inherit enable;
      location = "sda";
    }) modules;

  baseModulesConfiguration = mkServiceSettings baseSpModules false // {
    nextcloud = {
      enable = true;
      location = "sda";
    };
    monitoring = {
      enable = true;
      location = "sda";
    };
    "simple-nixos-mailserver" = {
      enable = true;
      location = "sda";
    };
  };

  allModulesConfiguration = mkServiceSettings spModules true;
in
{
  inherit
    callFlake
    spModules
    baseSpModules
    baseModulesConfiguration
    allModulesConfiguration
    ;

  mkTestUserdata =
    overrides:
    lib.recursiveUpdate {
      dns = {
        provider = "CLOUDFLARE";
        useStagingACME = false;
      };
      server.provider = "HETZNER";
      domain = "dummy.site";
      hostname = "dummysite";
      timezone = "Etc/UTC";
      useBinds = true;
      sshKeys = [ ];
      users = [ ];
      autoUpgrade.enable = false;
      postgresql.location = null;
      modules = baseModulesConfiguration;
    } overrides;

  mkTestSystem =
    {
      system,
      userdata,
      spModules ? baseSpModules,
      extraModules ? [ ],
      topLevelFlake ? self,
    }:
    import ./nixos-system.nix { inherit inputs; } {
      inherit topLevelFlake userdata spModules;
      extraModules = [
        (
          { pkgs, ... }:
          let
            userdataFile = pkgs.writeText "userdata.json" (builtins.toJSON userdata);
          in
          {
            nixpkgs.hostPlatform = system;
            system.stateVersion = lib.trivial.release;
            systemd.tmpfiles.settings.test-userdata = {
              "/etc/nixos".d = {
                mode = "0755";
                user = "root";
                group = "root";
              };
              "/etc/nixos/userdata.json".C = {
                mode = "0600";
                user = "root";
                group = "root";
                argument = toString userdataFile;
              };
            };
          }
        )
      ]
      ++ extraModules;
    };
}
