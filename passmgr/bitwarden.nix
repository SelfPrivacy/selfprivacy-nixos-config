{ pkgs, config, ... }:
let
  cfg = config.services.userdata;
in
{
  services.vaultwarden = {
    enable = cfg.bitwarden.enable;
    dbBackend = "sqlite";
    backupDir = "/var/lib/bitwarden/backup";
    config = {
      domain = "https://password.${cfg.domain}/";
      signupsAllowed = true;
      rocketPort = 8222;
    };
  };
}
