{ pkgs, lib, config, ... }:
let
  cfg = config.services.userdata;
in
{
  fileSystems = lib.mkIf cfg.useBinds {
    "/var/lib/bitwarden" = {
      device = "/volumes/${cfg.bitwarden.location}/bitwarden";
      options = [ "bind" ];
    };
    "/var/lib/bitwarden_rs" = {
      device = "/volumes/${cfg.bitwarden.location}/bitwarden_rs";
      options = [ "bind" ];
    };
  };
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
