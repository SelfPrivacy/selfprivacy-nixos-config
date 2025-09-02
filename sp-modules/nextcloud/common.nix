config: rec {
  sp = config.selfprivacy;
  domain = sp.domain;
  admin-pass-filepath = "/var/lib/nextcloud/admin-pass";
  override-config-fp = "/var/lib/nextcloud/config/override.config.php";
}
