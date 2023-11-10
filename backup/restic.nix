{ config, ... }:
let
  cfg = config.selfprivacy.userdata;
in
{
  services.restic.backups = {
    options = {
      passwordFile = "/etc/restic/resticPasswd";
      repository = "s3:s3.anazonaws.com/${cfg.backup.bucket}";
      initialize = true;
      paths = [
        "/var/dkim"
        "/var/vmail"
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
    group = "restic";
  };
}
