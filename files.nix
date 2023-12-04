nixos-config-source: { config, pkgs, ... }:
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
      "f+ /var/domain 0444 selfprivacy-api selfprivacy-api - ${domain}"
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
      selfprivacy-nixos-configuration-source = ''
        rm -rf /etc/nixos/{*,.[!.]*}
        cp -r --no-preserve=all ${nixos-config-source}/ -T /etc/nixos/
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
    };
}
