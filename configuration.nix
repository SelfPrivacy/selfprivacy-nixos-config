{ config, pkgs, lib, system, ... }:
{
  imports = [
    ./variables-module.nix
    ./volumes.nix
    ./users.nix
    ./letsencrypt/acme.nix
    ./letsencrypt/resolve.nix
    ./webserver/nginx.nix
    ./webserver/memcached.nix
    # ./resources/limits.nix
  ];

  fileSystems."/".options = [ "noatime" ];

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

  services.do-agent.enable = if config.selfprivacy.server.provider == "DIGITALOCEAN" then true else false;

  boot.cleanTmpDir = true;
  networking = {
    hostName = config.selfprivacy.hostname;
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
  time.timeZone = config.selfprivacy.timezone;
  i18n.defaultLocale = "en_GB.UTF-8";
  users.users.root.openssh.authorizedKeys.keys = config.selfprivacy.ssh.rootKeys;
  services.openssh = {
    enable = config.selfprivacy.ssh.enable;
    passwordAuthentication = config.selfprivacy.ssh.passwordAuthentication;
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
  # consider environment.defaultPackages = lib.mkForce [];
  environment.variables = {
    DOMAIN = config.selfprivacy.domain;
  };
  documentation.enable = false; # no {man,info}-pages & docs, etc to save space
  system.autoUpgrade = {
    enable = config.selfprivacy.autoUpgrade.enable;
    allowReboot = config.selfprivacy.autoUpgrade.allowReboot;
    channel = "https://channel.selfprivacy.org/nixos-selfpricacy";
  };
  nix = {
    # TODO uncomment when NixOS version is at least 23.05
    # nix.channel.enable = false;

    # daemonCPUSchedPolicy = "idle";
    # daemonIOSchedClass = "idle";
    # daemonIOSchedPriority = 7;
    # this is superseded by nix.settings.auto-optimise-store.
    # optimise.automatic = true;

    gc = {
      automatic = true; # TODO it's debatable, because of IO&CPU load
      options = "--delete-older-than 7d";
    };
  };
  nix.settings = {
    sandbox = true;
    experimental-features = [ "nix-command" "flakes" "repl-flake" ];
    # auto-optimise-store = true;

    # evaluation restrictions:
    # restrict-eval = true;
    # allowed-uris = [];
    allow-dirty = false;
  };
  nix.package =
    if lib.versionAtLeast pkgs.nix.version "2.15.2"
    then pkgs.nix.out
    else pkgs.nixUnstable.out;
  nixpkgs.hostPlatform = system;
  services.journald.extraConfig = "SystemMaxUse=500M";
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1; # TODO why is it here by default, for VPN only?
  };
  # TODO must be configurable and determined at nixos-infect stage
  swapDevices = [
    {
      device = "/swapfile";
      priority = 0;
      size = 2048;
    }
  ];
  # TODO why is sudo needed?
  security = {
    sudo = {
      enable = true;
    };
  };
  systemd.enableEmergencyMode = false;
  systemd.coredump.enable = false;
}
