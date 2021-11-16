{ config, lib, pkgs, ... }:

with lib;

let
  selfprivacy-api = pkgs.callPackage ./api-package.nix { };
  cfg = config.services.selfprivacy-api;
  directionArg =
    if cfg.direction == ""
    then ""
    else "--direction=${cfg.direction}";
in
{
  options.services.selfprivacy-api = {
    enable = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Enable SelfPrivacy API service
      '';
    };
    token = mkOption {
      type = types.str;
      description = ''
        SelfPrivacy API token
      '';
    };
    enableSwagger = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Enable Swagger UI
      '';
    };
    b2AccountId = mkOption {
      type = types.str;
      description = ''
        B2 account ID
      '';
    };
    b2AccountKey = mkOption {
      type = types.str;
      description = ''
        B2 account key
      '';
    };
    resticPassword = mkOption {
      type = types.str;
      description = ''
        Restic password
      '';
    };
  };
  config = lib.mkIf cfg.enable {

    systemd.services.selfprivacy-api = {
      description = "API Server used to control system from the mobile application";
      environment = config.nix.envVars // {
        inherit (config.environment.sessionVariables) NIX_PATH;
        HOME = "/root";
        PYTHONUNBUFFERED = "1";
        AUTH_TOKEN = cfg.token;
        ENABLE_SWAGGER = (if cfg.enableSwagger then "1" else "0");
        B2_ACCOUNT_ID = cfg.b2AccountId;
        B2_ACCOUNT_KEY = cfg.b2AccountKey;
        RESTIC_PASSWORD = cfg.resticPassword;
      } // config.networking.proxy.envVars;
      path = [ "/var/" "/var/dkim/" pkgs.coreutils pkgs.gnutar pkgs.xz.bin pkgs.gzip pkgs.gitMinimal config.nix.package.out pkgs.nixos-rebuild pkgs.restic pkgs.mkpasswd ];
      after = [ "network-online.target" ];
      wantedBy = [ "network-online.target" ];
      serviceConfig = {
        User = "root";
        ExecStart = "${selfprivacy-api}/bin/app.py";
        Restart = "always";
        RestartSec = "5";
      };
    };
  };
}
