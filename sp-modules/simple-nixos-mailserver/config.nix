mailserverDate: { config, lib, ... }:
let
  sp = config.selfprivacy;
in
{
  fileSystems =
    lib.mkIf (sp.modules.simple-nixos-mailserver.enable && sp.useBinds)
      {
        "/var/vmail" = {
          device = "/volumes/${sp.email.location}/vmail";
          options = [ "bind" ];
        };
        "/var/sieve" = {
          device = "/volumes/${sp.email.location}/sieve";
          options = [ "bind" ];
        };
      };

  users.users = lib.mkIf sp.modules.simple-nixos-mailserver.enable {
    virtualMail = {
      isNormalUser = false;
    };
  };

  selfprivacy.modules.simple-nixos-mailserver =
    lib.mkIf sp.modules.simple-nixos-mailserver.enable {
      fqdn = sp.domain;
      domains = [ sp.domain ];

      # A list of all login accounts. To create the password hashes, use
      # mkpasswd -m sha-512 "super secret password"
      loginAccounts = {
        "${sp.username}@${sp.domain}" = {
          hashedPassword = sp.hashedMasterPassword;
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
          name = "${user.username}@${sp.domain}";
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
        sp.users);

      extraVirtualAliases = {
        "admin@${sp.domain}" = "${sp.username}@${sp.domain}";
      };

      certificateScheme =
        if builtins.compareVersions mailserverDate "20230525011002"
          >= 0
        then "manual"
        else 1;
      certificateFile = "/var/lib/acme/${sp.domain}/fullchain.pem";
      keyFile = "/var/lib/acme/${sp.domain}/key.pem";

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
