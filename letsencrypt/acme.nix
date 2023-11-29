{ config, pkgs, lib, ... }:
let
  cfg = config.selfprivacy;
in
{
  users.groups.acmereceivers = {
    members = [ "nginx" "dovecot2" "postfix" "virtualMail" "ocserv" ];
  };
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "${cfg.username}@${cfg.domain}";
      server = if cfg.dns.useStagingACME then "https://acme-staging-v02.api.letsencrypt.org/directory" else "https://acme-v02.api.letsencrypt.org/directory";
      dnsPropagationCheck = false;
      reloadServices = [ "nginx" ];
    };
    certs = lib.mkForce {
      "${cfg.domain}" = {
        domain = "*.${cfg.domain}";
        extraDomainNames = [ "${cfg.domain}" ];
        group = "acmereceivers";
        dnsProvider = lib.strings.toLower cfg.dns.provider;
        credentialsFile = "/var/lib/cloudflare/Credentials.ini";
      };
    };
  };
}
