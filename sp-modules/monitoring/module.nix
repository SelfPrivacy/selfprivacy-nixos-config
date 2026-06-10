{
  config,
  lib,
  pkgs,
  selfprivacy,
  ...
}:
let
  cfg = config.selfprivacy.modules.monitoring;
in
{
  options.selfprivacy.modules.monitoring = {
    enable = selfprivacy.types.enableOption "monitoring service";
    location = selfprivacy.types.locationOption;
  };
  config =
    let
      telemetryCfg = config.selfprivacy.telemetry;

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
    in
    lib.mkMerge [
      (lib.mkIf cfg.enable {
        fileSystems = lib.mkIf config.selfprivacy.useBinds {
          "/var/lib/prometheus2" = {
            fsType = "auto";
            device = "/volumes/${cfg.location}/prometheus";
            options = [
              "bind"
              "x-systemd.required-by=prometheus.service"
              "x-systemd.before=prometheus.service"
            ];
          };
        };

        # We use cadvisor to get cpu, memory and I/O metrics by systemd slices.
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
          inherit scrapeConfigs;
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
      })
      (lib.mkIf (cfg.enable && telemetryCfg.enable) {
        fileSystems = lib.mkIf config.selfprivacy.useBinds {
          "/var/lib/private/opentelemetry-collector" = {
            fsType = "auto";
            device = "/volumes/${cfg.location}/opentelemetry-collector";
            options = [
              "bind"
              "x-systemd.required-by=opentelemetry-collector.service"
              "x-systemd.before=opentelemetry-collector.service"
            ];
          };
        };

        services.opentelemetry-collector = {
          enable = telemetryCfg.enable;
          package = pkgs.opentelemetry-collector-contrib;

          settings = {
            service.telemetry.metrics.level = "none";

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

              resource.attributes = [
                {
                  key = "sp.deployment.domain";
                  action = "insert";
                  value = config.selfprivacy.domain;
                }
              ];
            };

            exporters = {
              otlp = {
                endpoint = telemetryCfg.endpoint;
                headers = telemetryCfg.headers;
              };
            };

            service = {
              pipelines = {
                traces = {
                  receivers = [ "otlp" ];
                  processors = [
                    "memory_limiter"
                    "batch"
                    "resource"
                  ];
                  exporters = [ "otlp" ];
                };

                metrics = {
                  receivers = [
                    "otlp"
                  ];
                  processors = [
                    "memory_limiter"
                    "batch"
                    "resource"
                  ];
                  exporters = [ "otlp" ];
                };

                logs = {
                  receivers = [
                    "otlp"
                  ];
                  processors = [
                    "memory_limiter"
                    "batch"
                    "resource"
                  ];
                  exporters = [
                    "otlp"
                  ];
                };
              };
            };
          };
        };

        systemd.services.opentelemetry-collector.serviceConfig.Slice = "monitoring.slice";
      })
      (lib.mkIf (cfg.enable && telemetryCfg.enable && telemetryCfg.uploadSystemLogs) {
        services.opentelemetry-collector.settings = {
          extensions."file_storage/journald" = {
            directory = "journald";
            create_directory = true;
          };
          receivers.journald = {
            storage = "file_storage/journald";
          };
          service = {
            extensions = [ "file_storage/journald" ];
            pipelines.logs.receivers = [
              "journald"
            ];
          };
        };
      })
      (lib.mkIf (cfg.enable && telemetryCfg.enable && telemetryCfg.uploadSystemMetrics) {
        services.opentelemetry-collector.settings = {
          receivers.prometheus = {
            # we can't just use config.services.prometheus... because nix will set all unset fields to null,
            # so for example metrics_path would become null breaking the collector.
            config.scrape_configs = scrapeConfigs;
          };
        };
        services.opentelemetry-collector.settings.service.pipelines.metrics.receivers = [
          "prometheus"
        ];
      })
    ];
}
