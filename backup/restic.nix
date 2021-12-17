{ config, pkgs, ... }:
let
  cfg = config.services.userdata;
in
{

  systemd = {
    services = {
      "restic-backup" = {
        description = "Userdata restic backup trigger";
        serviceConfig = {
          Type = "simple";
          User = "restic";
          ExecStart = "${pkgs.restic}/bin/restic -o rclone.args="serve restic --stdio" -r rclone:backblaze:${cfg.backblaze.bucket}:/sfbackup --verbose --json backup /var";
        };
      };
    };
    timers = {
      "restic-scheduled-backup" = {
        wantedBy = [ "timers.target" ];
        partOf = [ "restic-backup.service" ];
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
