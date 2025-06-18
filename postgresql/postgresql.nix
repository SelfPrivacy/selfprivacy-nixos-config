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
      enable = enable;
      pleromaEnabled = pleroma_enabled;
    };
  };
  systemd = {
    services.postgresql = {
      serviceConfig.Slice = "postgresql.slice";
    };
    slices.postgresql = {
      description = "PostgreSQL slice";
    };
  };
}
