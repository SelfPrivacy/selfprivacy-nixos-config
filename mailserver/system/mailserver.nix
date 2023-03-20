{ config, pkgs, lib, ... }:
let
  cfg = config.services.userdata;
in
{
  imports = [
    (builtins.fetchTarball {
      # Pick a commit from the branch you are interested in
      url = "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/6d0d9fb9/nixos-mailserver-6d0d9fb9.tar.gz";

      # And set its hash
      sha256 = "sha256:0h35al73p15z9v8zb6hi5nq987sfl5wp4rm5c8947nlzlnsjl61x";
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
