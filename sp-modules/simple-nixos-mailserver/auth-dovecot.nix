{
  mailserver-service-account-name,
  mailserver-service-account-token-name,
  mailserver-service-account-token-fp,
}:
{
  config,
  lib,
  pkgs,
  ...
}@nixos-args:
let
  inherit (import ./common.nix nixos-args)
    appendSetting
    auth-passthru
    cfg
    domain
    group
    is-auth-enabled
    ;

  runtime-folder = group;
  keysPath = auth-passthru.keys-path;

  # create service account token, needed for LDAP
  kanidmExecStartPostScript = pkgs.writeShellScript "mailserver-kanidm-ExecStartPost-script.sh" ''
    export HOME=$RUNTIME_DIRECTORY/client_home
    readonly KANIDM="${pkgs.kanidm}/bin/kanidm"

    # get Kanidm service account for mailserver
    KANIDM_SERVICE_ACCOUNT="$($KANIDM service-account list --name idm_admin | grep -E "^name: ${mailserver-service-account-name}$")"
    echo KANIDM_SERVICE_ACCOUNT: "$KANIDM_SERVICE_ACCOUNT"
    if [ -n "$KANIDM_SERVICE_ACCOUNT" ]
    then
        echo "kanidm service account \"${mailserver-service-account-name}\" is found"
    else
        echo "kanidm service account \"${mailserver-service-account-name}\" is not found"
        echo "creating new kanidm service account \"${mailserver-service-account-name}\""
        if $KANIDM service-account create --name idm_admin ${mailserver-service-account-name} ${mailserver-service-account-name} idm_admin
        then
            "kanidm service account \"${mailserver-service-account-name}\" created"
        else
            echo "error: cannot create kanidm service account \"${mailserver-service-account-name}\""
            exit 1
        fi
    fi

    # add Kanidm service account to `idm_mail_servers` group
    $KANIDM group add-members idm_mail_servers ${mailserver-service-account-name}

    # create a new read-only token for mailserver
    if ! KANIDM_SERVICE_ACCOUNT_TOKEN_JSON="$($KANIDM service-account api-token generate --name idm_admin ${mailserver-service-account-name} ${mailserver-service-account-token-name} --output json)"
    then
        echo "error: kanidm CLI returns an error when trying to generate service-account api-token"
        exit 1
    fi
    if ! KANIDM_SERVICE_ACCOUNT_TOKEN="$(echo "$KANIDM_SERVICE_ACCOUNT_TOKEN_JSON" | ${lib.getExe pkgs.jq} -r .result)"
    then
        echo "error: cannot get service-account API token from JSON"
        exit 1
    fi

    if ! install --mode=640 \
    <(printf "%s" "$KANIDM_SERVICE_ACCOUNT_TOKEN") \
    ${mailserver-service-account-token-fp}
    then
        echo "error: cannot write token to \"${mailserver-service-account-token-fp}\""
        exit 1
    fi
  '';

  ldapConfFile = "/run/${runtime-folder}/dovecot-ldap.conf.ext";
  mkLdapSearchScope =
    scope:
    (
      if scope == "sub" then
        "subtree"
      else if scope == "one" then
        "onelevel"
      else
        scope
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
  oauth-client-secret-fp = "${keysPath}/${group}/kanidm-oauth-client-secret";
  oauth-secret-ExecStartPreScript = pkgs.writeShellScript "${oauth-client-id}-kanidm-ExecStartPre-script.sh" ''
    set -o xtrace
    [ -f "${oauth-client-secret-fp}" ] || \
      "${lib.getExe pkgs.openssl}" rand -base64 32 | tr "\n:@/+=" "012345" > "${oauth-client-secret-fp}"
  '';
  dovecot-oauth2-conf-fp = "/run/${runtime-folder}/dovecot-oauth2.conf.ext";
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
    prefix =
      ''introspection_url = "'' + (auth-passthru.oauth2-introspection-url-prefix oauth-client-id);
    suffix = auth-passthru.oauth2-introspection-url-postfix + ''"'';
    passwordFile = oauth-client-secret-fp;
    destination = dovecot-oauth2-conf-fp;
  };
in
{
  # for dovecot2 to have access to get through ${keysPath} directory
  users.groups.keys.members = [ group ];
  systemd.tmpfiles.settings."kanidm-secrets"."${keysPath}/${group}".d = {
    user = "kanidm";
    inherit group;
    mode = "2750";
  };

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
    preStart = setPwdInLdapConfFile + "\n" + write-dovecot-oauth2-conf + "\n";
    after = [ auth-passthru.oauth2-systemd-service ];
    requires = [ auth-passthru.oauth2-systemd-service ];
    serviceConfig.RuntimeDirectory = lib.mkForce [ runtime-folder ];
  };

  systemd.services.kanidm.serviceConfig.ExecStartPre = lib.mkBefore [
    ("-" + oauth-secret-ExecStartPreScript)
  ];
  systemd.services.kanidm.serviceConfig.ExecStartPost = lib.mkAfter [
    ("-" + kanidmExecStartPostScript)
  ];

  systemd.services.postfix.restartTriggers = [
    setPwdInLdapConfFile
    write-dovecot-oauth2-conf
  ];
  selfprivacy.passthru.mailserver = {
    inherit oauth-client-id oauth-client-secret-fp;
  };
}
