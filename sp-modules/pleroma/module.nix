{ config, lib, pkgs, ... }:
let
  secrets-filepath = "/etc/selfprivacy/secrets.json";
  inherit (import ./common.nix config) secrets-exs sp;
in
{
  options.selfprivacy.modules.pleroma = {
    enable = lib.mkOption {
      default = false;
      type = with lib; types.nullOr types.bool;
    };
    location = lib.mkOption {
      default = "sda1";
      type = with lib; types.nullOr types.str;
    };
  };
  config = lib.mkIf config.selfprivacy.modules.pleroma.enable {
    fileSystems = lib.mkIf sp.useBinds {
      "/var/lib/pleroma" = {
        device = "/volumes/${sp.modules.pleroma.location}/pleroma";
        options = [ "bind" ];
      };
      "/var/lib/postgresql" = {
        device = "/volumes/${sp.modules.pleroma.location}/postgresql";
        options = [ "bind" ];
      };
    };
    services = {
      pleroma = {
        enable = true;
        user = "pleroma";
        group = "pleroma";
        configs = [
          (builtins.replaceStrings
            [ "$DOMAIN" "$LUSER" ]
            [ sp.domain sp.username ]
            (builtins.readFile ./config.exs.in))
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
    systemd.services.pleroma-secrets = {
      before = [ "pleroma.service" ];
      requiredBy = [ "pleroma.service" ];
      serviceConfig.Type = "oneshot";
      path = with pkgs; [ coreutils jq ];
      script = ''
        set -o nounset

        password="$(jq -re '.databasePassword' ${secrets-filepath})"
        filecontents=$(cat <<- EOF
        import Config
        config :pleroma, Pleroma.Repo,
          password: "$password"
        EOF
        )

        install -m 0750 -o pleroma -g pleroma -DT \
        <(printf "%s" "$filecontents") ${secrets-exs}
      '';
    };
    systemd.tmpfiles.rules = [
      "d /var/lib/pleroma 0700 pleroma pleroma - -"
      "f ${secrets-exs} 0755 pleroma pleroma - -"
    ];
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
    # seems to be an upstream nixpkgs/nixos bug (missing hexdump)
    systemd.services.pleroma.path = [ pkgs.util-linux ];
  };
}