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
      inherit (import ./common.nix config)
        sp secrets-filepath db-pass-filepath admin-pass-filepath hostName;
    in
    lib.mkIf sp.modules.nextcloud.enable {
      fileSystems = lib.mkIf sp.useBinds {
        "/var/lib/nextcloud" = {
          device = "/volumes/${sp.modules.nextcloud.location}/nextcloud";
          options = [ "bind" ];
        };
      };
      systemd.services.nextcloud-secrets = {
        before = [ "nextcloud-setup.service" ];
        requiredBy = [ "nextcloud-setup.service" ];
        serviceConfig.Type = "oneshot";
        path = with pkgs; [ coreutils jq ];
        script = ''
          install -m 0440 -o nextcloud -g nextcloud -DT \
          <(jq -re '.modules.nextcloud.databasePassword' ${secrets-filepath}) \
          ${db-pass-filepath}

          install -m 0440 -o nextcloud -g nextcloud -DT \
          <(jq -re '.modules.nextcloud.adminPassword' ${secrets-filepath}) \
          ${admin-pass-filepath}
        '';
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
    };
}
