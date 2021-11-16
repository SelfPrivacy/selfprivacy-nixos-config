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
    in
    [
      "d /var/restic 0660 restic - - -"
      "d /var/bitwarden 0777 bitwarden_rs bitwarden_rs -"
      "d /var/bitwarden/backup 0777 bitwarden_rs bitwarden_rs -"
      "d /var/lib/pleroma 0600 pleroma pleroma - -"
      "d /var/lib/restic 0600 restic restic - -"
      "f /var/lib/restic/pass 0400 restic restic - ${resticPassword}"
      "f /var/lib/pleroma/secrets.exs 0755 pleroma pleroma - -"
      "f /var/domain 0444 selfprivacy-api selfprivacy-api - ${domain}"
      "f /var/nextcloud-db-pass 0440 nextcloud nextcloud - ${nextcloudDBPass}"
      "f /var/nextcloud-admin-pass 0440 nextcloud nextcloud - ${nextcloudAdminPass}"
      "f /var/cloudflareCredentials.ini 0440 nginx acmerecievers - ${cloudflareCredentials}"
    ];
}
