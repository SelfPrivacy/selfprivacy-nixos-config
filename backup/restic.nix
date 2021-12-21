{ config, pkgs, ... }:
let
  cfg = config.services.userdata;
in
{
  services.restic.backups = {
    varBackup = {
      passwordFile = "/var/lib/restic/pass";
      repository = "rclone:backblaze:${cfg.backblaze.bucket}:/sfbackup";
      extraOptions = [ "rclone.args='serve restic --stdio'" ];
      rcloneConfigFile = "/root/.config/rclone/rclone.conf";
      initialize = true;
      paths = [
        "/var"
      ];
      timerConfig = {
        OnCalendar = [ "daily" ];
      };
      user = "restic";
      pruneOpts = [
        "--keep-daily 5"
      ];
    };
  };
  users.users.restic = {
    isNormalUser = false;
    isSystemUser = true;
  };
}
