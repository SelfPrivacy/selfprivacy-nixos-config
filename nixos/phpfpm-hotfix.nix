{ config, lib, ... }:
let
  domain = config.selfprivacy.domain;
  assetsRoot = ../assets;
  modules = config.selfprivacy.modules;
  nextcloudEnabled = modules ? nextcloud && modules.nextcloud.enable;
  roundcubeEnabled = modules ? roundcube && modules.roundcube.enable;
  nextcloud = if modules ? nextcloud then modules.nextcloud else { };
  roundcube = if modules ? roundcube then modules.roundcube else { };
  shutdownVhost = {
    root = lib.mkForce assetsRoot;
    extraConfig = lib.mkBefore ''
      rewrite ^(?!/php-shutdown\.html$) /php-shutdown.html last;
    '';
  };
in
{
  config = lib.mkMerge [
    (lib.mkIf nextcloudEnabled {
      services.nginx.virtualHosts."${nextcloud.subdomain}.${domain}" = shutdownVhost;
      systemd.services.phpfpm-nextcloud.enable = lib.mkForce false;
    })

    (lib.mkIf roundcubeEnabled {
      services.nginx.virtualHosts."${roundcube.subdomain}.${domain}" = shutdownVhost;
      systemd.services.phpfpm-roundcube.enable = lib.mkForce false;
    })
  ];
}
