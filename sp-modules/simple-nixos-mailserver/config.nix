mailserverFlake:
{
  config,
  lib,
  pkgs,
  ...
}@nixos-args:
let
  sp = config.selfprivacy;

  inherit (import ./common.nix { inherit config pkgs; })
    auth-passthru
    group
    ;
  mailserver-service-account = {
    mailserver-service-account-name = "sp.mailserver.service-account";
    mailserver-service-account-token-name = "mailserver-service-account-token";
    mailserver-service-account-token-fp = "/run/keys/${group}/kanidm-service-account-token"; # FIXME sync with auth module
  };
in
lib.mkIf sp.modules.simple-nixos-mailserver.enable (
  lib.mkMerge [
    {
      
      
      fileSystems = lib.mkIf sp.useBinds {
        "/var/vmail" = {
          device = "/volumes/${sp.modules.simple-nixos-mailserver.location}/vmail";
          options = [
            "bind"
            "x-systemd.required-by=postfix.service"
            "x-systemd.before=postfix.service"
          ];
        };
        "/var/sieve" = {
          device = "/volumes/${sp.modules.simple-nixos-mailserver.location}/sieve";
          options = [
            "bind"
            "x-systemd.required-by=dovecot.service"
            "x-systemd.before=dovecot.service"
          ];
        };
      };

      # https://nixos-mailserver.readthedocs.io/en/latest/migrations.html
      mailserver.stateVersion = 3;

      users.users = {
        virtualMail = {
          isNormalUser = false;
        };
      };

      users.groups.acmereceivers.members = [
        "dovecot2"
        "postfix"
        "virtualMail"
      ];

      mailserver = {
        enable = true;
        fqdn = sp.domain;
        domains = [ sp.domain ];
        localDnsResolver = false;

        certificateScheme = "manual";
        certificateFile = "/var/lib/acme/root-${sp.domain}/fullchain.pem";
        keyFile = "/var/lib/acme/root-${sp.domain}/key.pem";

        # Enable IMAP and POP3
        enableImap = true;
        enableImapSsl = true;
        enablePop3 = false;
        enablePop3Ssl = false;
        dkimSelector = "selector";

        # Enable the ManageSieve protocol
        enableManageSieve = true;

        virusScanning = false;

        mailDirectory = "/var/vmail";

        # LDAP is needed for Postfix to query Kanidm about email address ownership.
        # LDAP is needed for Dovecot also.
        ldap = {
          # false; otherwise, simple-nixos-mailserver enables auth via LDAP
          enable = false;

          # bind.dn = "uid=mail,ou=persons," + ldap_base_dn;
          bind.dn = "dn=token";
          # TODO change in this file should trigger system restart dovecot
          bind.passwordFile = mailserver-service-account.mailserver-service-account-token-fp;

          # searchBase = "ou=persons," + ldap_base_dn;
          searchBase = auth-passthru.ldap-base-dn; # TODO refine this

          # NOTE: 127.0.0.1 instead of localhost doesn't work (maybe because of TLS)
          uris = [ "ldaps://localhost:${toString auth-passthru.ldap-port}" ];
        };
      };

      systemd = {
        services = {
          sp-mailserver-migration = {
            serviceConfig.Slice = "simple_nixos_mailserver.slice";
            requiredBy = [
              "dovecot.service"
              "postfix.service"
              "rspamd.service"
              "redis-rspamd.service"
            ];
            serviceConfig.Type = "oneshot";
            script = let
              migration3PythonScript = pkgs.writers.writePython3 "nixos-mailserver-migration-03" {
                doCheck = false;
              } (builtins.readFile "${mailserverFlake}/migrations/nixos-mailserver-migration-03.py");
            in ''
              set -euo pipefail

              STATE_FILE="/etc/selfprivacy/mailserver.stateversion"
              if  [ ! -f "$STATE_FILE" ]; then
                echo "1" > "$STATE_FILE"
              fi

              CUR="$(<"$STATE_FILE")"

              run_migration_1() {} 
              # No action needed, we use default mailDirectory
              run_migration_2() {                
                ${migration3PythonScript}
              } 

              run_migration() {
                local i="$1"
                echo "Running mailserver migration $i..."
                if eval "run_migration_$((i + 1))"; then
                  echo $((i + 1)) > "$STATE_FILE"
                  echo "Migration $i succeeded."
                  return 0
                else
                  echo "Migration $i failed." >&2
                  return 1
                fi
              }

              for (( i = CUR; i < ${config.mailserver.stateVersion}; i++ )); do
                if ! run_migration "$i"; then
                  echo "Stopping at migration $i due to failure." >&2
                  exit 1
                fi
              done

            '';
          };
          dovecot.serviceConfig.Slice = "simple_nixos_mailserver.slice";
          postfix.serviceConfig.Slice = "simple_nixos_mailserver.slice";
          rspamd.serviceConfig.Slice = "simple_nixos_mailserver.slice";
          redis-rspamd.serviceConfig.Slice = "simple_nixos_mailserver.slice";
        };
        slices."simple_nixos_mailserver" = {
          name = "simple_nixos_mailserver.slice";
          description = "Simple NixOS Mailserver service slice";
        };
      };
    }
    (import ./auth-dovecot.nix mailserver-service-account nixos-args)
    (import ./auth-postfix.nix nixos-args)
  ]
)
