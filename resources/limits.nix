{
  systemd.services = {
    dovecot2 = {
      serviceConfig = {
        CpuAccounting = true;
        CpuQuota = "20%";
        MemoryAccounting = true;
        MemoryMax = "256M";
        StartLimitIntervalSec = 500;
        StartLimitBurst = 5;
        BlockIOWeigth = 25;
      };
    };
    postfix = {
      serviceConfig = {
        CpuAccounting = true;
        CpuQuota = "20%";
        MemoryAccounting = true;
        MemoryMax = "256M";
        StartLimitIntervalSec = 500;
        StartLimitBurst = 5;
        BlockIOWeigth = 25;
      };
    };
    ocserv = {
      serviceConfig = {
        CpuAccounting = true;
        CpuQuota = "70%";
        MemoryAccounting = true;
        MemoryMax = "512M";
        StartLimitIntervalSec = 500;
        StartLimitBurst = 5;
      };
    };
    nginx = {
      serviceConfig = {
        CpuAccounting = true;
        CpuQuota = "70%";
        MemoryAccounting = true;
        MemoryMax = "768M";
        StartLimitIntervalSec = 500;
        StartLimitBurst = 5;
        BlockIOWeight = 10;
      };
    };
  };
}
