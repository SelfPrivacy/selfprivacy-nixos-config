{ config, pkgs, lib, ... }:
let
  cfg = config.services.userdata;
in
{
  imports = [
    (builtins.fetchTarball {
      # Pick a commit from the branch you are interested in
      url = "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/5675b122/nixos-mailserver-5675b122.tar.gz";

      # And set its hash
      sha256 = "1fwhb7a5v9c98nzhf3dyqf3a5ianqh7k50zizj8v5nmj3blxw4pi";
    })
  ];

  services.dovecot2 = {
    enablePAM = lib.mkForce true;
    showPAMFailure = lib.mkForce true;
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
        catchAll = [ cfg.domain ];
        sieveScript = ''
          require ["fileinto", "mailbox"];
          if header :contains "Chat-Version" "1.0"
          {  
            fileinto :create "DeltaChat";
            stop;
          }
        '';
      } // builtins.listToAttrs (builtins.map
        (user: {
          name = "${user.username}@${cfg.domain}";
          value = {
            hashedPassword = user.hashedPassword;
            catchAll = [ cfg.domain ];
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
    };

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
