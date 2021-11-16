{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.userdata;
  directionArg =
    if cfg.direction == ""
    then ""
    else "--direction=${cfg.direction}";
in
{
  options.services.userdata = {
    enable = mkOption {
      default = true;
      type = types.nullOr types.bool;
    };
    hostname = mkOption {
      description = "The hostname of the server.";
      type = types.nullOr types.string;
    };
    domain = mkOption {
      description = ''
        Domain used by the server
      '';
      type = types.nullOr types.string;
    };
    username = mkOption {
      description = ''
        Username that was defined at the initial setup process
      '';
      type = types.nullOr types.string;
    };
    hashedMasterPassword = mkOption {
      description = ''
        Hash of the password that was defined at the initial setup process
      '';
      type = types.nullOr types.string;
    };
    api = {
      token = mkOption {
        description = ''
          API token used to authenticate with the server
        '';
        type = types.nullOr types.string;
      };
    };
    backblaze = {
      bucket = mkOption {
        description = "Bucket name used for userdata backups";
        type = types.nullOr types.string;
      };
      accountId = mkOption {
        description = "Backblaze B2 Account ID";
        type = types.nullOr types.string;
      };
      accountKey = mkOption {
        description = "Backblaze B2 Account Key.";
        type = types.nullOr types.string;
      };
    };
    cloudflare = {
      apiKey = mkOption {
        description = "Cloudflare API Key.";
        type = types.nullOr types.string;
      };
    };
    databasePassword = mkOption {
      description = ''
        Password for the database
      '';
      type = types.nullOr types.string;
    };
    bitwarden = {
      enable = mkOption {
        default = false;
        type = types.nullOr types.bool;
      };
    };
    gitea = {
      enable = mkOption {
        default = false;
        type = types.nullOr types.bool;
      };
    };
    nextcloud = {
      enable = mkOption {
        default = true;
        type = types.nullOr types.bool;
      };
      databasePassword = mkOption {
        description = ''
          Password for the nextcloud database
        '';
        type = types.nullOr types.string;
      };
      adminPassword = mkOption {
        description = ''
          Password for the nextcloud admin user
        '';
        type = types.nullOr types.string;
      };
    };
    pleroma = {
      enable = mkOption {
        default = false;
        type = types.nullOr types.bool;
      };
    };
    jitsi = {
      enable = mkOption {
        default = false;
        type = types.nullOr types.bool;
      };
    };
    ocserv = {
      enable = mkOption {
        default = true;
        type = types.nullOr types.bool;
      };
    };
    resticPassword = mkOption {
      description = ''
        Password for the restic
      '';
      type = types.nullOr types.string;
    };
    ssh = {
      enable = mkOption {
        default = true;
        type = types.nullOr types.bool;
      };
      rootKeys = mkOption {
        description = ''
        Root SSH Keys
        '';
        type = types.nullOr (types.listOf types.string);
      };
      passwordAuthentication = mkOption {
        description = ''
          Password authentication for SSH
        '';
        default = true;
        type = types.nullOr types.bool;
      };
    };
    timezone = mkOption {
      description = ''
        Timezone used by the server
      '';
      type = types.nullOr types.string;
      default = "Europe/Uzhgorod";
    };
    users = mkOption {
      description = ''
        Users that will be created on the server
      '';
      type = types.nullOr (types.listOf (types.attrsOf types.anything));
    };
  };
}
