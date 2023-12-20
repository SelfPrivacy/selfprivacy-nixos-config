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
        options = [
          "bind"
          "x-systemd.required-by=pleroma-secrets.service"
          "x-systemd.required-by=pleroma.service"
        ];
      };
      "/var/lib/postgresql" = {
        device = "/volumes/${sp.modules.pleroma.location}/postgresql";
        options = [
          "bind"
          "x-systemd.required-by=pleroma-secrets.service"
          "x-systemd.required-by=pleroma.service"
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

        install -C -m 0700 -o pleroma -g pleroma -DT \
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
    services.nginx.virtualHosts."social.${sp.domain}" = {
      sslCertificate = "/var/lib/acme/wildcard-${sp.domain}/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/wildcard-${sp.domain}/key.pem";
      root = "/var/www/social.${sp.domain}";
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
          proxyPass = "http://127.0.0.1:4000";
        };
      };
    };
  };
}
