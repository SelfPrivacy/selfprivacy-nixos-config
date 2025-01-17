{ config, lib, pkgs, ... }@nixos-args:
let
  inherit (import ./common.nix nixos-args)
    appendLdapBindPwd
    auth-passthru
    cfg
    domain
    is-auth-enabled
    ;

  runtime-directory = "dovecot2";

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
  setPwdInLdapConfFile = appendLdapBindPwd {
    name = "ldap-conf-file";
    file = dovecot-ldap-config;
    prefix = ''dnpass = "'';
    suffix = ''"'';
    passwordFile = config.mailserver.ldap.bind.passwordFile;
    destination = ldapConfFile;
  };
  dovecot-oauth2-conf-file = pkgs.writeTextFile {
    name = "dovecot-oauth2.conf.ext";
    text = ''
      introspection_mode = post
      introspection_url = ${auth-passthru.oauth2-introspection-url "roundcube" "VERYSTRONGSECRETFORROUNDCUBE"}
      client_id = roundcube
      client_secret = VERYSTRONGSECRETFORROUNDCUBE # FIXME
      username_attribute = username
      scope = email profile openid
      tls_ca_cert_file = /etc/ssl/certs/ca-certificates.crt
      active_attribute = active
      active_value = true
      openid_configuration_url = ${auth-passthru.oauth2-discovery-url "roundcube"}
      debug = "no"
    '';
  };
in
lib.mkIf is-auth-enabled {
  mailserver.ldap = {
    # note: in `ldapsearch` first comes filter, then attributes
    dovecot.userAttrs = "+"; # all operational attributes
    # TODO: investigate whether "mail=%u" is better than:
    # dovecot.userFilter = "(&(class=person)(uid=%n))";
  };

  services.dovecot2.extraConfig = ''
    auth_mechanisms = xoauth2 oauthbearer

    passdb {
      driver = oauth2
      mechanisms = xoauth2 oauthbearer
      args = ${dovecot-oauth2-conf-file}
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
    preStart = setPwdInLdapConfFile + "\n";
    # FIXME pass dependant services to auth module option instead?
    wants = [ auth-passthru.oauth2-systemd-service ];
    after = [ auth-passthru.oauth2-systemd-service ];
    serviceConfig.RuntimeDirectory = lib.mkForce [ runtime-directory ];
  };

  # does it merge with existing restartTriggers?
  systemd.services.postfix.restartTriggers = [ setPwdInLdapConfFile ];
}
