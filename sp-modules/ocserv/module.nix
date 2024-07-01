{ config, lib, ... }:
let
  domain = config.selfprivacy.domain;
  cert = "${config.security.acme.certs.${domain}.directory}/fullchain.pem";
  key = "${config.security.acme.certs.${domain}.directory}/key.pem";
  cfg = config.selfprivacy.modules.ocserv;
in
{
  options.selfprivacy.modules.ocserv = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
    };
    subdomain = lib.mkOption {
      default = "vpn";
      type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.ocserv.members = [ "ocserv" ];
    users.users.ocserv = {
      isNormalUser = false;
      isSystemUser = true;
      extraGroups = [ "acmereceivers" ];
      group = "ocserv";
    };
    services.ocserv = {
      enable = true;
      config = ''
        socket-file = /var/run/ocserv-socket

        auth = "pam"

        tcp-port = 8443
        udp-port = 8443

        server-cert = ${cert}
        server-key = ${key}

        compression = true

        max-clients = 0
        max-same-clients = 6

        try-mtu-discovery = true

        idle-timeout=1200
        mobile-idle-timeout=2400

        default-domain = ${cfg.subdomain}.${domain}

        device = vpn0

        ipv4-network = 10.10.10.0
        ipv4-netmask = 255.255.255.0

        tunnel-all-dns = true
        dns = 1.1.1.1
        dns = 1.0.0.1

        route = default
      '';
    };
    services.nginx.virtualHosts."${cfg.subdomain}.${domain}" = {
      useACMEHost = domain;
      forceSSL = true;
      extraConfig = ''
        add_header Strict-Transport-Security $hsts_header;
        #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;
        add_header 'Referrer-Policy' 'origin-when-cross-origin';
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
      '';
    };
    systemd.services.ocserv.unitConfig.ConditionPathExists = [ cert key ];
  };
}
