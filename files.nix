{ config, pkgs, ... }:
let
  cfg = config.services.userdata;
in
{
  systemd.tmpfiles.rules =
    let
      domain = builtins.replaceStrings [ "\n" "\"" "\\" "%" ] [ "\\n" "\\\"" "\\\\" "%%" ] cfg.domain;
    in
    [
      (if cfg.bitwarden.enable then "d /var/lib/bitwarden 0777 vaultwarden vaultwarden -" else "")
      (if cfg.bitwarden.enable then "d /var/lib/bitwarden/backup 0777 vaultwarden vaultwarden -" else "")
      (if cfg.pleroma.enable then "d /var/lib/pleroma 0700 pleroma pleroma - -" else "")
      "d /var/lib/restic 0600 restic - - -"
      (if cfg.pleroma.enable then "f /var/lib/pleroma/secrets.exs 0755 pleroma pleroma - -" else "")
      "f+ /var/domain 0444 selfprivacy-api selfprivacy-api - ${domain}"
    ];
  system.activationScripts =
    let
      jq = "${pkgs.jq}/bin/jq";
      sed = "${pkgs.gnused}/bin/sed";
    in
    {
      nextcloudSecrets =
        if cfg.nextcloud.enable then ''
          cat /etc/nixos/userdata/userdata.json | ${jq} -r '.nextcloud.databasePassword' > /var/lib/nextcloud/db-pass
          chmod 0440 /var/lib/nextcloud/db-pass
          chown nextcloud:nextcloud /var/lib/nextcloud/db-pass

          cat /etc/nixos/userdata/userdata.json | ${jq} -r '.nextcloud.adminPassword' > /var/lib/nextcloud/admin-pass
          chmod 0440 /var/lib/nextcloud/admin-pass
          chown nextcloud:nextcloud /var/lib/nextcloud/admin-pass
        ''
        else ''
          rm -f /var/lib/nextcloud/db-pass
          rm -f /var/lib/nextcloud/admin-pass
        '';
      cloudflareCredentials = ''
        mkdir -p /var/lib/cloudflare
        chmod 0440 /var/lib/cloudflare
        chown nginx:acmerecievers /var/lib/cloudflare
        echo 'CF_API_KEY=REPLACEME' > /var/lib/cloudflare/Credentials.ini
        echo 'CLOUDFLARE_DNS_API_TOKEN=REPLACEME' >> /var/lib/cloudflare/Credentials.ini
        echo 'CLOUDFLARE_ZONE_API_TOKEN=REPLACEME' >> /var/lib/cloudflare/Credentials.ini
        ${sed} -i "s/REPLACEME/$(cat /etc/nixos/userdata/userdata.json | ${jq} -r '.cloudflare.apiKey')/g" /var/lib/cloudflare/Credentials.ini
        chmod 0440 /var/lib/cloudflare/Credentials.ini
        chown nginx:acmerecievers /var/lib/cloudflare/Credentials.ini
      '';
      resticCredentials = ''
        mkdir -p /root/.config/rclone
        chmod 0400 /root/.config/rclone
        chown root:root /root/.config/rclone
        echo '[backblaze]' > /root/.config/rclone/rclone.conf
        echo 'type = b2' >> /root/.config/rclone/rclone.conf
        echo 'account = REPLACEME1' >> /root/.config/rclone/rclone.conf
        echo 'key = REPLACEME2' >> /root/.config/rclone/rclone.conf

        ${sed} -i "s/REPLACEME1/$(cat /etc/nixos/userdata/userdata.json | ${jq} -r '.backblaze.accountId')/g" /root/.config/rclone/rclone.conf
        ${sed} -i "s/REPLACEME2/$(cat /etc/nixos/userdata/userdata.json | ${jq} -r '.backblaze.accountKey')/g" /root/.config/rclone/rclone.conf

        chmod 0400 /root/.config/rclone/rclone.conf
        chown root:root /root/.config/rclone/rclone.conf

        cat /etc/nixos/userdata/userdata.json | ${jq} -r '.resticPassword' > /var/lib/restic/pass
        chmod 0400 /var/lib/restic/pass
        chown restic /var/lib/restic/pass
      '';
      pleromaCredentials =
        if cfg.pleroma.enable then ''
          echo 'import Config' > /var/lib/pleroma/secrets.exs
          echo 'config :pleroma, Pleroma.Repo,' >> /var/lib/pleroma/secrets.exs
          echo '  password: "REPLACEME"' >> /var/lib/pleroma/secrets.exs

          ${sed} -i "s/REPLACEME/$(cat /etc/nixos/userdata/userdata.json | ${jq} -r '.databasePassword')/g" /var/lib/pleroma/secrets.exs

          chmod 0750 /var/lib/pleroma/secrets.exs
          chown pleroma:pleroma /var/lib/pleroma/secrets.exs
        '' else ''
          rm -f /var/lib/pleroma/secrets.exs
        '';
    };
}
