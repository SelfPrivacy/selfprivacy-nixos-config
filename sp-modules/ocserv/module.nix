{ config, lib, ... }:
let
  domain = config.selfprivacy.domain;
  cert = "${config.security.acme.certs.${domain}.directory}/fullchain.pem";
  key = "${config.security.acme.certs.${domain}.directory}/key.pem";
  cfg = config.selfprivacy.modules.ocserv;
in
{
  options.selfprivacy.modules.ocserv = {
    enable = (lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable";
    }) // {
      meta = {
        type = "enable";
      };
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

        default-domain = ${domain}

        device = vpn0

        ipv4-network = 10.10.10.0
        ipv4-netmask = 255.255.255.0

        tunnel-all-dns = true
        dns = 1.1.1.1
        dns = 1.0.0.1

        route = default
      '';
    };
    systemd = {
      services = {
        ocserv = {
          unitConfig.ConditionPathExists = [ cert key ];
          serviceConfig.Slice = "ocserv.slice";
        };
      };
      slices.ocserv = {
        description = "ocserv service slice";
      };
    };
  };
}
