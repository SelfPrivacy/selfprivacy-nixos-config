{ pkgs, config, ... }:
let
  cfg = config.services.userdata;
in
{
  services.bitwarden_rs = {
    enable = cfg.bitwarden.enable;
    dbBackend = "sqlite";
    backupDir = "/var/bitwarden/backup";
    config = {
      domain = "https://password.${cfg.domain}/";
      signupsAllowed = true;
      rocketPort = 8222;
    };
  };
}
