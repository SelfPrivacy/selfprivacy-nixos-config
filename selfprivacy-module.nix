{ lib, config, ... }:

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
      type = lib.types.strMatching ''^(xn--)?[a-z0-9][a-z0-9_-]{0,61}[a-z0-9]{0,1}\.(xn--)?([a-z0-9-]{1,61}|[a-z0-9-]{1,30}\.[a-z]{2,})$'';
    };
    timezone = mkOption {
      description = ''
        Timezone used by the server
      '';
      type = types.nullOr types.str;
      default = "Etc/UTC";
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
    sso = {
      enable = mkOption {
        description = "Enable SSO.";
        default = true;
        readOnly = true;
        type = types.nullOr types.bool;
      };
      debug = mkOption {
        description = "Enable debug for SSO.";
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
      default = null;
    };
    hashedMasterPassword = mkOption {
      description = ''
        Hash of the password that was defined at the initial setup process
      '';
      type = types.nullOr types.str;
      default = null;
    };
    sshKeys = mkOption {
      description = ''
        SSH keys of the user that was defined at the initial setup process
      '';
      type = types.listOf types.str;
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
      forceDisableDnsPropagationCheck = mkOption {
        description = "Force disable DNS propagation check.";
        type = types.nullOr types.bool;
        default = false;
      };
    };
    server = {
      provider = mkOption {
        description = "Server provider that was defined at the initial setup process.";
        type = types.str;
      };
      rootPartition = mkOption {
        description = "Root partition to use.";
        type = types.nullOr types.str;
        default = null;
      };
      rootPartitionName = mkOption {
        description = "Canonical root partition name.";
        type = types.nullOr types.str;
        default = null;
      };
      bootloader = mkOption {
        description = "Bootloader configuration.";
        default = {
          type = "none";
        };
        type = types.submodule {
          options = {
            type = mkOption {
              type = types.enum [
                "none"
                "grub-mbr"
                "systemd-boot-efi"
              ];
              description = "Bootloader type.";
            };

            device = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Bootloader installation target";
            };
          };
        };
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
    ################
    #  PostgreSQL  #
    ################
    postgresql = {
      location = mkOption {
        description = "Volume name where to store Postgres data.";
        type = types.nullOr types.str;
        default = null;
      };
    };
    ################
    # passthrough  #
    ################
    passthru = mkOption {
      type = types.submodule {
        freeformType = with types; lazyAttrsOf (uniq unspecified);
        options = { };
      };
      default = { };
      visible = false;
      description = ''
        This attribute allows to share data between modules.
        You can put whatever you want here.
      '';
    };
    #################
    #   Telemetry   #
    #################
    telemetry = {
      enable = mkOption {
        type = types.nullOr types.bool;
        default = false;
      };
      uploadSystemLogs = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable export of system journal over OTLP
        '';
      };
      uploadSystemMetrics = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable export of system metrics (disk usage, memory usage,
          per-systemd-slice resource usage, etc) over OTLP
        '';
      };
      endpoint = mkOption {
        type = types.nullOr types.str;
        default = "http://localhost:4317";
        description = ''
          OTLP gRPC endpoint URL
        '';
      };
      headers = mkOption {
        type = types.attrsOf (types.str);
        default = { };
        example = {
          "authorization" = "Basic REDACTED";
        };
        description = ''
          Additional headers to send with OTLP requests
        '';
      };
    };
    #################
    #  Workarounds  #
    #################
    workarounds = {
      deleteNextcloudAdmin = mkOption {
        description = ''
          Whether to delete an admin user, which is initially created
        '';
        type = types.bool;
        default = false;
      };
      dbusImplementation = mkOption {
        description = ''
          Which DBus implementation to use, required because changing DBus implementation requires reboot
        '';
        type = types.enum [
          "dbus"
          "broker"
        ];
        default = "dbus"; # legacy
      };
      # Should be removed after NixOS 26.11
      initrdImplementation = mkOption {
        description = ''
          Which initrd implementation to use
        '';
        type = types.enum [
          "legacy"
          "systemd"
        ];
        default = "systemd";
      };
    };
  };
}
