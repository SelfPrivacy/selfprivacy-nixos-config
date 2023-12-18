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
      type = with lib.types; nullOr bool;
    };
    location = lib.mkOption {
      default = "sda1";
      type = with lib.types; nullOr str;
    };
  };

  config = lib.mkIf config.selfprivacy.modules.bitwarden.enable {
    fileSystems = lib.mkIf sp.useBinds {
      "/var/lib/bitwarden" = {
        device = "/volumes/${sp.modules.bitwarden.location}/bitwarden";
        options = [
          "bind"
          "x-systemd.required-by=bitwarden-secrets.service"
          "x-systemd.required-by=vaultwarden.service"
        ];
      };
      "/var/lib/bitwarden_rs" = {
        device = "/volumes/${sp.modules.bitwarden.location}/bitwarden_rs";
        options = [
          "bind"
          "x-systemd.required-by=bitwarden-secrets.service"
          "x-systemd.required-by=vaultwarden.service"
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
  };
}
