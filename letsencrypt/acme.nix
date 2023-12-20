{ config, lib, pkgs, ... }:
let
  cfg = config.selfprivacy;
  dnsCredentialsTemplates = {
    DIGITALOCEAN = "DO_AUTH_TOKEN=$TOKEN";
    CLOUDFLARE = ''
      CF_API_KEY=$TOKEN
      CLOUDFLARE_DNS_API_TOKEN=$TOKEN
      CLOUDFLARE_ZONE_API_TOKEN=$TOKEN
    '';
    DESEC = "DESEC_TOKEN=$TOKEN";
  };
  dnsCredentialsTemplate = dnsCredentialsTemplates.${cfg.dns.provider};
  acme-env-filepath = "/var/lib/selfprivacy/acme-env";
  secrets-filepath = "/etc/selfprivacy/secrets.json";
  dnsPropagationCheckExceptions = [ "DIGITALOCEAN" ];
in
{
  users.groups.acmereceivers.members = [ "nginx" ];
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "${cfg.username}@${cfg.domain}";
      server = if cfg.dns.useStagingACME then "https://acme-staging-v02.api.letsencrypt.org/directory" else "https://acme-v02.api.letsencrypt.org/directory";
      dnsPropagationCheck =
        ! (lib.elem cfg.dns.provider dnsPropagationCheckExceptions);
      reloadServices = [ "nginx" ];
    };
    certs = lib.mkForce {
      "wildcard-${cfg.domain}" = {
        domain = "*.${cfg.domain}";
        extraDomainNames = [ "${cfg.domain}" ];
        group = "acmereceivers";
        dnsProvider = lib.strings.toLower cfg.dns.provider;
        credentialsFile = acme-env-filepath;
      };
      "${cfg.domain}" = {
        domain = cfg.domain;
        group = "acmereceivers";
        webroot = "/var/lib/acme/acme-challenge";
      };
    };
  };
  systemd.services.acme-secrets = {
    before = [ "acme-${cfg.domain}.service" ];
    requiredBy = [ "acme-${cfg.domain}.service" ];
    serviceConfig.Type = "oneshot";
    path = with pkgs; [ coreutils jq ];
    script = ''
      set -o nounset

      TOKEN="$(jq -re '.dns.apiKey' ${secrets-filepath})"
      filecontents=$(cat <<- EOF
      ${dnsCredentialsTemplate}
      EOF
      )

      install -m 0440 -o root -g acmereceivers -DT \
      <(printf "%s\n" "$filecontents") ${acme-env-filepath}
    '';
  };
}
