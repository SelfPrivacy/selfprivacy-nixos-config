{ config, pkgs, ... }:
let
  cfg = config.services.userdata;
in
{
  services.restic.backups = {
    options = {
      passwordFile = "/etc/restic/resticPasswd";
      repository = "s3:s3.anazonaws.com/${cfg.backblaze.bucket}";
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
  environment.etc."restic/resticPasswd".text = ''
    ${cfg.resticPassword}
  '';
  environment.etc."restic/s3Passwd".text = ''
    AWS_ACCESS_KEY_ID=${cfg.backblaze.accountId}
    AWS_SECRET_ACCESS_KEY=${cfg.backblaze.accountKey}
  '';
}
