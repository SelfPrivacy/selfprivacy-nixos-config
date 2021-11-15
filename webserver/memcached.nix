{ pkgs, ... }:
{
  services = {
    memcached = {
      enable = true;
      user = "memcached";
      listen = "127.0.0.1";
      port = 11211;
      maxMemory = 64;
      maxConnections = 1024;
    };
  };
}
