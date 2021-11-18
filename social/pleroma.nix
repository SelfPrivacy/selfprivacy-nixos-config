{ pkgs, config, ... }:
let
  cfg = config.services.userdata;
in
{
  nixpkgs.overlays = [
    (self: super: {
      pleroma-otp = self.callPackage ./pleroma-package.nix { };
    })
  ];
  services = {
    pleroma = {
      enable = cfg.pleroma.enable;
      user = "pleroma";
      group = "pleroma";
      configs = [
        (builtins.replaceStrings
        [ "$DOMAIN" "$LUSER" "$DB_PASSWORD" ]
        [ cfg.domain cfg.username cfg.databasePassword ]
        (builtins.readFile ./config.exs))
      ];
    };
    postgresql = {
      enable = true;
      package = pkgs.postgresql_12;
      initialScript = "/etc/setup.psql";
    };
  };
  environment.etc."setup.psql".text = ''
    CREATE USER pleroma WITH ENCRYPTED PASSWORD '${cfg.databasePassword}';
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
  };
}
