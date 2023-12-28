{ config, lib, pkgs, ... }:
let
  secrets-filepath = "/etc/selfprivacy/secrets.json";
  backup-dir = "/var/lib/bitwarden/backup";
  inherit (import ./common.nix config) bitwarden-env sp;
in
{
  options.selfprivacy.modules.bitwarden = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
    };
    location = lib.mkOption {
      type = lib.types.str;
    };
  };

  config = lib.mkIf config.selfprivacy.modules.bitwarden.enable {
    fileSystems = lib.mkIf sp.useBinds {
      "/var/lib/bitwarden" = {
        device = "/volumes/${sp.modules.bitwarden.location}/bitwarden";
        options = [
          "bind"
          "x-systemd.required-by=bitwarden-secrets.service"
          "x-systemd.required-by=backup-vaultwarden.service"
          "x-systemd.required-by=vaultwarden.service"
          "x-systemd.before=bitwarden-secrets.service"
          "x-systemd.before=backup-vaultwarden.service"
          "x-systemd.before=vaultwarden.service"
        ];
      };
      "/var/lib/bitwarden_rs" = {
        device = "/volumes/${sp.modules.bitwarden.location}/bitwarden_rs";
        options = [
          "bind"
          "x-systemd.required-by=bitwarden-secrets.service"
          "x-systemd.required-by=backup-vaultwarden.service"
          "x-systemd.required-by=vaultwarden.service"
          "x-systemd.before=bitwarden-secrets.service"
          "x-systemd.before=backup-vaultwarden.service"
          "x-systemd.before=vaultwarden.service"
        ];
      };
    };
    services.vaultwarden = {
      enable = true;
      dbBackend = "sqlite";
      backupDir = backup-dir;
      environmentFile = "${bitwarden-env}";
      config = {
        domain = "https://password.${sp.domain}/";
        signupsAllowed = true;
        rocketPort = 8222;
      };
    };
    systemd.services.bitwarden-secrets = {
      before = [ "vaultwarden.service" ];
      requiredBy = [ "vaultwarden.service" ];
      serviceConfig.Type = "oneshot";
      path = with pkgs; [ coreutils jq ];
      script = ''
        set -o nounset

        token="$(jq -r '.bitwarden.adminToken' ${secrets-filepath})"
        if [ "$token" == "null" ]; then
            # If it's null, empty the contents of the file
            bitwarden_env=""
        else
            bitwarden_env="ADMIN_TOKEN=$token"
        fi

        install -C -m 0700 -o vaultwarden -g vaultwarden \
        -d /var/lib/bitwarden

        install -C -m 0600 -o vaultwarden -g vaultwarden -DT \
        <(printf "%s" "$bitwarden_env") ${bitwarden-env}
      '';
    };
    services.nginx.virtualHosts."password.${sp.domain}" = {
      useACMEHost = sp.domain;
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
          proxyPass = "http://127.0.0.1:8222";
        };
      };
    };
    # NixOS upstream bug? Otherwise, backup-vaultwarden cannot find sqlite DB.
    systemd.services.backup-vaultwarden.unitConfig.ConditionPathExists =
      "/var/lib/bitwarden_rs/db.sqlite3";
  };
}
