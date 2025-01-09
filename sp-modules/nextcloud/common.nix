config: rec {
  sp = config.selfprivacy;
  domain= sp.domain;
  secrets-filepath = "/etc/selfprivacy/secrets.json";
  db-pass-filepath = "/var/lib/nextcloud/db-pass";
  admin-pass-filepath = "/var/lib/nextcloud/admin-pass";
  override-config-fp = "/var/lib/nextcloud/config/override.config.php";
}
