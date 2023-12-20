{ config, lib, ... }:
let
  domain = config.selfprivacy.domain;
in
{
  options.selfprivacy.modules.ocserv = {
    enable = lib.mkOption {
      default = false;
      type = with lib; types.nullOr types.bool;
    };
  };

  config = lib.mkIf config.selfprivacy.modules.ocserv.enable {
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

        server-cert = /var/lib/acme/wildcard-${domain}/fullchain.pem
        server-key = /var/lib/acme/wildcard-${domain}/key.pem

        compression = true

        max-clients = 0
        max-same-clients = 6

        try-mtu-discovery = true

        idle-timeout=1200
        mobile-idle-timeout=2400

        default-domain = vpn.${domain}

        device = vpn0

        ipv4-network = 10.10.10.0
        ipv4-netmask = 255.255.255.0

        tunnel-all-dns = true
        dns = 1.1.1.1
        dns = 1.0.0.1

        route = default
      '';
    };
    services.nginx.virtualHosts."vpn.${domain}" = {
      sslCertificate = "/var/lib/acme/wildcard-${domain}/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/wildcard-${domain}/key.pem";
      forceSSL = true;
      extraConfig = ''
        add_header Strict-Transport-Security $hsts_header;
        #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;
        add_header 'Referrer-Policy' 'origin-when-cross-origin';
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
        expires 10m;
      '';
    };
  };
}
