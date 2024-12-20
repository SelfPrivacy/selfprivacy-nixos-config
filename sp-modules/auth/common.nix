{ config, lib, pkgs, ... }:
rec {
  domain = config.selfprivacy.domain;
  cfg = config.selfprivacy.modules.auth;
  passthru = config.passthru.selfprivacy.auth;
  auth-fqdn = cfg.subdomain + "." + domain;

  kanidm_ldap_port = 3636;

  # e.g. "dc=mydomain,dc=com"
  ldap_base_dn =
    lib.strings.concatMapStringsSep
      ","
      (x: "dc=" + x)
      (lib.strings.splitString "." domain);

  appendLdapBindPwd =
    { name, file, prefix, suffix ? "", passwordFile, destination }:
    pkgs.writeScript "append-ldap-bind-pwd-in-${name}" ''
      #!${pkgs.stdenv.shell}
      set -euo pipefail

      baseDir=$(dirname ${destination})
      if (! test -d "$baseDir"); then
        mkdir -p $baseDir
        chmod 755 $baseDir
      fi

      cat ${file} > ${destination}
      echo -n '${prefix}' >> ${destination}
      cat ${passwordFile} >> ${destination}
      echo -n '${suffix}' >> ${destination}
      chmod 600 ${destination}
    '';
}
