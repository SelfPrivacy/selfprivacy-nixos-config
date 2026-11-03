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
      assertions = map (email: {
        assertion = (builtins.match "[^@]+\\.[^@]+" email.name) != null;
        message = "Service email names must use the local-part format 'name.service' without a domain.";
      }) (lib.attrsToList sp.emails);

      fileSystems = lib.mkIf sp.useBinds {
        "/var/vmail" = {
          fsType = "auto";
          device = "/volumes/${sp.modules.simple-nixos-mailserver.location}/vmail";
          options = [
            "bind"
            "x-systemd.required-by=postfix.service"
            "x-systemd.before=postfix.service"
          ];
        };
        "/var/sieve" = {
          fsType = "auto";
          device = "/volumes/${sp.modules.simple-nixos-mailserver.location}/sieve";
          options = [
            "bind"
            "x-systemd.required-by=dovecot.service"
            "x-systemd.before=dovecot.service"
          ];
        };
      };

      # https://nixos-mailserver.readthedocs.io/en/latest/migrations.html
      mailserver.stateVersion = 5;

      users.groups.acmereceivers.members = [
        "dovecot2"
        "postfix"
        "virtualMail"
      ];

      security.acme.certs."root-${sp.domain}".reloadServices = [
        "dovecot.service"
        "postfix.service"
      ];

      mailserver = {
        enable = true;
        fqdn = sp.domain;
        domains = [ sp.domain ];
        accounts = lib.mapAttrs' (
          name: email:
          lib.nameValuePair "${name}@${sp.domain}" {
            passwordFile = email.passwordFile;
            inherit (email) sendOnly;
          }
        ) sp.emails;
        localDnsResolver = false;

        x509.certificateFile = "/var/lib/acme/root-${sp.domain}/fullchain.pem";
        x509.privateKeyFile = "/var/lib/acme/root-${sp.domain}/key.pem";

        # Enable IMAP and POP3
        enableImap = true;
        enableImapSsl = true;
        enablePop3 = false;
        enablePop3Ssl = false;
        enableSubmission = true;
        dkim.defaults.selector = "selector";

        # Enable the ManageSieve protocol
        enableManageSieve = true;

        virusScanning = false;

        storage.path = "/var/vmail";

        # LDAP is needed for Postfix to query Kanidm about email address ownership.
        # LDAP is needed for Dovecot also.
        ldap = {
          # false; otherwise, simple-nixos-mailserver enables auth via LDAP
          enable = false;

          # bind.dn = "uid=mail,ou=persons," + ldap_base_dn;
          bind.dn = "dn=token";
          # TODO change in this file should trigger system restart dovecot
          bind.passwordFile = mailserver-service-account.mailserver-service-account-token-fp;

          # base = "ou=persons," + ldap_base_dn;
          base = auth-passthru.ldap-base-dn; # TODO refine this

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
            before = [
              "dovecot.service"
              "postfix.service"
              "rspamd.service"
              "redis-rspamd.service"
            ];
            unitConfig.RequiresMountsFor = [
              "/var/vmail"
              "/var/sieve"
            ];
            serviceConfig.Type = "oneshot";
            serviceConfig.RemainAfterExit = true;
            script =
              let
                migration3PythonScript = pkgs.writers.writePython3 "nixos-mailserver-migration-03" {
                  doCheck = false;
                } (builtins.readFile "${mailserverFlake}/migrations/nixos-mailserver-migration-03.py");
                migration5PythonScript = pkgs.writers.writePython3 "nixos-mailserver-migration-05-sp" {
                  doCheck = false;
                } (builtins.readFile ./nixos-mailserver-migration-05-sp.py);
              in
              ''
                set -euo pipefail

                STATE_FILE="/etc/selfprivacy/mailserver.stateversion"
                if  [ ! -f "$STATE_FILE" ]; then
                  echo "1" > "$STATE_FILE"
                fi

                CUR="$(<"$STATE_FILE")"

                run_migration_1() {
                  true
                }
                run_migration_2() {
                  ${migration3PythonScript} --layout default /var/vmail --execute
                }
                run_migration_3() {
                  # not applicable, we're not using mailserver.ldap and doing our own thing.
                  true
                }
                run_migration_4() {
                  if [ -d /var/sieve ]; then
                    DOMAIN=${lib.escapeShellArg sp.domain} ${migration5PythonScript} --execute /var/sieve
                  fi
                }

                run_migration() {
                  local i="$1"
                  echo "Running mailserver migration $i..."
                  if eval "run_migration_$i"; then
                    echo $((i + 1)) > "$STATE_FILE"
                    echo "Migration $i succeeded."
                    return 0
                  else
                    echo "Migration $i failed." >&2
                    return 1
                  fi
                }

                for (( i = CUR; i < ${toString config.mailserver.stateVersion}; i++ )); do
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

          generate-email-passwords = {
            enable = true;
            wantedBy = [ "multi-user.target" ];
            requiredBy = [ "dovecot.service" ];
            restartIfChanged = true;
            serviceConfig.Slice = "simple_nixos_mailserver.slice";
            path = with pkgs; [
              coreutils
              pwgen
            ];
            script = ''
              set -euo pipefail
              umask 0077
              install -d -m 0711 -o root -g root /run/sp-mailboxes
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (_: email: ''
                  install -d -m 0700 \
                    -o ${lib.escapeShellArg email.user} -g ${lib.escapeShellArg email.group} \
                    ${lib.escapeShellArg (builtins.dirOf email.passwordFile)}
                  if [ ! -s ${lib.escapeShellArg email.passwordFile} ]; then
                    tmp=$(mktemp ${lib.escapeShellArg "${email.passwordFile}.XXXXXX"})
                    pwgen -s 64 1 > "$tmp"
                    chown ${lib.escapeShellArg "${email.user}:${email.group}"} "$tmp"
                    chmod 0400 "$tmp"
                    mv "$tmp" ${lib.escapeShellArg email.passwordFile}
                  fi
                  chown ${lib.escapeShellArg "${email.user}:${email.group}"} ${lib.escapeShellArg email.passwordFile}
                  chmod 0400 ${lib.escapeShellArg email.passwordFile}
                '') sp.emails
              )}
            '';
          };
        }
        // (lib.pipe sp.emails [
          (lib.attrsets.mapAttrsToList (_: value: value.systemdServices))
          lib.flatten
          (x: x ++ [ "dovecot" ])
          (map (
            x:
            lib.nameValuePair x {
              wants = [ "generate-email-passwords.service" ];
              after = [ "generate-email-passwords.service" ];
            }
          ))
          lib.listToAttrs
        ]);

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
