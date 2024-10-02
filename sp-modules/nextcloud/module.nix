{ config, lib, pkgs, ... }:
{
  options.selfprivacy.modules.nextcloud = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    location = mkOption {
      type = types.str;
    };
    subdomain = lib.mkOption {
      default = "cloud";
      type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
    };
  };

  config =
    let
      inherit (import ./common.nix config)
        sp secrets-filepath db-pass-filepath admin-pass-filepath;
      cfg = sp.modules.nextcloud;
      hostName = "${cfg.subdomain}.${sp.domain}";
    in
    lib.mkIf sp.modules.nextcloud.enable {
      fileSystems = lib.mkIf sp.useBinds {
        "/var/lib/nextcloud" = {
          device = "/volumes/${cfg.location}/nextcloud";
          options = [
            "bind"
            "x-systemd.required-by=nextcloud-setup.service"
            "x-systemd.required-by=nextcloud-secrets.service"
            "x-systemd.before=nextcloud-setup.service"
            "x-systemd.before=nextcloud-secrets.service"
          ];
        };
      };
      systemd = {
        services = {
          phpfpm-nextcloud.serviceConfig.Slice = lib.mkForce "nextcloud.slice";
          nextcloud-setup.serviceConfig.Slice = "nextcloud.slice";
          nextcloud-cron.serviceConfig.Slice = "nextcloud.slice";
          nextcloud-update-db.serviceConfig.Slice = "nextcloud.slice";
          nextcloud-update-plugins.serviceConfig.Slice = "nextcloud.slice";
          nextcloud-secrets = {
            before = [ "nextcloud-setup.service" ];
            requiredBy = [ "nextcloud-setup.service" ];
            serviceConfig.Type = "oneshot";
            path = with pkgs; [ coreutils jq ];
            script = ''
              databasePassword=$(jq -re '.modules.nextcloud.databasePassword' ${secrets-filepath})
              adminPassword=$(jq -re '.modules.nextcloud.adminPassword' ${secrets-filepath})

              install -C -m 0440 -o nextcloud -g nextcloud -DT \
              <(printf "%s\n" "$databasePassword") \
              ${db-pass-filepath}

              install -C -m 0440 -o nextcloud -g nextcloud -DT \
              <(printf "%s\n" "$adminPassword") \
              ${admin-pass-filepath}
            '';
          };
        };
        slices.nextcloud = {
          description = "Nextcloud service slice";
        };
      };
      services.nextcloud = {
        enable = true;
        package = pkgs.nextcloud29;
        inherit hostName;

        # Use HTTPS for links
        https = true;

        # auto-update Nextcloud Apps
        autoUpdateApps.enable = true;
        # set what time makes sense for you
        autoUpdateApps.startAt = "05:00:00";

        settings = {
          # further forces Nextcloud to use HTTPS
          overwriteprotocol = "https";
        };

        config = {
          dbtype = "sqlite";
          dbuser = "nextcloud";
          dbname = "nextcloud";
          dbpassFile = db-pass-filepath;
          adminpassFile = admin-pass-filepath;
          adminuser = "admin";
        };
      };
      services.nginx.virtualHosts.${hostName} = {
        useACMEHost = sp.domain;
        forceSSL = true;
      };
    };
}
