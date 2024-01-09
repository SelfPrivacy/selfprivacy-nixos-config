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
  };

  config =
    let
      inherit (import ./common.nix config)
        sp secrets-filepath db-pass-filepath admin-pass-filepath;
      hostName = "cloud.${sp.domain}";
    in
    lib.mkIf sp.modules.nextcloud.enable {
      fileSystems = lib.mkIf sp.useBinds {
        "/var/lib/nextcloud" = {
          device = "/volumes/${sp.modules.nextcloud.location}/nextcloud";
          options = [
            "bind"
            "x-systemd.required-by=nextcloud-setup.service"
            "x-systemd.required-by=nextcloud-secrets.service"
            "x-systemd.before=nextcloud-setup.service"
            "x-systemd.before=nextcloud-secrets.service"
          ];
        };
      };
      systemd.services.nextcloud-secrets = {
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
      services.nextcloud = {
        enable = true;
        package = pkgs.nextcloud26;
        inherit hostName;

        # Use HTTPS for links
        https = true;

        # auto-update Nextcloud Apps
        autoUpdateApps.enable = true;
        # set what time makes sense for you
        autoUpdateApps.startAt = "05:00:00";

        config = {
          # further forces Nextcloud to use HTTPS
          overwriteProtocol = "https";

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
