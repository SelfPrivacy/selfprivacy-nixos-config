{ config, lib, pkgs, ... }:
let
  domain = config.selfprivacy.domain;
  cfg = config.selfprivacy.modules.roundcube;
  auth-module = config.selfprivacy.modules.auth;
  auth-fqdn = auth-module.subdomain + "." + domain;
  oauth-client-id = "roundcube";
  dovecot-service-account-name = "dovecot-service-account";
  postfix-service-account-name = "postfix-service-account";
  dovecot-service-account-token-name = "dovecot-service-account-token";
  postfix-service-account-token-name = "postfix-service-account-token";
  # dovecot-service-account-token-fp = "/run/kanidm/token/dovecot";
  dovecot-service-account-token-fp =
    "/run/keys/dovecot/kanidm-service-account-token";
  postfix-service-account-token-fp =
    "/run/keys/postfix/kanidm-service-account-token";
  dovecot-group = "dovecot2"; # FIXME
  postfix-group = "postfix"; # FIXME
  # FIXME use usernames and groups from `config`
  # FIXME dependency on dovecot2 and postfix
  # set-group-ID bit allows for kanidm user to create files,
  # which inherit directory group (.e.g dovecot, postfix)
  kanidmExecStartPostScriptRoot = pkgs.writeShellScript
    "roundcube-kanidm-ExecStartPost-root-script.sh"
    ''
      mkdir -p -v --mode=u+rwx,g+rs,g-w,o-rwx /run/keys/dovecot
      chown kanidm:dovecot2 /run/keys/dovecot

      mkdir -p -v --mode=u+rwx,g+rs,g-w,o-rwx /run/keys/postfix
      chown kanidm:postfix /run/keys/postfix
    '';
  # FIXME parameterize names like "dovecot2" group
  kanidmExecStartPostScript = pkgs.writeShellScript
    "roundcube-kanidm-ExecStartPost-script.sh"
    ''
      export HOME=$RUNTIME_DIRECTORY/client_home
      readonly KANIDM="${pkgs.kanidm}/bin/kanidm"

      # get Kanidm service account for Dovecot
      KANIDM_SERVICE_ACCOUNT="$($KANIDM service-account list --name idm_admin | grep -E "^name: ${dovecot-service-account-name}$")"
      echo KANIDM_SERVICE_ACCOUNT: "$KANIDM_SERVICE_ACCOUNT"
      if [ -n "$KANIDM_SERVICE_ACCOUNT" ]
      then
          echo "kanidm service account \"${dovecot-service-account-name}\" is found"
      else
          echo "kanidm service account \"${dovecot-service-account-name}\" is not found"
          echo "creating new kanidm service account \"${dovecot-service-account-name}\""
          if $KANIDM service-account create --name idm_admin ${dovecot-service-account-name} ${dovecot-service-account-name} idm_admin
          then
              "kanidm service account \"${dovecot-service-account-name}\" created"
          else
              echo "error: cannot create kanidm service account \"${dovecot-service-account-name}\""
              exit 1
          fi
      fi

      # add Kanidm service account to `idm_mail_servers` group
      $KANIDM group add-members idm_mail_servers ${dovecot-service-account-name}

      # create a new read-only token for Dovecot
      if ! KANIDM_SERVICE_ACCOUNT_TOKEN_JSON="$($KANIDM service-account api-token generate --name idm_admin ${dovecot-service-account-name} ${dovecot-service-account-token-name} --output json)"
      then
          echo "error: kanidm CLI returns an error when trying to generate service-account api-token"
          exit 1
      fi
      if ! KANIDM_SERVICE_ACCOUNT_TOKEN="$(echo "$KANIDM_SERVICE_ACCOUNT_TOKEN_JSON" | ${lib.getExe pkgs.jq} -r .result)"
      then
          echo "error: cannot get service-account API token from JSON"
          exit 1
      fi

      # if ! printf "%s\n" "$KANIDM_SERVICE_ACCOUNT_TOKEN" > ${dovecot-service-account-token-fp}
      if ! install --mode=640 \
      <(printf "%s" "$KANIDM_SERVICE_ACCOUNT_TOKEN") \
      ${dovecot-service-account-token-fp}
      then
          echo "error: cannot write token to \"${dovecot-service-account-token-fp}\""
          exit 1
      fi
    '';
