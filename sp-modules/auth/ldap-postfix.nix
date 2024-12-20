{ config, lib, pkgs, ... }:
let
  cfg = config.mailserver;

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

  ldapSenderLoginMapFile = "/run/postfix/ldap-sender-login-map.cf";
  submissionOptions.smtpd_sender_login_maps =
    lib.mkForce "hash:/etc/postfix/vaccounts,ldap:${ldapSenderLoginMapFile}";
  commonLdapConfig = ''
    server_host = ${lib.concatStringsSep " " cfg.ldap.uris}
    start_tls = ${if cfg.ldap.startTls then "yes" else "no"}
    version = 3
    # tls_ca_cert_file = ${cfg.ldap.tlsCAFile}
    # tls_require_cert = yes

    search_base = ${cfg.ldap.searchBase}
    scope = ${cfg.ldap.searchScope}

    bind = yes
    bind_dn = ${cfg.ldap.bind.dn}
  '';
  ldapSenderLoginMap = pkgs.writeText "ldap-sender-login-map.cf" ''
    ${commonLdapConfig}
    query_filter = ${cfg.ldap.postfix.filter}
    result_attribute = ${cfg.ldap.postfix.mailAttribute}
  '';
  appendPwdInSenderLoginMap = appendLdapBindPwd {
    name = "ldap-sender-login-map";
    file = ldapSenderLoginMap;
    prefix = "bind_pw = ";
    passwordFile = cfg.ldap.bind.passwordFile;
    destination = ldapSenderLoginMapFile;
  };

  ldapVirtualMailboxMap = pkgs.writeText "ldap-virtual-mailbox-map.cf" ''
    ${commonLdapConfig}
    query_filter = ${cfg.ldap.postfix.filter}
    result_attribute = ${cfg.ldap.postfix.uidAttribute}
  '';
  ldapVirtualMailboxMapFile = "/run/postfix/ldap-virtual-mailbox-map.cf";
  appendPwdInVirtualMailboxMap = appendLdapBindPwd {
    name = "ldap-virtual-mailbox-map";
    file = ldapVirtualMailboxMap;
    prefix = "bind_pw = ";
    passwordFile = cfg.ldap.bind.passwordFile;
    destination = ldapVirtualMailboxMapFile;
  };
in
{
  systemd.services.postfix-setup = {
    preStart = ''
      ${appendPwdInVirtualMailboxMap}
      ${appendPwdInSenderLoginMap}
    '';
    restartTriggers = [ appendPwdInVirtualMailboxMap appendPwdInSenderLoginMap ];
  };
  services.postfix = {
    # the list should be merged with other options from nixos-mailserver
    config.virtual_mailbox_maps = [ "ldap:${ldapVirtualMailboxMapFile}" ];
    submissionOptions = submissionOptions;
    submissionsOptions = submissionOptions;
  };
}
