{ config, pkgs, lib, ... }:
let
  redis-sp-api-srv-name = "sp-api";
  sp-print-api-token = pkgs.writeShellApplication {
    name = "sp-print-api-token";
    runtimeInputs = with pkgs; [ redis ];
    text = ''
      hash_token="$(redis-cli -s /run/redis-${redis-sp-api-srv-name}/redis.sock keys "token_repo:tokens:*" | head -n 1)"
      hash_token="''${hash_token#"token_repo:tokens:"}"

      token="$(redis-cli -s /run/redis-${redis-sp-api-srv-name}/redis.sock HGETALL "token_repo:tokens:$hash_token")"
      token="$(echo "$token" | sed -n '2p')"

      echo "$token"
    '';
  };
in
{
  imports = [
    ./selfprivacy-module.nix
    ./volumes.nix
    ./users.nix
    ./letsencrypt/acme.nix
    ./letsencrypt/resolve.nix
    ./webserver/nginx.nix
    ./webserver/memcached.nix
    # ./resources/limits.nix
  ];

  # We have to use this version to be able to migrate from Gitea.
  nixpkgs.config.permittedInsecurePackages = [
    "forgejo-1.20.6-1-unstable-2024-04-18"
  ];

  fileSystems."/".options = [ "noatime" ];

  services.selfprivacy-api.enable = true;

  services.redis.servers.${redis-sp-api-srv-name} = {
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

  boot.tmp.cleanOnBoot = true;
  networking = {
    hostName = config.selfprivacy.hostname;
    domain = config.selfprivacy.domain;
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
    settings = {
      PasswordAuthentication = config.selfprivacy.ssh.passwordAuthentication;
      PermitRootLogin = "yes";
      LoginGraceTime = 0;
    };
    openFirewall = false;

  };
  programs.ssh = {
    pubkeyAcceptedKeyTypes = [ "ssh-ed25519" "ssh-rsa" "ecdsa-sha2-nistp256" ];
    hostKeyAlgorithms = [ "ssh-ed25519" "ssh-rsa" ];
  };
  environment.systemPackages = with pkgs; [
    git
    jq
    sp-print-api-token
  ];
  # consider environment.defaultPackages = lib.mkForce [];
  documentation.enable = false; # no {man,info}-pages & docs, etc to save space
  # (or create a systemd service with `ConditionFirstBoot=yes`?)
  systemd.tmpfiles.rules = [
    "# Completely remove remnants of NIXOS_LUSTRATE."
    "R! /old-root"
  ];
  system.stateVersion =
    lib.mkIf (config.selfprivacy.stateVersion != null)
      config.selfprivacy.stateVersion;
  system.autoUpgrade = {
    enable = config.selfprivacy.autoUpgrade.enable;
    allowReboot = config.selfprivacy.autoUpgrade.allowReboot;
    # TODO get attribute name from selfprivacy options
    flake = "/etc/nixos#default";
  };
  systemd.services.nixos-upgrade.serviceConfig.WorkingDirectory = "/etc/nixos";
  # TODO parameterize URL somehow; run nix flake update as non-root user
  systemd.services.nixos-upgrade.serviceConfig.ExecCondition =
    pkgs.writeShellScript "flake-update-script" ''
      set -o xtrace
      if ${config.nix.package.out}/bin/nix flake update \
      --override-input selfprivacy-nixos-config git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-nixos-config.git?ref=flakes
      then
          if ${pkgs.diffutils}/bin/diff -u -r /etc/selfprivacy/nixos-config-source/ /etc/nixos/
          then
              set +o xtrace
              echo "No configuration changes detected. Nothing to upgrade."
              exit 1
          fi
      else
          # ExecStart must not start after 255 exit code, service must fail.
          exit 255
      fi
    '';
  nix = {
    channel.enable = false;

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
