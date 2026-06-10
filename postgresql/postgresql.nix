{
  config,
  lib,
  pkgs,
  ...
}:
let
  sp = config.selfprivacy;
  pleroma_location =
    if
      lib.attrsets.hasAttr "pleroma" sp.modules && lib.attrsets.hasAttr "location" sp.modules.pleroma
    then
      sp.modules.pleroma.location
    else
      null;
  postgres_location =
    if lib.attrsets.hasAttr "postgresql" sp && lib.attrsets.hasAttr "location" sp.postgresql then
      sp.postgresql.location
    else
      null;
  # Priority: postgresql > pleroma
  location = if postgres_location != null then postgres_location else pleroma_location;
  # Active if there is a location
  enable = location != null;
  pleroma_enabled =
    if
      lib.attrsets.hasAttr "pleroma" sp.modules && lib.attrsets.hasAttr "enable" sp.modules.pleroma
    then
      sp.modules.pleroma.enable
    else
      false;
in
{
  imports = [
    ./upgrade12to16.nix
  ];
  fileSystems = lib.mkIf enable {
    "/var/lib/postgresql" = {
      fsType = "auto";
      device = "/volumes/${location}/postgresql";
      options = [
        "bind"
        "x-systemd.required-by=postgresql.service"
        "x-systemd.required-by=postgresql-upgrade12to16.service"
        "x-systemd.before=postgresql.service"
        "x-systemd.before=postgresql-upgrade12to16.service"
      ];
    };
    "/var/lib/postgresql-dumps" = {
      fsType = "auto";
      device = "/volumes/${location}/postgresql-dumps";
      options = [ "bind" ];
    };
  };
  services = {
    postgresql = {
      enable = enable;
      package = pkgs.postgresql_16;
      # Change to selfpirvacy-api user when API migrates to rootless daemon
      authentication = ''
        local all postgres peer map=selfprivacy-api
      '';
      identMap = ''
        selfprivacy-api root postgres
        selfprivacy-api postgres postgres
      '';
    };
    postgresqlUpgrade12to16 = {
      enable = false;
      pleromaEnabled = pleroma_enabled;
    };
  };
  systemd = {
    services.postgresql = {
      serviceConfig.Slice = "postgresql.slice";
      serviceConfig.ExecStartPost = pkgs.writeShellScript "update-pg-collation" ''
        export PATH="${config.services.postgresql.package}/bin:$PATH"
        GLIBC_VERSION="${pkgs.glibc.version}"

        check_mismatches() {
          local query="
            SELECT datname, datcollversion
            FROM pg_database
            WHERE datcollversion IS NOT NULL
              AND datcollversion != '$GLIBC_VERSION'
              AND datallowconn = true
              AND datname NOT IN ('template0')
            ORDER BY datname;
          "

          psql -c "$query" 2>/dev/null | grep -v '^$' || true
        }

        get_mismatched_databases() {
          check_mismatches | while IFS='|' read -r dbname version; do
              dbname=$(echo "$dbname" | xargs)
              version=$(echo "$version" | xargs)

              if [ "datname" != "$dbname" ] && [ -n "$dbname" ] && [ -n "$version" ]; then
                echo "$dbname"
              fi
          done
        }


        fix_database() {
          local dbname=$1
          local current_version
          current_version=$(psql --csv -c "SELECT datcollversion FROM pg_database WHERE datname = '$dbname';" | xargs)
          if  psql -d "$dbname" -c "REINDEX DATABASE \"$dbname\";" 2>/dev/null && psql -d "$dbname" -c "ALTER DATABASE \"$dbname\" REFRESH COLLATION VERSION;" 2>/dev/null; then
            echo "update-collation: Successfully updated collation on DB $dbname ($current_version -> $GLIBC_VERSION)"
            return 0
          else
            echo "update-collation: Failed to update collation on DB $dbname"
            return 1
          fi
        }

        dbs=$(get_mismatched_databases)

        for dbname in $dbs; do
          echo "update-collation: Updating $dbname"
          fix_database $dbname
        done
      '';
    };
    slices.postgresql = {
      description = "PostgreSQL slice";
    };
  };
}
