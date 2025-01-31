{ config, pkgs, ... }:
rec {
  auth-passthru = config.passthru.selfprivacy.auth;
  domain = config.selfprivacy.domain;
  is-auth-enabled = config.selfprivacy.modules.auth.enable or false;
  group = "dovecot2";

  appendSetting =
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
