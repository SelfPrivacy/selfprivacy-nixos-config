{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.selfprivacy-api;
  directionArg =
    if cfg.direction == ""
    then ""
    else "--direction=${cfg.direction}";
in
{
  options.services.selfprivacy-api = {
    enable = mkOption {
      default = true;
      type = types.bool;
      description = ''
        Enable SelfPrivacy API service
      '';
    };
    enableSwagger = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Enable Swagger UI
      '';
    };
    b2Bucket = mkOption {
      type = types.str;
      description = ''
        B2 bucket
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
        ENABLE_SWAGGER = (if cfg.enableSwagger then "1" else "0");
        B2_BUCKET = cfg.b2Bucket;
      } // config.networking.proxy.envVars;
      path = [
        "/var/"
        "/var/dkim/"
        pkgs.coreutils
        pkgs.gnutar
        pkgs.xz.bin
        pkgs.gzip
        pkgs.gitMinimal
        config.nix.package.out
        pkgs.nixos-rebuild
        pkgs.nix
        pkgs.restic
        pkgs.mkpasswd
        pkgs.util-linux
        pkgs.e2fsprogs
        pkgs.iproute2
      ];
      after = [ "network-online.target" ];
      wantedBy = [ "network-online.target" ];
      serviceConfig = {
        User = "root";
        ExecStart = "${pkgs.selfprivacy-graphql-api}/bin/app.py";
        Restart = "always";
        RestartSec = "5";
      };
    };
    systemd.services.selfprivacy-api-worker = {
      description = "Task worker for SelfPrivacy API";
      environment = config.nix.envVars // {
        inherit (config.environment.sessionVariables) NIX_PATH;
        HOME = "/root";
        PYTHONUNBUFFERED = "1";
        ENABLE_SWAGGER = (if cfg.enableSwagger then "1" else "0");
        B2_BUCKET = cfg.b2Bucket;
        PYTHONPATH = pkgs.selfprivacy-graphql-api.pythonPath + ":${pkgs.selfprivacy-graphql-api}/lib/python3.10/site-packages/";
      } // config.networking.proxy.envVars;
      path = [
        "/var/"
        "/var/dkim/"
        pkgs.coreutils
        pkgs.gnutar
        pkgs.xz.bin
        pkgs.gzip
        pkgs.gitMinimal
        config.nix.package.out
        pkgs.nixos-rebuild
        pkgs.restic
        pkgs.mkpasswd
        pkgs.util-linux
        pkgs.e2fsprogs
        pkgs.iproute2
      ];
      after = [ "network-online.target" ];
      wantedBy = [ "network-online.target" ];
      serviceConfig = {
        User = "root";
        ExecStart = "${pkgs.python310Packages.huey}/bin/huey_consumer.py selfprivacy_api.task_registry.huey";
        Restart = "always";
        RestartSec = "5";
      };
    };
    # One shot systemd service to rebuild NixOS using nixos-rebuild
    systemd.services.sp-nixos-rebuild = {
      description = "Upgrade NixOS using nixos-rebuild";
      environment = config.nix.envVars // {
        inherit (config.environment.sessionVariables) NIX_PATH;
        HOME = "/root";
      } // config.networking.proxy.envVars;
      path = [ pkgs.coreutils pkgs.gnutar pkgs.xz.bin pkgs.gzip pkgs.gitMinimal config.nix.package.out pkgs.nixos-rebuild ];
      serviceConfig = {
        User = "root";
        ExecStart = "${pkgs.nixos-rebuild}/bin/nixos-rebuild switch";
        KillMode = "none";
        SendSIGKILL = "no";
      };
    };
    # One shot systemd service to upgrade NixOS using nixos-rebuild
    systemd.services.sp-nixos-upgrade = {
      description = "Upgrade NixOS using nixos-rebuild";
      environment = config.nix.envVars // {
        inherit (config.environment.sessionVariables) NIX_PATH;
        HOME = "/root";
      } // config.networking.proxy.envVars;
      path = [ pkgs.coreutils pkgs.gnutar pkgs.xz.bin pkgs.gzip pkgs.gitMinimal config.nix.package.out pkgs.nixos-rebuild ];
      serviceConfig = {
        User = "root";
        ExecStart = "${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --upgrade";
        KillMode = "none";
        SendSIGKILL = "no";
      };
    };
    # One shot systemd service to rollback NixOS using nixos-rebuild
    systemd.services.sp-nixos-rollback = {
      description = "Rollback NixOS using nixos-rebuild";
      environment = config.nix.envVars // {
        inherit (config.environment.sessionVariables) NIX_PATH;
        HOME = "/root";
      } // config.networking.proxy.envVars;
      path = [ pkgs.coreutils pkgs.gnutar pkgs.xz.bin pkgs.gzip pkgs.gitMinimal config.nix.package.out pkgs.nixos-rebuild ];
      serviceConfig = {
        User = "root";
        ExecStart = "${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --rollback";
        KillMode = "none";
        SendSIGKILL = "no";
      };
    };
  };
}
