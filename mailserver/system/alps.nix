{ pkgs, config, lib, fetchgit, buildGoModule, ... }:
let domain = config.services.userdata.domain;
in
{
  nixpkgs.overlays =
    [ (self: super: { alps = self.callPackage ./alps-package.nix { }; }) ];

  systemd.services = {
    alps = {
      path = [ pkgs.alps pkgs.coreutils ];
      serviceConfig = {
        ExecStart =
          "${pkgs.alps}/bin/alps -theme sourcehut imaps://${domain}:993 smtps://${domain}:465";
        WorkingDirectory = "${pkgs.alps}/bin";
      };
    };
  };
}
