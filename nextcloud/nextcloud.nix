{ pkgs, lib, config, ... }:
let
  cfg = config.services.userdata;
in
{
  fileSystems = lib.mkIf cfg.useBinds {
    "/var/lib/nextcloud" = {
      device = "/volumes/${cfg.nextcloud.location}/nextcloud";
      options = [ "bind" ];
    };
  };
  services.nextcloud = {
    enable = cfg.nextcloud.enable;
    package = pkgs.nextcloud25;
    hostName = "cloud.${cfg.domain}";

    # Use HTTPS for links
    https = false;

    # Auto-update Nextcloud Apps
    autoUpdateApps.enable = true;
    # Set what time makes sense for you
    autoUpdateApps.startAt = "05:00:00";

    config = {
      # Further forces Nextcloud to use HTTPS
      overwriteProtocol = "https";

      # Nextcloud PostegreSQL database configuration, recommended over using SQLite
      dbtype = "sqlite";
      dbuser = "nextcloud";
      dbhost = "/run/postgresql"; # nextcloud will add /.s.PGSQL.5432 by itself
      dbname = "nextcloud";
      dbpassFile = "/var/lib/nextcloud/db-pass";

      adminpassFile = "/var/lib/nextcloud/admin-pass";
      adminuser = "admin";
    };
  };
}
