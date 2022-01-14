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
    # General server options
    hostname = mkOption {
      description = "The hostname of the server.";
      type = types.nullOr types.str;
    };
    domain = mkOption {
      description = ''
        Domain used by the server
      '';
      type = types.nullOr types.str;
    };
    timezone = mkOption {
      description = ''
        Timezone used by the server
      '';
      type = types.nullOr types.str;
      default = "Europe/Uzhgorod";
    };
    autoUpgrade = {
      enable = mkOption {
        description = "Enable auto-upgrade of the server.";
        default = true;
        type = types.nullOr types.bool;
      };
      allowReboot = mkOption {
        description = "Allow the server to reboot during the upgrade.";
        default = false;
        type = types.nullOr types.bool;
      };
    };
    ########################
    # Server admin options #
    ########################
    username = mkOption {
      description = ''
        Username that was defined at the initial setup process
      '';
      type = types.nullOr types.str;
    };
    hashedMasterPassword = mkOption {
      description = ''
        Hash of the password that was defined at the initial setup process
      '';
      type = types.nullOr types.str;
    };
    sshKeys = mkOption {
      description = ''
        SSH keys of the user that was defined at the initial setup process
      '';
      type = types.nullOr (types.listOf types.str);
      default = [ ];
    };
    ###############
    # API options #
    ###############
    api = {
      token = mkOption {
        description = ''
          API token used to authenticate with the server
        '';
        type = types.nullOr types.str;
      };
      enableSwagger = mkOption {
        default = true;
        description = ''
          Enable Swagger UI
        '';
        type = types.bool;
      };
      skippedMigrations = mkOption {
        default = [ ];
        description = ''
          List of migrations that should be skipped
        '';
        type = types.listOf types.str;
      };
    };
    #############
    #  Secrets  #
    #############
    backblaze = {
      bucket = mkOption {
        description = "Bucket name used for userdata backups";
        type = types.nullOr types.str;
      };
      accountId = mkOption {
        description = "Backblaze B2 Account ID";
        type = types.nullOr types.str;
      };
      accountKey = mkOption {
        description = "Backblaze B2 Account Key.";
        type = types.nullOr types.str;
      };
    };
    cloudflare = {
      apiKey = mkOption {
        description = "Cloudflare API Key.";
        type = types.nullOr types.str;
      };
    };
    ##############
    #  Services  #
    ##############
    databasePassword = mkOption {
      description = ''
        Password for the database
      '';
      type = types.nullOr types.str;
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
        type = types.nullOr types.str;
      };
      adminPassword = mkOption {
        description = ''
          Password for the nextcloud admin user
        '';
        type = types.nullOr types.str;
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
    #############
    #  Backups  #
    #############
    resticPassword = mkOption {
      description = ''
        Password for the restic
      '';
      type = types.nullOr types.str;
    };
    #########
    #  SSH  #
    #########
    ssh = {
      enable = mkOption {
        default = true;
        type = types.nullOr types.bool;
      };
      rootKeys = mkOption {
        description = ''
          Root SSH Keys
        '';
        type = types.nullOr (types.listOf types.str);
        default = [ "" ];
      };
      passwordAuthentication = mkOption {
        description = ''
          Password authentication for SSH
        '';
        default = true;
        type = types.nullOr types.bool;
      };
    };
    ###########
    #  Users  #
    ###########
    users = mkOption {
      description = ''
        Users that will be created on the server
      '';
      type = types.nullOr (types.listOf (types.attrsOf types.anything));
      default = [ ];
    };
  };
}
