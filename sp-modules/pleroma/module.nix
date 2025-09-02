{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.selfprivacy.modules.pleroma;
  sp = config.selfprivacy;
in
{
  options.selfprivacy.modules.pleroma = {
    enable =
      (lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Enable";
      })
      // {
        meta = {
          type = "enable";
        };
      };
    location =
      (lib.mkOption {
        type = lib.types.str;
        description = "Location";
      })
      // {
        meta = {
          type = "location";
        };
      };
    subdomain =
      (lib.mkOption {
        default = "social";
        type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
        description = "Subdomain";
      })
      // {
        meta = {
          widget = "subdomain";
          type = "string";
          regex = "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
          weight = 0;
        };
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
    };
    services = {
      pleroma = {
        enable = true;
        user = "pleroma";
        group = "pleroma";
        configs = [
          (builtins.replaceStrings [ "$DOMAIN" "$LUSER" ] [ sp.domain sp.username ] (
            builtins.readFile ./config.exs.in
          ))
        ];
      };
      postgresql = {
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

    environment.etc."setup.psql".text = ''
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
    systemd = {
      services = {
        pleroma-secrets = {
          before = [ "pleroma.service" ];
          requiredBy = [ "pleroma.service" ];
          serviceConfig.Type = "oneshot";
          path = with pkgs; [
            coreutils
          ];
          script = ''
            set -o nounset

            filecontents=$(cat <<- EOF
            import Config
            EOF
            )

            install -C -m 0700 -o pleroma -g pleroma -d /var/lib/pleroma

            install -C -m 0600 -o pleroma -g pleroma -DT \
            <(printf "%s" "$filecontents") ${secrets-exs}
          '';
        };
        pleroma = {
          # seems to be an upstream nixpkgs/nixos bug (missing hexdump)
          path = [ pkgs.util-linux ];
          serviceConfig.Slice = "pleroma.slice";
        };
      };
      slices.pleroma = {
        description = "Pleroma service slice";
      };
    };
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
  };
}
