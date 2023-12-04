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
          RestartSec =
            if lib.versionOlder config.system.nixos.release "23.11"
            then 15 * 60
            else abort "since NixOS 23.11 (#266155) ACME systemd service restart intervals should have been fixed, thus no workarounds are needed";
        };
      };
    };
  };
}
