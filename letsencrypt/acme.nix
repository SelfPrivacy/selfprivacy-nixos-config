{ config, pkgs, ... }:
let
  cfg = config.services.userdata;
in
{
  users.groups.acmerecievers = {
    members = [ "nginx" "dovecot2" "postfix" "virtualMail" "ocserv" ];
  };
  security.acme = {
    acceptTerms = true;
    email = "${cfg.username}@${cfg.domain}";
    certs = {
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
