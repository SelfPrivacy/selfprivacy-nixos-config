{ config, pkgs, lib, ... }:
let
  cfg = config.services.userdata;
in
{
  users.groups.acmerecievers = {
    members = [ "nginx" "dovecot2" "postfix" "virtualMail" "ocserv" ];
  };
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "${cfg.username}@${cfg.domain}";
      server = if cfg.dns.useStagingACME then "https://acme-staging-v02.api.letsencrypt.org/directory" else "https://acme-v02.api.letsencrypt.org/directory";
    };
    certs = lib.mkForce {
      "${cfg.domain}" = {
        domain = "*.${cfg.domain}";
        extraDomainNames = [ "${cfg.domain}" ];
        group = "acmerecievers";
        dnsProvider = "cloudflare";
        credentialsFile = "/var/lib/cloudflare/Credentials.ini";
      };
      "meet.${cfg.domain}" = {
        domain = "meet.${cfg.domain}";
        group = "acmerecievers";
        dnsProvider = "cloudflare";
        credentialsFile = "/var/lib/cloudflare/Credentials.ini";
      };
    };
  };
}
