{ config, lib, ... }:
let
  domain = config.selfprivacy.domain;
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
    };
  };
}
