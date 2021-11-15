{ config, pkgs, ... }:
let
  domain = config.services.userdata.domain;
in
{
  systemd = {
    services = {
      "acme-${domain}" = {
        serviceConfig = {
          StartLimitBurst = 5;
          StartLimitIntervalSec = 5;
          Restart = "on-failure";
        };
      };
      "nginx-config-reload" = {
        serviceConfig = {
          After = [ "acme-${domain}.service" ];
        };
      };
    };
  };
}