in
{
  options.selfprivacy.modules.roundcube = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
    };
    subdomain = lib.mkOption {
      default = "roundcube";
      type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
    };
  };

  config = lib.mkIf cfg.enable {
    # FIXME get user names from `config`
    # in order to allow access below /run/keys
    users.groups.keys.members = [ "kanidm" "dovecot2" "postfix" ];
    services.roundcube = {
      enable = true;
      # package = pkgs.roundcube.overrideAttrs (_: rec {
      #   version = "1.6.9";
      #   src = pkgs.fetchurl {
      #     url = "https://github.com/roundcube/roundcubemail/releases/download/${version}/roundcubemail-${version}-complete.tar.gz";
      #     sha256 = "sha256-thpfXCL4kMKZ6TWqz88IcGdpkNiuv/DWzf8HW/F8708=";
      #   };
      #   # src = pkgs.fetchurl {
      #   #   url = "https://github.com/roundcube/roundcubemail/archive/master/3a6e25a5b386e0d87427b934ccd2e0e282e0a74e.tar.gz";
      #   #   sha256 = "sha256-EpEI4E+r3reYbI/5rquia+zgz1+6k49lPChlp4QiZTE=";
      #   # };
      #   postFixup = ''
      #     cp -v ${/data/sp/roundcubemail-1.6.9/program/include/rcmail_oauth.php} $out/program/include/rcmail_oauth.php
      #     cp -v ${/data/sp/roundcubemail-1.6.9/program/actions/login/oauth.php} $out/program/actions/login/oauth.php
      #     rm -r $out/program/localization/*
      #   '';
      # });
      # package = pkgs.runCommandNoCCLocal "roundcube-debug" {} ''
      #   cp -r --no-preserve=all ${pkgs.roundcube} $out
      #   cp -v ${/data/sp/roundcubemail-1.6.8/plugins/debug_logger/debug_logger.php} $out/plugins/debug_logger/debug_logger.php
      #   cp -v ${/data/sp/roundcubemail-1.6.8/program/include/rcmail_oauth.php} $out/program/include/rcmail_oauth.php
      # '';
      # this is the url of the vhost, not necessarily the same as the fqdn of
      # the mailserver
      hostName = "${cfg.subdomain}.${config.selfprivacy.domain}";
      # plugins = [ "debug_logger" ];
      extraConfig = ''
        # starttls needed for authentication, so the fqdn required to match
        # the certificate
        $config['smtp_host'] = "tls://${config.mailserver.fqdn}";
        # $config['smtp_user'] = "%u";
        # $config['smtp_pass'] = "%p";
      '' + lib.strings.optionalString auth-module.enable ''
        $config['oauth_provider'] = 'generic';
        $config['oauth_provider_name'] = 'kanidm'; # FIXME
        $config['oauth_client_id'] = '${oauth-client-id}';
        $config['oauth_client_secret'] = 'VERYSTRONGSECRETFORROUNDCUBE'; # FIXME

        $config['oauth_auth_uri'] = 'https://${auth-fqdn}/ui/oauth2';
        $config['oauth_token_uri'] = 'https://${auth-fqdn}/oauth2/token';
        $config['oauth_identity_uri'] = 'https://${auth-fqdn}/oauth2/openid/${oauth-client-id}/userinfo';
        $config['oauth_scope'] = 'email profile openid';
        # $config['oauth_scope'] = 'email openid dovecotprofile';
        $config['oauth_auth_parameters'] = [];
        $config['oauth_identity_fields'] = ['email'];
        $config['oauth_login_redirect'] = false;
        $config['auto_create_user'] = true;

        $config['log_dir'] = '/tmp/roundcube';
        $config['log_driver'] = 'stdout';
        $config['log_errors'] = 1;
        // Log SQL queries to <log_dir>/sql or to syslog
        $config['sql_debug'] = true;

        // Log IMAP conversation to <log_dir>/imap or to syslog
        $config['imap_debug'] = true;
        $config['log_debug'] = true;
        $config['oauth_debug'] = true;

        // Log LDAP conversation to <log_dir>/ldap or to syslog
        $config['ldap_debug'] = true;

        // Log SMTP conversation to <log_dir>/smtp or to syslog
        $config['smtp_debug'] = true;

        $config['debug_logger']['master'] = 'master';
        $config['debug_logger']['oauth'] = 'oauth';
        $config['debug_logger']['imap'] = 'imap';
        $config['debug_logger']['log'] = 'log';
        $config['debug_logger']['smtp'] = 'smtp';

        $config['oauth_verify_peer'] = false;
        $config['log_logins'] = true;
        $config['log_session'] = true;
        # $config['oauth_pkce'] = 'S256';
      '';
    };
    services.nginx.virtualHosts."${cfg.subdomain}.${domain}" = {
      forceSSL = true;
      useACMEHost = domain;
      enableACME = false;
      # extraConfig = ''
      #   add_header X-Frame-Options DENY;
      #   add_header X-Content-Type-Options nosniff;
      #   add_header X-XSS-Protection "1; mode=block";
      # '';
    };
    systemd = {
      services = {
        phpfpm-roundcube.serviceConfig = {
          Slice = lib.mkForce "roundcube.slice";
          StandardError = "journal";
          StandardOutput = "journal";
        };
        kanidm.serviceConfig.ExecStartPost = lib.mkAfter [
          ("+" + kanidmExecStartPostScriptRoot)
          kanidmExecStartPostScript
        ];
      };
      slices.roundcube = {
        description = "Roundcube service slice";
      };
    };

    services.kanidm.provision = lib.mkIf auth-module.enable {
      groups.roundcube_users.present = true;
      systems.oauth2.roundcube = {
        displayName = "Roundcube";
        originUrl = "https://${cfg.subdomain}.${domain}/index.php/login/oauth";
        originLanding = "https://${cfg.subdomain}.${domain}/";
        basicSecretFile = pkgs.writeText "bs-roundcube" "VERYSTRONGSECRETFORROUNDCUBE";
        # when true, name is passed to a service instead of name@domain
        preferShortUsername = false;
        allowInsecureClientDisablePkce = true; # FIXME is it needed?
        scopeMaps.roundcube_users = [
          "email"
          "profile"
          "openid"
        ];
        # scopeMaps.roundcube_users = [
        #   "email"
        #   "openid"
        #   "dovecotprofile"
        # ];

        # add more scopes when a user is a member of specific group
        # claimMaps.groups = {
        #   joinType = "array";
        #   valuesByGroup = {
        #     "sp.roundcube.admin" = [ "admin" ];
        #   };
        # };
      };
    };
  };
}
