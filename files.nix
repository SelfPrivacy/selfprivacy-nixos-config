{ config, pkgs, ... }:
let
  cfg = config.selfprivacy;
  dnsCredentialsTemplates = {
    DIGITALOCEAN = "DO_AUTH_TOKEN=REPLACEME";
    CLOUDFLARE = ''
      CF_API_KEY=REPLACEME
      CLOUDFLARE_DNS_API_TOKEN=REPLACEME
      CLOUDFLARE_ZONE_API_TOKEN=REPLACEME
    '';
    DESEC = "DESEC_TOKEN=REPLACEME";
  };
  dnsCredentialsTemplate = dnsCredentialsTemplates.${cfg.dns.provider};
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
      (if cfg.bitwarden.enable then "f /var/lib/bitwarden/.env 0640 vaultwarden vaultwarden - -" else "")
    ];
  system.activationScripts =
    let
      jq = "${pkgs.jq}/bin/jq";
      sed = "${pkgs.gnused}/bin/sed";
    in
    {
      nixos-lustrate = ''
        rm -rf /old-root
      '';
      cloudflareCredentials = ''
        mkdir -p /var/lib/cloudflare
        chmod 0440 /var/lib/cloudflare
        chown nginx:acmereceivers /var/lib/cloudflare
        echo '${dnsCredentialsTemplate}' > /var/lib/cloudflare/Credentials.ini
        ${sed} -i "s/REPLACEME/$(cat /etc/selfprivacy/secrets.json | ${jq} -r '.dns.apiKey')/g" /var/lib/cloudflare/Credentials.ini
        chmod 0440 /var/lib/cloudflare/Credentials.ini
        chown nginx:acmereceivers /var/lib/cloudflare/Credentials.ini
      '';
      resticCredentials = ''
        mkdir -p /root/.config/rclone
        chmod 0400 /root/.config/rclone
        chown root:root /root/.config/rclone
        echo '[backblaze]' > /root/.config/rclone/rclone.conf
        echo 'type = b2' >> /root/.config/rclone/rclone.conf
        echo 'account = REPLACEME1' >> /root/.config/rclone/rclone.conf
        echo 'key = REPLACEME2' >> /root/.config/rclone/rclone.conf

        ${sed} -i "s/REPLACEME1/$(cat /etc/selfprivacy/secrets.json | ${jq} -r '.backup.accountId')/g" /root/.config/rclone/rclone.conf
        ${sed} -i "s/REPLACEME2/$(cat /etc/selfprivacy/secrets.json | ${jq} -r '.backup.accountKey')/g" /root/.config/rclone/rclone.conf

        chmod 0400 /root/.config/rclone/rclone.conf
        chown root:root /root/.config/rclone/rclone.conf

        cat /etc/selfprivacy/secrets.json | ${jq} -r '.resticPassword' > /var/lib/restic/pass
        chmod 0400 /var/lib/restic/pass
        chown restic /var/lib/restic/pass
      '';
      pleromaCredentials =
        if cfg.pleroma.enable then ''
          echo 'import Config' > /var/lib/pleroma/secrets.exs
          echo 'config :pleroma, Pleroma.Repo,' >> /var/lib/pleroma/secrets.exs
          echo '  password: "REPLACEME"' >> /var/lib/pleroma/secrets.exs

          ${sed} -i "s/REPLACEME/$(cat /etc/selfprivacy/secrets.json | ${jq} -r '.databasePassword')/g" /var/lib/pleroma/secrets.exs

          chmod 0750 /var/lib/pleroma/secrets.exs
          chown pleroma:pleroma /var/lib/pleroma/secrets.exs
        '' else ''
          rm -f /var/lib/pleroma/secrets.exs
        '';
      bitwardenCredentials =
        if cfg.bitwarden.enable then ''
          mkdir -p /var/lib/bitwarden
          token=$(cat /etc/selfprivacy/secrets.json | ${jq} -r '.bitwarden.adminToken')
          if [ "$token" == "null" ]; then
            # If it's null, delete the contents of the file
            > /var/lib/bitwarden/.env
          else
            echo "ADMIN_TOKEN=$token" > /var/lib/bitwarden/.env
          fi
          chmod 0640 /var/lib/bitwarden/.env
          chown vaultwarden:vaultwarden /var/lib/bitwarden/.env
        '' else ''
          rm -f /var/lib/bitwarden/.env
        '';
    };
}
