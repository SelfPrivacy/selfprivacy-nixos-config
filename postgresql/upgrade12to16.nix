{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.postgresqlUpgrade12to16;
  mkIf = lib.mkIf;
  mkOption = lib.mkOption;
  types = lib.types;
  optional = lib.optional;
in

{
  options.services.postgresqlUpgrade12to16 = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enables an automatic one-shot upgrade from PostgreSQL 12 to 16 if a
        version 12 data directory is found. This will run pg_upgrade and may
        take time depending on database size. Use with caution.
      '';
    };
    dataDir12 = mkOption {
      type = types.str;
      default = "/var/lib/postgresql/12";
      description = "Location of the old PostgreSQL 12 data directory.";
    };
    dataDir16 = mkOption {
      type = types.str;
      default = "/var/lib/postgresql/16";
      description = "Location of the new PostgreSQL 16 data directory.";
    };
    pleromaEnabled = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether Pleroma service is present and needs to be stopped/started
        during the PostgreSQL upgrade process.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.postgresql.package == pkgs.postgresql_16;
        message = "PostgreSQL package must be set to postgresql_16 for the upgrade to work correctly.";
      }
      {
        assertion = config.services.postgresql.dataDir == cfg.dataDir16;
        message = "PostgreSQL data directory must be set to ${cfg.dataDir16} for the upgrade to work correctly. The current value is ${config.services.postgresql.dataDir}.";
      }
    ];

    systemd.services."postgresql-upgrade12to16" = {
      description = "Upgrade PostgreSQL 12 database to PostgreSQL 16";
      wantedBy = [ "multi-user.target" ];
      before = [ "postgresql.service" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";

        ExecStartPre =
          # Stop Pleroma only if pleromaEnabled is true
          optional cfg.pleromaEnabled
            "${pkgs.writeShellScript "postgresql-upgrade12to16-pre.sh" ''
              if [ -d "${cfg.dataDir12}" ] && [ ! -d "${cfg.dataDir16}" ]; then
                ${pkgs.systemd}/bin/systemctl stop pleroma.service
              fi
            ''}";

        ExecStart = "${pkgs.writeShellScript "postgresql-upgrade12to16.sh" ''
          set -e

          oldDataDir="${cfg.dataDir12}"
          newDataDir="${cfg.dataDir16}"

          # Only upgrade if old data directory exists, and the new one doesn't yet
          if [ -d "$oldDataDir" ] && [ ! -d "$newDataDir" ]; then
            echo "Detected PostgreSQL 12 data directory at $oldDataDir"
            echo "Upgrading to PostgreSQL 16 data directory at $newDataDir"

            # Stop the old PostgreSQL if it's running
            if systemctl is-active --quiet postgresql.service; then
              systemctl stop postgresql.service
            fi

            # Create the new data directory (if not already present)
            mkdir -p "$newDataDir"
            chown -R postgres:postgres "$(dirname "$newDataDir")"

            # Create a temporary working directory
            tempDir=$(mktemp -d)
            chown -R postgres:postgres "$tempDir"
            trap 'rm -rf "$tempDir"' EXIT

            # Change to the temporary working directory
            cd "$tempDir"

            # Initialize the new PostgreSQL 16 data directory
            ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql_16.out}/bin/initdb -D "$newDataDir" -U postgres

            # Run pg_upgrade as the postgres user
            ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql_16.out}/bin/pg_upgrade \
              --old-datadir "$oldDataDir" \
              --new-datadir "$newDataDir" \
              --old-bindir ${pkgs.postgresql_12.out}/bin \
              --new-bindir ${pkgs.postgresql_16.out}/bin \
              --jobs "$(nproc)" \
              --link \
              --verbose

            touch "$newDataDir/.sp_migrated"

            echo "PostgreSQL upgrade from 12 to 16 completed."
          else
            echo "No PostgreSQL 12 data directory detected or already upgraded. Skipping."
          fi
        ''}";

        # Start Pleroma only if pleromaEnabled is true
        ExecStartPost = optional cfg.pleromaEnabled "${pkgs.writeShellScript "postgresql-upgrade12to16-post.sh" ''
          if test -e "${cfg.dataDir16}/.sp_migrated"; then
            ${pkgs.systemd}/bin/systemctl start --no-block pleroma.service

            rm -f "${cfg.dataDir16}/.sp_migrated"
          fi
        ''}";
      };
    };
  };
}
