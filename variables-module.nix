{ lib, ... }:

with lib;
{
  options.selfprivacy = {
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
        default = false;
        type = types.nullOr types.bool;
      };
      allowReboot = mkOption {
        description = "Allow the server to reboot during the upgrade.";
        default = false;
        type = types.nullOr types.bool;
      };
    };
    stateVersion = mkOption {
      description = ''
        State version of the server
      '';
      type = types.str;
      default = "22.11";
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
    dns = {
      provider = mkOption {
        description = "DNS provider that was defined at the initial setup process. Default is ClOUDFLARE";
        type = types.nullOr types.str;
      };
      useStagingACME = mkOption {
        description = "Use staging ACME server. Default is false";
        type = types.nullOr types.bool;
      };
    };
    backup = {
      bucket = mkOption {
        description = "Bucket name used for userdata backups";
        type = types.nullOr types.str;
      };
    };
    server = {
      provider = mkOption {
        description = "Server provider that was defined at the initial setup process. Default is HETZNER";
        type = types.nullOr types.str;
      };
    };
    ##############
    #  Services  #
    ##############
    bitwarden = {
      enable = mkOption {
        default = false;
        type = types.nullOr types.bool;
      };
      location = mkOption {
        default = "sda1";
        type = types.nullOr types.str;
      };
    };
    email = {
      location = mkOption {
        default = "sda1";
        type = types.nullOr types.str;
      };
    };
    gitea = {
      enable = mkOption {
        default = false;
        type = types.nullOr types.bool;
      };
      location = mkOption {
        default = "sda1";
        type = types.nullOr types.str;
      };
    };
    pleroma = {
      enable = mkOption {
        default = false;
        type = types.nullOr types.bool;
      };
      location = mkOption {
        default = "sda1";
        type = types.nullOr types.str;
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
    ##############
    #   Volumes  #
    ##############
    volumes = mkOption {
      description = ''
        Volumes that will be created on the server
      '';
      type = types.nullOr (types.listOf (types.attrsOf types.anything));
      default = [ ];
    };
    useBinds = mkOption {
      type = types.nullOr types.bool;
      default = false;
      description = "Whether to bind-mount vmail and sieve folders";
    };
    ##############
    #   Modules  #
    ##############
    # modules =
  };
}
