{ config, lib, pkgs, ... }@nixos-args:
let
  inherit (import ./common.nix nixos-args)
    appendSetting
    auth-passthru
    cfg
    domain
    group
    is-auth-enabled
    ;

  runtime-directory = group;

  ldapConfFile = "/run/${runtime-directory}/dovecot-ldap.conf.ext";
  mkLdapSearchScope = scope: (
    if scope == "sub" then "subtree"
    else if scope == "one" then "onelevel"
    else scope
  );
  dovecot-ldap-config = pkgs.writeTextFile {
    name = "dovecot-ldap.conf.ext.template";
    text = ''
      ldap_version = 3
      uris = ${lib.concatStringsSep " " config.mailserver.ldap.uris}
      ${lib.optionalString config.mailserver.ldap.startTls ''
      tls = yes
      ''}
      tls_require_cert = hard
      tls_ca_cert_file = ${config.mailserver.ldap.tlsCAFile}
      dn = ${config.mailserver.ldap.bind.dn}
      sasl_bind = no
      auth_bind = no
      base = ${config.mailserver.ldap.searchBase}
      scope = ${mkLdapSearchScope config.mailserver.ldap.searchScope}
      ${lib.optionalString (config.mailserver.ldap.dovecot.userAttrs != null) ''
      user_attrs = ${config.mailserver.ldap.dovecot.userAttrs}
      ''}
      user_filter = ${config.mailserver.ldap.dovecot.userFilter}
    '';
  };
  setPwdInLdapConfFile = appendSetting {
    name = "ldap-conf-file";
    file = dovecot-ldap-config;
    prefix = ''dnpass = "'';
    suffix = ''"'';
    passwordFile = config.mailserver.ldap.bind.passwordFile;
    destination = ldapConfFile;
  };
  oauth-client-id = "mailserver";
  oauth-client-secret-fp =
    "/run/keys/${group}/kanidm-oauth-client-secret";
  oauth-secret-ExecStartPreScript = pkgs.writeShellScript
    "${oauth-client-id}-kanidm-ExecStartPre-script.sh" ''
    set -o xtrace
    [ -f "${oauth-client-secret-fp}" ] || \
      "${lib.getExe pkgs.openssl}" rand -base64 32 | tr -d "\n" > "${oauth-client-secret-fp}"
  '';
  dovecot-oauth2-conf-fp = "/run/${runtime-directory}/dovecot-oauth2.conf.ext";
  write-dovecot-oauth2-conf = appendSetting {
    name = "oauth2-conf-file";
    file = builtins.toFile "dovecot-oauth2.conf.ext.template" ''
      introspection_mode = post
      username_attribute = username
      scope = email profile openid
      tls_ca_cert_file = /etc/ssl/certs/ca-certificates.crt
      active_attribute = active
      active_value = true
      openid_configuration_url = ${auth-passthru.oauth2-discovery-url oauth-client-id}
      debug = "no"
    '';
    prefix = ''introspection_url = "'' +
      (auth-passthru.oauth2-introspection-url-prefix oauth-client-id);
    suffix = auth-passthru.oauth2-introspection-url-postfix + ''"'';
    passwordFile = oauth-client-secret-fp;
    destination = dovecot-oauth2-conf-fp;
  };
in
{
  # for dovecot2 to have access to get through /run/keys directory
  users.groups.keys.members = [ group ];

  mailserver.ldap = {
    # note: in `ldapsearch` first comes filter, then attributes
    dovecot.userAttrs = "+"; # all operational attributes
    # TODO: investigate whether "mail=%u" is better than:
    # dovecot.userFilter = "(&(class=person)(uid=%n))";
  };

  services.dovecot2.extraConfig = ''
    auth_mechanisms = xoauth2 oauthbearer plain login

    passdb {
      driver = oauth2
      mechanisms = xoauth2 oauthbearer
      args = ${dovecot-oauth2-conf-fp}
    }

    userdb {
      driver = static
      args = uid=virtualMail gid=virtualMail home=/var/vmail/${domain}/%u
    }

    # provide SASL via unix socket to postfix
    service auth {
      unix_listener /var/lib/postfix/private-auth {
        mode = 0660
        user = postfix
        group = postfix
      }
    }
    service auth {
      unix_listener auth-userdb {
        mode = 0660
        user = ${config.services.dovecot2.user}
      }
      unix_listener dovecot-auth {
        mode = 0660
        # Assuming the default Postfix user and group
        user = postfix
        group = postfix
      }
    }

    userdb {
      driver = ldap
      args = ${ldapConfFile}
      default_fields = home=/var/vmail/${domain}/%u uid=${toString config.mailserver.vmailUID} gid=${toString config.mailserver.vmailUID}
    }
  '';
  services.dovecot2.enablePAM = false;
  systemd.services.dovecot2 = {
    # TODO does it merge with existing preStart?
    preStart = setPwdInLdapConfFile + "\n" + write-dovecot-oauth2-conf + "\n";
    # FIXME pass dependant services to auth module option instead?
    after = [ auth-passthru.oauth2-systemd-service ];
    requires = [ auth-passthru.oauth2-systemd-service ];
    serviceConfig.RuntimeDirectory = lib.mkForce [ runtime-directory ];
  };

  systemd.services.kanidm.serviceConfig.ExecStartPre = lib.mkAfter [
    ("-" + oauth-secret-ExecStartPreScript)
  ];
  # does it merge with existing restartTriggers?
  systemd.services.postfix.restartTriggers = [
    setPwdInLdapConfFile
    write-dovecot-oauth2-conf
  ];
  selfprivacy.passthru.mailserver = {
    inherit oauth-client-id oauth-client-secret-fp;
  };
}
