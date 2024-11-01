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
      debug = yes # FIXME
    '';
  };

  provisionAdminPassword = "abcd1234";
  provisionIdmAdminPassword = "abcd1234"; # FIXME
in
{
  options.selfprivacy.modules.auth = {
    enable = lib.mkOption {
      default = true;
      type = lib.types.bool;
    };
    subdomain = lib.mkOption {
      default = "auth";
      type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
    };
  };

  config = lib.mkIf cfg.enable {
    # kanidm uses TLS in internal connection with nginx too
    # FIXME revise this: maybe kanidm must not have access to a public TLS
    users.groups."acmereceivers".members = [ "kanidm" ];

    services.kanidm = {
      enableServer = true;

      # kanidm with Rust code patches for OAuth and admin passwords provisioning
      # package = pkgs.kanidm.withSecretProvisioning;
      # FIXME
      package = pkgs.kanidm.withSecretProvisioning.overrideAttrs (_: {
        version = "git";
        src = pkgs.fetchFromGitHub {
          owner = "AleXoundOS";
          repo = "kanidm";
          rev = "a1a55f2e53facbfa504c7d64c44c3b5d0eb796c2";
          hash = "sha256-ADh4Zwn6EMt4CiOrvgG0RbmNMeR5i0ilVTxF46t/wm8=";
        };
        doCheck = false;
      });

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

        # FIXME read randomly generated password from ?
        adminPasswordFile = pkgs.writeText "admin-pw" provisionAdminPassword;
        idmAdminPasswordFile = pkgs.writeText "idm-admin-pw" provisionIdmAdminPassword;
      };
      enableClient = true;
      clientSettings = {
        uri = "https://" + auth-fqdn;
        verify_ca = false; # FIXME
        verify_hostnames = false; # FIXME
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts.${auth-fqdn} = {
        useACMEHost = domain;
        forceSSL = true;
        locations."/" = {
          proxyPass =
            "https://${kanidm-bind-address}";
        };
      };
    };

    # TODO move to mailserver module everything below
    mailserver.debug = true; # FIXME
    mailserver.mailDirectory = "/var/vmail";
    services.dovecot2.extraConfig = ''
      auth_mechanisms = xoauth2 oauthbearer

      passdb {
        driver = oauth2
        mechanisms = xoauth2 oauthbearer
        args = ${dovecot-oauth2-conf-file}
      }

      userdb {
        driver = static
        args = uid=virtualMail gid=virtualMail home=/var/vmail/%u
      }

      # provide SASL via unix socket to postfix
      service auth {
        unix_listener /var/lib/postfix/private/auth {
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

      #auth_username_format = %Ln
      auth_debug = yes
      auth_debug_passwords = yes  # Be cautious with this in production as it logs passwords
      auth_verbose = yes
      mail_debug = yes
    '';
    services.dovecot2.enablePAM = false;
    services.postfix.extraConfig = ''
      smtpd_sasl_local_domain = ${domain}
      smtpd_relay_restrictions = permit_sasl_authenticated, reject
      smtpd_sasl_type = dovecot
      smtpd_sasl_path = private/auth
      smtpd_sasl_auth_enable = yes
    '';
  };
}
