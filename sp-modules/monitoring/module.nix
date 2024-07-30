{ config, lib, ... }:
let
  cfg = config.selfprivacy.modules.monitoring;
in
{
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
    security.auditd.enable = true;
    security.audit.enable = true;
    security.audit.rules = [
      "-w /root -p war -k root"
      "-w /root/.ssh -p wa -k rootkey"
      "-w /etc/nixos -p w -k nixosconfig"
      "-w /etc/selfprivacy.nix -p w -k selfprivacyfolder"
      "-a always,exclude -F msgtype=CWD"
      "-a always,exclude -F msgtype=PATH"
      "-a always,exclude -F "
      "-a exit,never -F arch=b64 -F a0=systemctl -F a1=show"
      # "-a exit,always -F arch=b64 -S execve"
      "-a always,exit -F arch=b64 -S kexec_load -k KEXEC"
      "-a always,exit -F arch=b64 -S mknod -S mknodat -k specialfiles"
      "-a always,exit -F arch=b64 -S mount -S umount2 -F auid!=-1 -k mount"
      "-a always,exit -F arch=b64 -S swapon -S swapoff -F auid!=-1 -k swap"
      "-a always,exit -F arch=b64 -S adjtimex -S settimeofday -S clock_settime -k time"
      "-w /etc/group -p wa -k etcgroup"
      "-w /etc/passwd -p wa -k etcpasswd"
      "-w /etc/shadow -k etcpasswd"
      "-w /etc/sudoers -p wa -k actions"
      "-a always,exit -F arch=b64 -S sethostname -S setdomainname -k network_modifications"
      "-a always,exit -F arch=b64 -S open -F dir=/etc -F success=0 -k unauthedfileaccess"
      "-a always,exit -F arch=b64 -S open -F dir=/bin -F success=0 -k unauthedfileaccess"
      "-a always,exit -F arch=b64 -S open -F dir=/usr/bin -F success=0 -k unauthedfileaccess"
      "-a always,exit -F arch=b64 -S open -F dir=/var -F success=0 -k unauthedfileaccess"
      "-a always,exit -F arch=b64 -S open -F dir=/home -F success=0 -k unauthedfileaccess"
      "-a always,exit -F arch=b64 -S open -F dir=/srv -F success=0 -k unauthedfileaccess"

    ];
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
          static_configs = [{
            targets = [ "127.0.0.1:9002" ];
          }];
        }
        {
          job_name = "cadvisor";
          static_configs = [{
            targets = [ "127.0.0.1:9003" ];
          }];
        }
      ];
    };
    services.logrotate = {
      enable = true;
      settings = {
        "/var/log/audit/audit.log" = {
          rotate = 7;
          compress = true;
          missingok = true;
          notifempty = true;
          sharedscripts = true;
          postrotate = "systemctl kill -s USR1 auditd.service";
        };
      };
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
