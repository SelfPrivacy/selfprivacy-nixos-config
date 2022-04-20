{ pkgs, config, ... }:
let
  domain = config.services.userdata.domain;
in
{
  users.groups.ocserv = {
    members = [ "ocserv" ];
  };
  users.users.ocserv = {
    isNormalUser = false;
    isSystemUser = true;
    extraGroups = [ "ocserv" "acmerecievers" ];
    group = "ocserv";
  };
  services.ocserv = {
    enable = config.services.userdata.ocserv.enable;
    config = ''
      socket-file = /var/run/ocserv-socket

      auth = "pam"

      tcp-port = 8443
      udp-port = 8443

      server-cert = /var/lib/acme/${domain}/fullchain.pem
      server-key = /var/lib/acme/${domain}/key.pem

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
}
