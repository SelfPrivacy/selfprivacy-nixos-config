{ config, lib, ... }:
let
  cfg = config.selfprivacy.userdata;
in
{
  fileSystems = lib.mkIf
    (cfg.simple-nixos-mailserver.enable && cfg.useBinds)
    {
      "/var/vmail" = {
        device = "/volumes/${cfg.email.location}/vmail";
        options = [ "bind" ];
      };
      "/var/sieve" = {
        device = "/volumes/${cfg.email.location}/sieve";
        options = [ "bind" ];
      };
    };

  users.users = lib.mkIf cfg.simple-nixos-mailserver.enable {
    virtualMail = {
      isNormalUser = false;
    };
  };

  selfprivacy.userdata.simple-nixos-mailserver =
    lib.mkIf cfg.simple-nixos-mailserver.enable {
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

      certificateScheme = "manual";
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
