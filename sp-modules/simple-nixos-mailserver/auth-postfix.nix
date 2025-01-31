{ config, lib, pkgs, ... }@nixos-args:
let
  inherit (import ./common.nix nixos-args)
    appendSetting
    auth-passthru
    is-auth-enabled
    ;

  cfg = config.mailserver;

  ldapSenderLoginMapFile = "/run/postfix/ldap-sender-login-map.cf";
  submissionOptions.smtpd_sender_login_maps =
    lib.mkForce "hash:/etc/postfix/vaccounts,ldap:${ldapSenderLoginMapFile}";
  commonLdapConfig = ''
    server_host = ${lib.concatStringsSep " " cfg.ldap.uris}
    start_tls = ${if cfg.ldap.startTls then "yes" else "no"}
    version = 3
    tls_ca_cert_file = ${cfg.ldap.tlsCAFile}
    tls_require_cert = yes

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
  appendPwdInSenderLoginMap = appendSetting {
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
  appendPwdInVirtualMailboxMap = appendSetting {
    name = "ldap-virtual-mailbox-map";
    file = ldapVirtualMailboxMap;
    prefix = "bind_pw = ";
    passwordFile = cfg.ldap.bind.passwordFile;
    destination = ldapVirtualMailboxMapFile;
  };
in
{
  mailserver.ldap = {
    postfix.mailAttribute = "mail";
    postfix.uidAttribute = "uid";
  };
  systemd.services.postfix-setup = {
    preStart = ''
      ${appendPwdInVirtualMailboxMap}
      ${appendPwdInSenderLoginMap}
    '';
    restartTriggers =
      [ appendPwdInVirtualMailboxMap appendPwdInSenderLoginMap ];
    wants = [ auth-passthru.oauth2-systemd-service ];
    after = [ auth-passthru.oauth2-systemd-service ];
  };
  services.postfix = {
    # the list should be merged with other options from nixos-mailserver
    config.virtual_mailbox_maps = [ "ldap:${ldapVirtualMailboxMapFile}" ];
    inherit submissionOptions;
    submissionsOptions = submissionOptions;
  };
}
