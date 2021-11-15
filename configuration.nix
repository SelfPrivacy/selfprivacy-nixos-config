{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix

    ./variables-module.nix
    ./variables.nix
    ./vscode.nix
    ./files.nix
    ./users.nix
    ./mailserver/system/mailserver.nix
    ./mailserver/system/alps.nix
    ./vpn/ocserv.nix
    ./api/api.nix
    ./api/api-module.nix
    ./social/pleroma.nix
    ./letsencrypt/acme.nix
    ./letsencrypt/resolve.nix
    ./backup/restic.nix
    ./passmgr/bitwarden.nix
    ./webserver/nginx.nix
    ./webserver/memcached.nix
    ./nextcloud/nextcloud.nix
    ./resources/limits.nix
    ./videomeet/jitsi.nix
    ./git/gitea.nix
  ];

  boot.cleanTmpDir = true;
  networking = {
    hostName = config.services.userdata.hostname;
    firewall = {
      allowedTCPPorts = lib.mkForce [ 22 25 80 143 443 465 587 993 8443 ];
      allowedUDPPorts = lib.mkForce [ 8443 ];
    };
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
  };
  time.timeZone = "Europe/Uzhgorod";
  i18n.defaultLocale = "en_GB.UTF-8";
  users.users.root.openssh.authorizedKeys.keys = config.services.userdata.rootSshKeys;
  services.openssh = {
    enable = true;
    passwordAuthentication = true;
    permitRootLogin = "yes";
    openFirewall = false;
  };
  programs.ssh = {
    pubkeyAcceptedKeyTypes = [ "ssh-ed25519" ];
    hostKeyAlgorithms = [ "ssh-ed25519" ];
  };
  environment.systemPackages = with pkgs; [
    git
  ];
  environment.variables = {
    DOMAIN = config.services.userdata.domain;
  };
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = false;
  system.autoUpgrade.channel = https://nixos.org/channels/nixos-21.05-small;
  nix = {
    optimise.automatic = true;
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
  };
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
