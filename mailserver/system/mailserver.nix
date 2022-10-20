{ config, pkgs, lib, ... }:
let
  cfg = config.services.userdata;
in
{
  imports = [
    (builtins.fetchTarball {
      # Pick a commit from the branch you are interested in
      url = "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/f535d812/nixos-mailserver-f535d812.tar.gz";

      # And set its hash
      sha256 = "sha256:0csx2i8p7gbis0n5aqpm57z5f9cd8n9yabq04bg1h4mkfcf7mpl6";
    })
  ];

  fileSystems = lib.mkIf cfg.useBinds {
    "/var/vmail" = {
      device = "/volumes/${cfg.email.location}/vmail";
      options = [ "bind" ];
    };
    "/var/sieve" = {
      device = "/volumes/${cfg.email.location}/sieve";
      options = [ "bind" ];
    };
  };

  users.users = {
    virtualMail = {
      isNormalUser = false;
    };
  };

  mailserver = {
    enable = true;
    fqdn = cfg.domain;
    domains = [ cfg.domain ];

    # A list of all login accounts. To create the password hashes, use
    # mkpasswd -m sha-512 "super secret password"
    loginAccounts = {
      "${cfg.username}@${cfg.domain}" = {
        hashedPassword = cfg.hashedMasterPassword;
        sieveScript = ''
          require ["fileinto", "mailbox"];
          if header :contains "Chat-Version" "1.0"
          {
            fileinto :create "DeltaChat";
            stop;
          }
        '';
      };
    } // builtins.listToAttrs (builtins.map
      (user: {
        name = "${user.username}@${cfg.domain}";
        value = {
          hashedPassword = user.hashedPassword;
          sieveScript = ''
            require ["fileinto", "mailbox"];
            if header :contains "Chat-Version" "1.0"
            {
              fileinto :create "DeltaChat";
              stop;
            }
          '';
        };
      })
      cfg.users);

    extraVirtualAliases = {
      "admin@${cfg.domain}" = "${cfg.username}@${cfg.domain}";
    };

    certificateScheme = 1;
    certificateFile = "/var/lib/acme/${cfg.domain}/fullchain.pem";
    keyFile = "/var/lib/acme/${cfg.domain}/key.pem";

    # Enable IMAP and POP3
    enableImap = true;
    enableImapSsl = true;
    enablePop3 = false;
    enablePop3Ssl = false;
    dkimSelector = "selector";

    # Enable the ManageSieve protocol
    enableManageSieve = true;

    virusScanning = false;
  };
}
