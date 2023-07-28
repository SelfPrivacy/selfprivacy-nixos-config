{ config, pkgs, lib, ... }:
let
  cfg = config.services.userdata;
  dnsPropagationCheckExceptions = [ "DIGITALOCEAN" ];
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
      dnsPropagationCheck = if lib.elem cfg.dns.provider dnsPropagationCheckExceptions then false else true;
      reloadServices = [ "nginx" ];
    };
    certs = lib.mkForce {
      "wildcard-${cfg.domain}" = {
        domain = "*.${cfg.domain}";
        group = "acmerecievers";
        dnsProvider = lib.strings.toLower cfg.dns.provider;
        credentialsFile = "/var/lib/cloudflare/Credentials.ini";
      };
      "${cfg.domain}" = {
        domain = cfg.domain;
        group = "acmerecievers";
        webroot = "/var/lib/acme/acme-challenge";
      };
    };
  };
}
