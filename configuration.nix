{ config, pkgs, lib, ... }:
{
  imports = [
    ./variables-module.nix
    ./files.nix
    ./volumes.nix
    ./users.nix
    ./vpn/ocserv.nix
    ./api/api.nix
    ./social/pleroma.nix
    ./letsencrypt/acme.nix
    ./letsencrypt/resolve.nix
    ./backup/restic.nix
    ./passmgr/bitwarden.nix
    ./webserver/nginx.nix
    ./webserver/memcached.nix
    ./resources/limits.nix
    ./videomeet/jitsi.nix
    ./git/gitea.nix
  ];

  services.redis.servers.sp-api = {
    enable = true;
    save = [
      [
        30
        1
      ]
      [
        10
        10
      ]
    ];
    port = 0;
    settings = {
      notify-keyspace-events = "KEA";
    };
  };

  services.do-agent.enable = if config.selfprivacy.userdata.server.provider == "DIGITALOCEAN" then true else false;

  boot.cleanTmpDir = true;
  networking = {
    hostName = config.selfprivacy.userdata.hostname;
    usePredictableInterfaceNames = false;
    firewall = {
      allowedTCPPorts = lib.mkForce [ 22 25 80 143 443 465 587 993 4443 8443 ];
      allowedUDPPorts = lib.mkForce [ 8443 10000 ];
      extraCommands = ''
        iptables --table nat --append POSTROUTING --out-interface eth0 -j MASQUERADE
        iptables --append FORWARD --in-interface vpn00 -j ACCEPT
      '';
    };
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
  };
  time.timeZone = config.selfprivacy.userdata.timezone;
  i18n.defaultLocale = "en_GB.UTF-8";
  users.users.root.openssh.authorizedKeys.keys = config.selfprivacy.userdata.ssh.rootKeys;
  services.openssh = {
    enable = config.selfprivacy.userdata.ssh.enable;
    passwordAuthentication = config.selfprivacy.userdata.ssh.passwordAuthentication;
    permitRootLogin = "yes";
    openFirewall = false;
  };
  programs.ssh = {
    pubkeyAcceptedKeyTypes = [ "ssh-ed25519" "ssh-rsa" ];
    hostKeyAlgorithms = [ "ssh-ed25519" "ssh-rsa" ];
  };
  environment.systemPackages = with pkgs; [
    git
    jq
  ];
  environment.variables = {
    DOMAIN = config.selfprivacy.userdata.domain;
  };
  system.autoUpgrade = {
    enable = config.selfprivacy.userdata.autoUpgrade.enable;
    allowReboot = config.selfprivacy.userdata.autoUpgrade.allowReboot;
    channel = "https://channel.selfprivacy.org/nixos-selfpricacy";
  };
  system.stateVersion = config.selfprivacy.userdata.stateVersion;
  nix = {
    optimise.automatic = true;
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
  };
  services.journald.extraConfig = "SystemMaxUse=500M";
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };
  swapDevices = [
    {
      device = "/swapfile";
      priority = 0;
      size = 2048;
    }
  ];
  security = {
    sudo = {
      enable = true;
    };
  };
}
