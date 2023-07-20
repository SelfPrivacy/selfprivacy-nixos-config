{ config, pkgs, ... }:
let
  cfg = config.services.userdata;
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
      nextcloudSecrets =
        if cfg.nextcloud.enable then ''
          mkdir -p /var/lib/nextcloud
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
        echo '${dnsCredentialsTemplate}' > /var/lib/cloudflare/Credentials.ini
        ${sed} -i "s/REPLACEME/$(cat /etc/nixos/userdata/userdata.json | ${jq} -r '.dns.apiKey')/g" /var/lib/cloudflare/Credentials.ini
        chmod 0440 /var/lib/cloudflare/Credentials.ini
        chown nginx:acmerecievers /var/lib/cloudflare/Credentials.ini
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
      bitwardenCredentials =
        if cfg.bitwarden.enable then ''
          mkdir -p /var/lib/bitwarden
          token=$(cat /etc/nixos/userdata/userdata.json | ${jq} -r '.bitwarden.adminToken')
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
