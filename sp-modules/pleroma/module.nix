{ config, lib, pkgs, ... }:
let
  secrets-filepath = "/etc/selfprivacy/secrets.json";
  cfg = config.selfprivacy.modules.pleroma;
  inherit (import ./common.nix config) secrets-exs sp;
in
{
  options.selfprivacy.modules.pleroma = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
    };
    location = lib.mkOption {
      type = lib.types.str;
    };
    subdomain = lib.mkOption {
      default = "social";
      type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
    };
  };
  config = lib.mkIf cfg.enable {
    fileSystems = lib.mkIf sp.useBinds {
      "/var/lib/pleroma" = {
        device = "/volumes/${cfg.location}/pleroma";
        options = [
          "bind"
          "x-systemd.required-by=pleroma-secrets.service"
          "x-systemd.required-by=pleroma.service"
          "x-systemd.before=pleroma.service"
          "x-systemd.before=pleroma-secrets.service"
        ];
      };
      "/var/lib/postgresql" = {
        device = "/volumes/${cfg.location}/postgresql";
        options = [
          "bind"
          "x-systemd.required-by=pleroma-secrets.service"
          "x-systemd.required-by=pleroma.service"
          "x-systemd.before=pleroma-secrets.service"
          "x-systemd.before=pleroma.service"
        ];
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
            ensureDBOwnership = true;
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

        install -C -m 0700 -o pleroma -g pleroma -d /var/lib/pleroma

        install -C -m 0600 -o pleroma -g pleroma -DT \
        <(printf "%s" "$filecontents") ${secrets-exs}
      '';
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
    # seems to be an upstream nixpkgs/nixos bug (missing hexdump)
    systemd.services.pleroma.path = [ pkgs.util-linux ];
    services.nginx.virtualHosts."${cfg.subdomain}.${sp.domain}" = {
      useACMEHost = sp.domain;
      root = "/var/www/${cfg.subdomain}.${sp.domain}";
      forceSSL = true;
      extraConfig = ''
        add_header Strict-Transport-Security $hsts_header;
        #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;
        add_header 'Referrer-Policy' 'origin-when-cross-origin';
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
      '';
      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:4000";
        };
      };
    };
    systemd = {
      services = {
        pleroma.serviceConfig.Slice = "pleroma.slice";
      };
      slices.pleroma = {
        description = "Pleroma service slice";
      };
    };
  };
}
