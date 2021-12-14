{ config, pkgs, ... }:
let
  cfg = config.services.userdata;
in
{

  systemd = {
    services = {
      "restic-scheduled-backup" = {
        description = "Userdata restic backup trigger";
        serviceConfig = {
          Type = "simple";
          User = "restic";
          ExecStart = "${pkgs.restic}/bin/restic -r rclone:backblaze:${cfg.backblaze.bucket}:/sfbackup --verbose --json backup /var";
        };
      };
    };
    timers = {
      "restic-scheduled-backup" = {
        wantedBy = [ "timers.target" ];
        partOf = [ "restic-scheduled-backup.service" ];
        timerConfig = {
          OnCalendar = "daily";
        };
      };
    };
  };
  users.users.restic = {
    isNormalUser = false;
    isSystemUser = true;
  };
}
