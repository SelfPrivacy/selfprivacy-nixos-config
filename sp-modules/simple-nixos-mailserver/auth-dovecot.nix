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
    domain
    group
    ;

  runtime-folder = group;
  keysPath = auth-passthru.keys-path;

  kanidmExecStartPostScript = pkgs.writeShellScript "create-dovecot-service-account-token-for-ldap" ''
    export HOME=$RUNTIME_DIRECTORY/client_home
    readonly KANIDM="${config.services.kanidm.package}/bin/kanidm"
    export KANIDM_NAME=idm_admin

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
            echo "kanidm service account \"${mailserver-service-account-name}\" created"
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
      ldap_uris = ${lib.concatStringsSep " " config.mailserver.ldap.uris}
      ${lib.optionalString config.mailserver.ldap.startTls ''
        ldap_starttls = yes
      ''}
      ssl_client_require_valid_cert = yes
      ssl_client_ca_file = ${config.mailserver.ldap.caFile}
      ldap_auth_dn = ${config.mailserver.ldap.bind.dn}
      ldap_base = ${config.mailserver.ldap.base}
      ldap_scope = ${mkLdapSearchScope config.mailserver.ldap.scope}

      userdb ldap {
        filter = ${config.mailserver.ldap.dovecot.userFilter}
        fields {
          home = /var/vmail/${domain}/%{user}
          uid = ${toString config.mailserver.storage.uid}
          gid = ${toString config.mailserver.storage.gid}
        }
      }
    '';
  };
  setPwdInLdapConfFile = appendSetting {
    name = "ldap-conf-file";
    file = dovecot-ldap-config;
    prefix = ''ldap_auth_dn_password = "'';
    suffix = ''"'';
    passwordFile = config.mailserver.ldap.bind.passwordFile;
    destination = ldapConfFile;
  };
  oauth-client-id = "mailserver";
  oauth-client-secret-fp = "${keysPath}/${group}/kanidm-oauth-client-secret";
  oauth-secret-ExecStartPreScript = pkgs.writeShellScript "${oauth-client-id}-create-client-secret.sh" ''
    set -o xtrace
    [ -f "${oauth-client-secret-fp}" ] || \
      "${lib.getExe pkgs.openssl}" rand -base64 32 | tr "\n:@/+=" "012345" > "${oauth-client-secret-fp}"
  '';
  dovecot-oauth2-conf-fp = "/run/${runtime-folder}/dovecot-oauth2.conf.ext";
  write-dovecot-oauth2-conf = appendSetting {
    name = "oauth2-conf-file";
    file = builtins.toFile "dovecot-oauth2.conf.ext.template" ''
      oauth2 {
        introspection_mode = post
        username_attribute = username
        scope = email profile openid
        ssl_client_ca_file = /etc/ssl/certs/ca-certificates.crt
        active_attribute = active
        active_value = true
        openid_configuration_url = ${auth-passthru.oauth2-discovery-url oauth-client-id}
    '';
    prefix =
      "  introspection_url = \"" + (auth-passthru.oauth2-introspection-url-prefix oauth-client-id);
    suffix = auth-passthru.oauth2-introspection-url-postfix + "\"\n      }\n";
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

  services.dovecot2.includeFiles = [
    ldapConfFile
    dovecot-oauth2-conf-fp
  ];

  services.dovecot2.settings = {
    auth_mechanisms = [
      "xoauth2"
      "oauthbearer"
      "plain"
      "login"
    ];

    "userdb static" = {
      fields = {
        uid = "virtualMail";
        gid = "virtualMail";
        home = "/var/vmail/${domain}/%{user}";
      };
    };

    "service auth" = {
      # provide SASL via unix socket to postfix
      "unix_listener /var/lib/postfix/private-auth" = {
        mode = "0660";
        user = "postfix";
        group = "postfix";
      };
      "unix_listener auth-userdb" = {
        mode = "0660";
        user = config.services.dovecot2.settings.default_internal_user;
        group = "virtualMail";
      };
      "unix_listener dovecot-auth" = {
        mode = "0660";
        # Assuming the default Postfix user and group
        user = "postfix";
        group = "postfix";
      };
    };
  };
  services.dovecot2.enablePAM = false;
  systemd.services.dovecot = {
    preStart = setPwdInLdapConfFile + "\n" + write-dovecot-oauth2-conf + "\n";
    after = [ auth-passthru.oauth2-systemd-service ];
    requires = [ auth-passthru.oauth2-systemd-service ];
    serviceConfig.RuntimeDirectory = lib.mkForce [ runtime-folder ];
  };

  systemd.services.kanidm.serviceConfig.ExecStartPre = lib.mkBefore [
    oauth-secret-ExecStartPreScript
  ];
  systemd.services.kanidm.serviceConfig.ExecStartPost = lib.mkAfter [
    kanidmExecStartPostScript
  ];

  systemd.services.postfix.restartTriggers = [
    setPwdInLdapConfFile
    write-dovecot-oauth2-conf
  ];
  selfprivacy.passthru.mailserver = {
    inherit oauth-client-id oauth-client-secret-fp;
  };
}
