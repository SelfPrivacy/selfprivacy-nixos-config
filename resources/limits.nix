{ pkgs, ... }:
{
  systemd.services = {
    dovecot2 = {
      serviceConfig = {
        cpuAccounting = true;
        cpuQuota = "20%";
        memoryAccounting = true;
        memoryMax = "256M";
        startLimitIntervalSec = 500;
        startLimitBurst = 5;
        blockIOWeigth = 25;
      };
    };
    postfix = {
      serviceConfig = {
        cpuAccounting = true;
        cpuQuota = "20%";
        memoryAccounting = true;
        memoryMax = "256M";
        startLimitIntervalSec = 500;
        startLimitBurst = 5;
        blockIOWeigth = 25;
      };
    };
    ocserv = {
      serviceConfig = {
        cpuAccounting = true;
        cpuQuota = "70%";
        memoryAccounting = true;
        memoryMax = "512M";
        startLimitIntervalSec = 500;
        startLimitBurst = 5;
      };
    };
    nginx = {
      serviceConfig = {
        cpuAccounting = true;
        cpuQuota = "70%";
        memoryAccounting = true;
        memoryMax = "768M";
        startLimitIntervalSec = 500;
        startLimitBurst = 5;
        blockIOWeigth = 10;
      };
    };
  };
}
