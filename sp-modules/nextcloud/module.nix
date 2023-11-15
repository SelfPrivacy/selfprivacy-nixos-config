{ config, lib, pkgs, ... }:
{
  options.selfprivacy.userdata.nextcloud = with lib; {
    enable = mkOption {
      type = types.nullOr types.bool;
      default = false;
    };
    location = mkOption {
      type = types.nullOr types.str;
      default = "sda1";
    };
  };

  config =
    let
      cfg = config.selfprivacy.userdata;
      secrets-filepath = "/etc/nixos/userdata/userdata.json";
      db-pass-filepath = "/var/lib/nextcloud/db-pass";
      admin-pass-filepath = "/var/lib/nextcloud/admin-pass";
    in
    lib.mkIf cfg.nextcloud.enable
      {
        system.activationScripts.nextcloudSecrets = ''
          mkdir -p /var/lib/nextcloud
          ${pkgs.jq}/bin/jq < ${secrets-filepath} -r '.nextcloud.databasePassword' > ${db-pass-filepath}
          chmod 0440 ${db-pass-filepath}
          chown nextcloud:nextcloud ${db-pass-filepath}

          ${pkgs.jq}/bin/jq < ${secrets-filepath} -r '.nextcloud.adminPassword' > ${admin-pass-filepath}
          chmod 0440 ${admin-pass-filepath}
          chown nextcloud:nextcloud ${admin-pass-filepath}
        '';
        fileSystems = lib.mkIf cfg.useBinds {
          "/var/lib/nextcloud" = {
            device = "/volumes/${cfg.nextcloud.location}/nextcloud";
            options = [ "bind" ];
          };
        };
        services.nextcloud = {
          enable = true;
          package = pkgs.nextcloud25;
          hostName = "cloud.${cfg.domain}";

          # Use HTTPS for links
          https = false;

          # auto-update Nextcloud Apps
          autoUpdateApps.enable = true;
          # set what time makes sense for you
          autoUpdateApps.startAt = "05:00:00";

          config = {
            # further forces Nextcloud to use HTTPS
            overwriteProtocol = "https";

            dbtype = "sqlite";
            dbuser = "nextcloud";
            dbhost = "/run/postgresql"; # nextcloud adds .s.PGSQL.5432 by itself
            dbname = "nextcloud";
            dbpassFile = db-pass-filepath;
            adminpassFile = admin-pass-filepath;
            adminuser = "admin";
          };
        };
      }
    # FIXME do we really want to delete passwords on module deactivation!?
    //
    lib.mkIf (!cfg.nextcloud.enable) {
      system.activationScripts.nextcloudSecrets =
        lib.trivial.warn
          (
            "nextcloud service is disabled, " +
            "${db-pass-filepath} and ${admin-pass-filepath} will be removed!"
          )
          ''
            rm -f ${db-pass-filepath}
            rm -f ${admin-pass-filepath}
          '';
    };
}
