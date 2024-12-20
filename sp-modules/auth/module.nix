{ config, lib, pkgs, ... }:
let
  domain = config.selfprivacy.domain;
  cfg = config.selfprivacy.modules.auth;
  auth-fqdn = cfg.subdomain + "." + domain;
  oauth2-introspection-url = client_id: client_secret:
    "https://${client_id}:${client_secret}@${auth-fqdn}/oauth2/token/introspect";
  oauth2-discovery-url = client_id: "https://${auth-fqdn}/oauth2/openid/${client_id}/.well-known/openid-configuration";

  kanidm-bind-address = "127.0.0.1:3013";
  ldap_host = "127.0.0.1";
  ldap_port = 3636;
  # e.g. "dc=mydomain,dc=com"
  ldap_base_dn =
    lib.strings.concatMapStringsSep
      ","
      (x: "dc=" + x)
      (lib.strings.splitString "." domain);

  dovecot-oauth2-conf-file = pkgs.writeTextFile {
    name = "dovecot-oauth2.conf.ext";
    text = ''
      introspection_mode = post
      introspection_url = ${oauth2-introspection-url "roundcube" "VERYSTRONGSECRETFORROUNDCUBE"}
      client_id = roundcube
      client_secret = VERYSTRONGSECRETFORROUNDCUBE # FIXME
      username_attribute = username
      # scope = email groups profile openid dovecotprofile
      scope = email profile openid
      tls_ca_cert_file = /etc/ssl/certs/ca-certificates.crt
      active_attribute = active
      active_value = true
      openid_configuration_url = ${oauth2-discovery-url "roundcube"}
      debug = ${if cfg.debug then "yes" else "no"}
    '';
  };

  lua_core_path = "${pkgs.luajitPackages.lua-resty-core}/lib/lua/5.1/?.lua";
  lua_lrucache_path = "${pkgs.luajitPackages.lua-resty-lrucache}/lib/lua/5.1/?.lua";
  lua_path = "${lua_core_path};${lua_lrucache_path};";
  ldapConfFile = "/run/dovecot2/dovecot-ldap.conf.ext"; # FIXME get "dovecot2" from `config`
  mkLdapSearchScope = scope: (
    if scope == "sub" then "subtree"
    else if scope == "one" then "onelevel"
    else scope
  );
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
  dovecot-ldap-config = pkgs.writeTextFile {
    name = "dovecot-ldap.conf.ext.template";
    text = ''
      ldap_version = 3
      uris = ${lib.concatStringsSep " " config.mailserver.ldap.uris}
      ${lib.optionalString config.mailserver.ldap.startTls ''
      tls = yes
      ''}
      # tls_require_cert = hard
      # tls_ca_cert_file = ${config.mailserver.ldap.tlsCAFile}
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
in
{
  options.selfprivacy.modules.auth = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
    };
    subdomain = lib.mkOption {
      default = "auth";
      type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
    };
    debug = lib.mkOption {
      default = false;
      type = lib.types.bool;
    };
  };

  config = lib.mkIf cfg.enable {
    # kanidm uses TLS in internal connection with nginx too
    # FIXME revise this: maybe kanidm must not have access to a public TLS
    users.groups."acmereceivers".members = [ "kanidm" ];

    services.kanidm = {
      enableServer = true;

      # kanidm with Rust code patches for OAuth and admin passwords provisioning
      package = pkgs.kanidm.withSecretProvisioning;
      # package = pkgs.kanidm.withSecretProvisioning.overrideAttrs (_: {
      #   version = "git";
      #   src = pkgs.fetchFromGitHub {
      #     owner = "AleXoundOS";
      #     repo = "kanidm";
      #     rev = "a1a55f2e53facbfa504c7d64c44c3b5d0eb796c2";
      #     hash = "sha256-ADh4Zwn6EMt4CiOrvgG0RbmNMeR5i0ilVTxF46t/wm8=";
      #   };
      #   doCheck = false;
      # });

      serverSettings = {
        inherit domain;
        # The origin for webauthn. This is the url to the server, with the port
        # included if it is non-standard (any port except 443). This must match or
        # be a descendent of the domain name you configure above. If these two
        # items are not consistent, the server WILL refuse to start!
        origin = "https://" + auth-fqdn;

        # TODO revise this: maybe kanidm must not have access to a public TLS
        tls_chain =
          "${config.security.acme.certs.${domain}.directory}/fullchain.pem";
        tls_key =
          "${config.security.acme.certs.${domain}.directory}/key.pem";

        bindaddress = kanidm-bind-address; # nginx should connect to it
        ldapbindaddress = "${ldap_host}:${toString ldap_port}";

        # kanidm is behind a proxy
        trust_x_forward_for = true;

        log_level = "trace"; # FIXME
      };
      provision = {
        enable = true;
        autoRemove = false;
      };
      enableClient = true;
      clientSettings = {
        uri = "https://" + auth-fqdn;
        verify_ca = false; # FIXME
        verify_hostnames = false; # FIXME
      };
    };
    # systemd.services.kanidm.serviceConfig.ExecStartPost = lib.mkBefore ''
    #   # check kanidm online here with curl again?
    #   # use API key for group creation?
    # '';
    # services.phpfpm.pools.roundcube.settings = {
    #   catch_workers_output = true;
    #   "php_admin_value[error_log]" = "stdout";
    #   "php_admin_flag[log_errors]" = true;
    #   "php_admin_value[log_level]" = "debug";
    # };
    services.phpfpm.phpOptions = ''
      error_reporting = E_ALL
      display_errors = on;
    '';
    systemd.services.phpfpm-roundcube.serviceConfig = {
      StandardError = "journal";
      StandardOutput = "journal";
    };

    services.nginx = {
      enable = true;
      additionalModules =
        lib.lists.optional cfg.debug pkgs.nginxModules.lua;
      commonHttpConfig = lib.strings.optionalString cfg.debug ''
        log_format kanidm escape=none '$request $status\n'
                                      '[Request body]: $request_body\n'
                                      '[Header]: $resp_header\n'
                                      '[Response Body]: $resp_body\n\n';
        lua_package_path "${lua_path}";
      '';
      virtualHosts.${auth-fqdn} = {
        useACMEHost = domain;
        forceSSL = true;
        locations."/" = {
          # extraConfig = ''
          #   if ($args != $new_args) {
          #       rewrite ^ /ui/oauth2?$new_args? last;
          #   }
          # '';
          extraConfig = lib.strings.optionalString cfg.debug ''
            access_log /var/log/nginx/kanidm.log kanidm;

            lua_need_request_body on;

            # log header
            set $req_header "";
            set $resp_header "";
            header_filter_by_lua '
              local h = ngx.req.get_headers()
              for k, v in pairs(h) do
                ngx.var.req_header = ngx.var.req_header .. k.."="..v.." "
              end
              local rh = ngx.resp.get_headers()
              for k, v in pairs(rh) do
                ngx.var.resp_header = ngx.var.resp_header .. k.."="..v.." "
              end
            ';

            # log body
            set $resp_body "";
            body_filter_by_lua '
              local resp_body = string.sub(ngx.arg[1], 1, 4000)
              ngx.ctx.buffered = (ngx.ctx.buffered or "") .. resp_body
              if ngx.arg[2] then
                ngx.var.resp_body = ngx.ctx.buffered
              end
            ';
          '';
          proxyPass = "https://${kanidm-bind-address}";
        };
      };
      # appendHttpConfig = ''
      #   # Define a map to modify redirect_uri and append %2F if missing
      #   map $args $new_args {
      #       ~^((.*)(redirect_uri=[^&]+)(?!%2F)(.*))$ $2$3%2F$4;
      #       default $args;
      #   }
      # '';
    };

    # TODO move to mailserver module everything below
    mailserver.debug = cfg.debug; # FIXME
    mailserver.mailDirectory = "/var/vmail";

    mailserver.loginAccounts = lib.mkForce { };
    mailserver.extraVirtualAliases = lib.mkForce { };
    # LDAP is needed for Postfix to query Kanidm about email address ownership
    # LDAP is needed for Dovecot also.
    mailserver.ldap = {
      enable = false;
      # bind.dn = "uid=mail,ou=persons," + ldap_base_dn;
      bind.dn = "dn=token";
      # TODO change in this file should trigger system restart dovecot
      bind.passwordFile = "/run/keys/dovecot/kanidm-service-account-token"; # FIXME
      # searchBase = "ou=persons," + ldap_base_dn;
      searchBase = ldap_base_dn;
      # searchScope = "sub";
      uris = [ "ldaps://localhost:${toString ldap_port}" ];

      # note: in `ldapsearch` first comes filter, then attributes
      dovecot.userAttrs = "+"; # all operational attributes
      # TODO: investigate whether "mail=%u" is better than:
      # dovecot.userFilter = "(&(class=person)(uid=%n))";
      postfix.mailAttribute = "mail";
      postfix.uidAttribute = "uid";
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
          user = dovecot2
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

      #auth_username_format = %Ln

      # FIXME
      auth_debug = yes
      auth_debug_passwords = yes  # Be cautious with this in production as it logs passwords
      auth_verbose = yes
      mail_debug = yes
    '';
    services.dovecot2.enablePAM = false;
    services.postfix.extraConfig = ''
      debug_peer_list = 94.43.135.210, 134.209.202.195
      debug_peer_level = 3
      smtp_use_tls = yes
      # these below are already set in nixos-mailserver/mail-server/postfix.nix
      # smtpd_sasl_local_domain = ${domain}
      # smtpd_relay_restrictions = permit_sasl_authenticated, reject
      # smtpd_sender_restrictions =
      # smtpd_sender_login_maps =
      # smtpd_sasl_type = dovecot
      # smtpd_sasl_path = private-auth
      # smtpd_sasl_auth_enable = yes
    '';

    systemd.services.dovecot2 = {
      # TODO does it merge with existing preStart?
      preStart = setPwdInLdapConfFile + "\n";
    };

    # does it merge with existing restartTriggers?
    systemd.services.postfix.restartTriggers = [ setPwdInLdapConfFile ];

    environment.systemPackages = lib.lists.optionals cfg.debug [
      pkgs.shelldap
      pkgs.openldap
    ];
  };
}
