{ config, lib, pkgs, ... }:
let
  secrets-filepath = "/etc/selfprivacy/secrets.json";
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
        options = [ "bind" ];
      };
      "/var/lib/bitwarden_rs" = {
        device = "/volumes/${sp.modules.bitwarden.location}/bitwarden_rs";
        options = [ "bind" ];
      };
    };
    services.vaultwarden = {
      enable = true;
      dbBackend = "sqlite";
      backupDir = "/var/lib/bitwarden/backup";
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
        # TODO revise this permissions mode
        install -m 0640 -o vaultwarden -g vaultwarden -DT \
        <(printf "%s" "$bitwarden_env") ${bitwarden-env}
      '';
    };
    systemd.tmpfiles.rules = [
      "d /var/lib/bitwarden 0777 vaultwarden vaultwarden -"
      "d /var/lib/bitwarden/backup 0777 vaultwarden vaultwarden -"
      "f ${bitwarden-env} 0640 vaultwarden vaultwarden - -"
    ];
  };
}
