{ pkgs, lib, config, ... }:
let
  cfg = config.services.userdata;
in
{
  services.mastodon = {
    enable = cfg.mastodon.enable;
    localDomain = "mastodon.${cfg.domain}";
    configureNginx = true;
    smtp.fromAddress = "noreply@${cfg.domain}";
  };
}
