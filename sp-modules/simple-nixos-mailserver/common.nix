{ config, pkgs, ... }:
rec {
  auth-passthru = config.selfprivacy.passthru.auth;
  domain = config.selfprivacy.domain;
  group = "dovecot2";
  is-auth-enabled =
    config.selfprivacy.modules.simple-nixos-mailserver.enableSso;

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
