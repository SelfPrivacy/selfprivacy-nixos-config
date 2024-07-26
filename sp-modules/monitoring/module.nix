{config, lib, ...}: let
  cfg = config.selfprivacy.modules.monitoring;
in {
  options.selfprivacy.modules.monitoring = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
    };
    location = lib.mkOption {
      type = lib.types.str;
    };
  };
  config = lib.mkIf cfg.enable {
    fileSystems = lib.mkIf config.selfprivacy.useBinds {
      "/var/lib/prometheus2" = {
        device = "/volumes/${cfg.location}/prometheus";
        options = [
          "bind"
          "x-systemd.required-by=prometheus.service"
          "x-systemd.before=prometheus.service"
        ];
      };
    };
    services.prometheus = {
      enable = true;
      port = 9001;
      listenAddress = "127.0.0.1";
      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          port = 9002;
          listenAddress = "127.0.0.1";
        };
        systemd = {
          enable = true;
          port = 9003;
          listenAddress = "127.0.0.1";
        };
      };
      scrapeConfigs = [
        {
          job_name = "node-exporter";
          static_configs = [{
            targets = [ "127.0.0.1:9002" ];
          }];
        }
        {
          job_name = "systemd-exporter";
          static_configs = [{
            targets = [ "127.0.0.1:9003" ];
          }];
        }
      ];
    };
  };
}
