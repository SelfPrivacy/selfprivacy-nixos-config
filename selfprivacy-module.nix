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
      # see: https://regexr.com/7p7ep, https://stackoverflow.com/a/26987741
      type = lib.types.strMatching ''^(xn--)?[a-z0-9][a-z0-9_-]{0,61}[a-z0-9]{0,1}\.(xn--)?([a-z0-9\-]{1,61}|[a-z0-9-]{1,30}\.[a-z]{2,})$'';
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
      description = "State version of the server";
      type = types.nullOr types.str;
      default = null;
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
    #############
    #    DNS    #
    #############
    dns = {
      provider = mkOption {
        description = "DNS provider that was defined at the initial setup process.";
        type = types.nullOr types.str;
      };
      useStagingACME = mkOption {
        description = "Use staging ACME server. Default is false";
        type = types.nullOr types.bool;
        default = false;
      };
    };
    server = {
      provider = mkOption {
        description = "Server provider that was defined at the initial setup process.";
        type = types.str;
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
          Root SSH authorized keys
        '';
        type = types.nullOr (types.listOf types.str);
        default = [ "" ];
      };
      passwordAuthentication = mkOption {
        description = ''
          Password authentication for SSH
        '';
        default = false;
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
  };
}
