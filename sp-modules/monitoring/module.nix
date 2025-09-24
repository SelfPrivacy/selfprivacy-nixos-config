{ config, lib, pkgs, ... }:
let
  cfg = config.selfprivacy.modules.monitoring;
in
{
  options.selfprivacy.modules.monitoring = {
    enable =
      (lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Enable monitoring service";
      })
      // {
        meta = {
          type = "enable";
        };
      };
    location =
      (lib.mkOption {
        type = lib.types.str;
        description = "Monitoring data location";
      })
      // {
        meta = {
          type = "location";
        };
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

    services.opentelemetry-collector = {
      enable = config.selfprivacy.telemetry.enable;
      package = pkgs.opentelemetry-collector-contrib;

      settings = {
        receivers = {
          otlp.protocols.grpc.endpoint = "127.0.0.1:4317";
        };

        processors = {
          batch = {
            timeout = "1s";
            send_batch_size = 1024;
          };

          memory_limiter = {
            check_interval = "5s";
            limit_mib = 512;
            spike_limit_mib = 256;
          };

          attributes = {
            actions = [
              {
                key = "sp.deployment.domain";
                action = "insert";
                value = config.selfprivacy.domain;
              }
            ];
          };
        };

        exporters = {
          otlp = {
            endpoint = config.selfprivacy.telemetry.endpoint;
            headers = config.selfprivacy.telemetry.headers;
          };
          debug = {
            verbosity = "detailed";
          };
        };

        service = {
          pipelines = {
            traces = {
              receivers = [ "otlp" ];
              processors = [ "memory_limiter" "batch" "attributes" ];
              exporters = [ "otlp" ];
            };

            metrics = {
              receivers = [ "otlp" ];
              processors = [ "memory_limiter" "batch" "attributes" ];
              exporters = [ "prometheus" ];
            };

            logs = {
              receivers = [ "otlp" ];
              processors = [ "memory_limiter" "batch" "attributes" ];
              exporters = [ "otlp" "debug" ];
            };
          };
        };
      };
    };

    services.cadvisor = {
      enable = true;
      port = 9003;
      listenAddress = "127.0.0.1";
      extraOptions = [ "--enable_metrics=cpu,memory,diskIO" ];
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
      };
      scrapeConfigs = [
        {
          job_name = "node-exporter";
          static_configs = [
            {
              targets = [ "127.0.0.1:9002" ];
            }
          ];
        }
        {
          job_name = "cadvisor";
          static_configs = [
            {
              targets = [ "127.0.0.1:9003" ];
            }
          ];
        }
      ];
    };
    systemd = {
      services = {
        prometheus.serviceConfig.Slice = "monitoring.slice";
        prometheus-node-exporter.serviceConfig.Slice = "monitoring.slice";
        cadvisor.serviceConfig.Slice = "monitoring.slice";
      };
      slices.monitoring = {
        description = "Monitoring service slice";
      };
    };
  };
}
