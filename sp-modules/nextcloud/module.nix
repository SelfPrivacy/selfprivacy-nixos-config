{ config, lib, pkgs, ... }:
{
  options.selfprivacy.modules.nextcloud = with lib; {
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
      sp = config.selfprivacy;
      secrets-filepath = "/etc/selfprivacy/secrets.json";
      db-pass-filepath = "/var/lib/nextcloud/db-pass";
      admin-pass-filepath = "/var/lib/nextcloud/admin-pass";
      hostName = "cloud.${sp.domain}";
    in
    lib.mkIf sp.modules.nextcloud.enable
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
        fileSystems = lib.mkIf sp.useBinds {
          "/var/lib/nextcloud" = {
            device = "/volumes/${sp.modules.nextcloud.location}/nextcloud";
            options = [ "bind" ];
          };
        };
        services.nextcloud = {
          enable = true;
          package = pkgs.nextcloud25;
          inherit hostName;

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
        services.nginx.virtualHosts.${hostName} = {
          sslCertificate = "/var/lib/acme/${sp.domain}/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/${sp.domain}/key.pem";
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
          locations = {
            "/" = {
              proxyPass = "http://127.0.0.1:80/";
            };
          };
        };
      }
    # FIXME do we really want to delete passwords on module deactivation!?
    //
    lib.mkIf (!sp.modules.nextcloud.enable) {
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
