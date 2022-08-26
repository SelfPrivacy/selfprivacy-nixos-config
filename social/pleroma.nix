{ pkgs, lib, config, ... }:
let
  cfg = config.services.userdata;
in
{
  fileSystems = lib.mkIf cfg.useBinds {
    "/var/lib/pleroma" = {
      device = "/volumes/${cfg.pleroma.location}/pleroma";
      options = [ "bind" ];
    };
    "/var/lib/postgresql" = {
      device = "/volumes/${cfg.pleroma.location}/postgresql";
      options = [ "bind" ];
    };
  };
  services = {
    pleroma = {
      enable = cfg.pleroma.enable;
      user = "pleroma";
      group = "pleroma";
      configs = [
        (builtins.replaceStrings
          [ "$DOMAIN" "$LUSER" ]
          [ cfg.domain cfg.username ]
          (builtins.readFile ./config.exs))
      ];
    };
    postgresql = {
      enable = true;
      package = pkgs.postgresql_12;
      initialScript = "/etc/setup.psql";
      ensureDatabases = [
        "pleroma"
      ];
      ensureUsers = [
        {
          name = "pleroma";
          ensurePermissions = {
            "DATABASE pleroma" = "ALL PRIVILEGES";
          };
        }
      ];
    };
  };
  environment.etc."setup.psql".text = ''
    CREATE USER pleroma;
    CREATE DATABASE pleroma OWNER pleroma;
    \c pleroma;
    --Extensions made by ecto.migrate that need superuser access
    CREATE EXTENSION IF NOT EXISTS citext;
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  '';
  users.users.pleroma = {
    extraGroups = [ "postgres" ];
    isNormalUser = false;
    isSystemUser = true;
    group = "pleroma";
  };
}
