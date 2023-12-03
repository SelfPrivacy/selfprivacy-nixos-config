{ config, lib, pkgs, ... }:
let
  sp = config.selfprivacy;
  secrets-filepath = "/etc/selfprivacy/secrets.json";
  rclone-conf-filepath = "/root/.config/rclone/rclone.conf";
in
{
  options.selfprivacy.modules.restic = {
    enable = lib.mkOption {
      default = false;
      type = with lib.types; nullOr bool;
    };
    # TODO AWS region should be configurable too?
    s3BucketName = lib.mkOption {
      type = lib.types.str;
    };
  };
  config = lib.mkIf config.selfprivacy.modules.restic.enable {
    services.restic.backups = {
      options = {
        # TODO is it the right location?
        passwordFile = "/etc/restic/resticPasswd";
        repository = "s3:s3.anazonaws.com/${sp.modules.restic.s3BucketName}";
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
    users.groups.restic.members = [ "restic" ];
    users.users.restic = {
      isNormalUser = false;
      isSystemUser = true;
      group = "restic";
    };
    systemd.tmpfiles.rules = [
      "d /var/lib/restic 0600 restic - - -"
    ];
    systemd.services.restic-secrets = {
      before = [ "restic-backups-options.service" ];
      requiredBy = [ "restic-backups-options.service" ];
      serviceConfig.Type = "oneshot";
      path = with pkgs; [ coreutils gnused jq ];
      script = ''
        set -o nounset

        account="$(jq -re '.modules.restic.accountId' ${secrets-filepath})"
        key="$(jq -re '.modules.restic.accountKey' ${secrets-filepath})"
        rclone_conf=$(cat <<- EOF
        [backblaze]
        account = $account
        key = $key
        EOF
        )
        install -m 0400 -o root -g root -DT \
        <(printf "%s" "$rclone_conf") ${rclone-conf-filepath}

        install -m 0400 -o restic -g restic -DT \
        <(jq -re '.resticPassword' ${secrets-filepath}) /var/lib/restic/pass
      '';
    };
  };
}
