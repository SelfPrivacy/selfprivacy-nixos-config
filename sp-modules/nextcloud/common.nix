config: rec {
  sp = config.selfprivacy;
  secrets-filepath = "/etc/selfprivacy/secrets.json";
  db-pass-filepath = "/var/lib/nextcloud/db-pass";
  admin-pass-filepath = "/var/lib/nextcloud/admin-pass";
  hostName = "cloud.${sp.domain}";
}
