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
