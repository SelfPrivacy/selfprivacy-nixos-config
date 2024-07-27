{ config, lib, ... }:
let
  sp = config.selfprivacy;
in
lib.mkIf sp.modules.simple-nixos-mailserver.enable
{
  fileSystems = lib.mkIf sp.useBinds
    {
      "/var/vmail" = {
        device =
          "/volumes/${sp.modules.simple-nixos-mailserver.location}/vmail";
        options = [
          "bind"
          "x-systemd.required-by=postfix.service"
          "x-systemd.before=postfix.service"
        ];
      };
      "/var/sieve" = {
        device =
          "/volumes/${sp.modules.simple-nixos-mailserver.location}/sieve";
        options = [
          "bind"
          "x-systemd.required-by=dovecot2.service"
          "x-systemd.before=dovecot2.service"
        ];
      };
    };

  users.users = {
    virtualMail = {
      isNormalUser = false;
    };
  };

  users.groups.acmereceivers.members = [ "dovecot2" "postfix" "virtualMail" ];

  mailserver = {
    enable = true;
    fqdn = sp.domain;
    domains = [ sp.domain ];
    localDnsResolver = false;

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

    certificateScheme = "acme";

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

  systemd = {
    services = {
      dovecot2.serviceConfig.Slice = "simple-nixos-mailserver.slice";
      postfix.serviceConfig.Slice = "simple-nixos-mailserver.slice";
      rspamd.serviceConfig.Slice = "simple-nixos-mailserver.slice";
      redis-rspamd.serviceConfig.Slice = "simple-nixos-mailserver.slice";
      opendkim.serviceConfig.Slice = "simple-nixos-mailserver.slice";
    };
    slices."simple-nixos-mailserver" = {
      name = "simple-nixos-mailserver.slice";
      description = "Simple NixOS Mailserver service slice";
    };
  };
}
