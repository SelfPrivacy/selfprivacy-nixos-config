{ config, pkgs, ... }:
let
  cfg = config.services.userdata;
in
{
  systemd.tmpfiles.rules =
    let
      nextcloudDBPass = builtins.replaceStrings [ "\n" "\"" "\\" ] [ "\\n" "\\\"" "\\\\" ] cfg.nextcloud.databasePassword;
      nextcloudAdminPass = builtins.replaceStrings [ "\n" "\"" "\\" ] [ "\\n" "\\\"" "\\\\" ] cfg.nextcloud.adminPassword;
      resticPass = builtins.replaceStrings [ "\n" "\"" "\\" ] [ "\\n" "\\\"" "\\\\" ] cfg.resticPassword;
      domain = builtins.replaceStrings [ "\n" "\"" "\\" ] [ "\\n" "\\\"" "\\\\" ] cfg.domain;
      cloudflareCredentials = builtins.replaceStrings [ "\n" "\"" "\\" ] [ "\\n" "\\\"" "\\\\" ] ''
        CF_API_KEY=${cfg.cloudflare.apiKey}
        CLOUDFLARE_DNS_API_TOKEN=${cfg.cloudflare.apiKey}
        CLOUDFLARE_ZONE_API_TOKEN=${cfg.cloudflare.apiKey}
      '';
      rcloneConfig = builtins.replaceStrings [ "\n" "\"" "\\" ] [ "\\n" "\\\"" "\\\\" ] ''
        [backblaze]
        type = b2
        account = ${cfg.backblaze.accountId}
        key = ${cfg.backblaze.accountKey}
      '';
    in
    [
      (if cfg.bitwarden.enable then "d /var/lib/bitwarden 0777 bitwarden_rs bitwarden_rs -" else "")
      (if cfg.bitwarden.enable then "d /var/lib/bitwarden/backup 0777 bitwarden_rs bitwarden_rs -" else "")
      (if cfg.pleroma.enable then "d /var/lib/pleroma 0600 pleroma pleroma - -" else "")
      "d /var/lib/restic 0600 restic - - -"
      "f+ /var/lib/restic/pass 0400 restic - - ${resticPass}"
      "f+ /root/.config/rclone/rclone.conf 0400 root root - ${rcloneConfig}"
      (if cfg.pleroma.enable then "f+ /var/lib/pleroma/secrets.exs 0755 pleroma pleroma - -" else "")
      "f+ /var/domain 0444 selfprivacy-api selfprivacy-api - ${domain}"
      (if cfg.nextcloud.enable then "f+ /var/lib/nextcloud/db-pass 0440 nextcloud nextcloud - ${nextcloudDBPass}" else "")
      (if cfg.nextcloud.enable then "f+ /var/lib/nextcloud/admin-pass 0440 nextcloud nextcloud - ${nextcloudAdminPass}" else "")
      "f+ /var/lib/cloudflare/Credentials.ini 0440 nginx acmerecievers - ${cloudflareCredentials}"
    ];
}
