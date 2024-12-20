{ config, lib, pkgs, ... }@nixos-args:
let
  inherit (import ./common.nix nixos-args)
    auth-fqdn
    cfg
    domain
    kanidm_ldap_port
    ldap_base_dn
    passthru
    ;

  lua_core_path = "${pkgs.luajitPackages.lua-resty-core}/lib/lua/5.1/?.lua";
  lua_lrucache_path = "${pkgs.luajitPackages.lua-resty-lrucache}/lib/lua/5.1/?.lua";
  lua_path = "${lua_core_path};${lua_lrucache_path};";
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

        # nginx should proxy requests to it
        bindaddress = passthru.kanidm-bind-address;

        ldapbindaddress = "127.0.0.1:${toString kanidm_ldap_port}";

        # kanidm is behind a proxy
        trust_x_forward_for = true;

        log_level = if cfg.debug then "trace" else "info";
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
          proxyPass = "https://${passthru.kanidm-bind-address}";
        };
      };
    };

    # TODO move to mailserver module everything below
    mailserver.debug = cfg.debug; # FIXME
    mailserver.mailDirectory = "/var/vmail";

    mailserver.loginAccounts = lib.mkForce { };
    mailserver.extraVirtualAliases = lib.mkForce { };
    # LDAP is needed for Postfix to query Kanidm about email address ownership.
    # LDAP is needed for Dovecot also.
    mailserver.ldap = {
      enable = false;
      # bind.dn = "uid=mail,ou=persons," + ldap_base_dn;
      bind.dn = "dn=token";
      # TODO change in this file should trigger system restart dovecot
      bind.passwordFile = "/run/keys/dovecot/kanidm-service-account-token"; # FIXME

      # searchBase = "ou=persons," + ldap_base_dn;
      searchBase = ldap_base_dn; # TODO refine this

      # NOTE: 127.0.0.1 instead of localhost does not work for unknown reason
      uris = [ "ldaps://localhost:${toString kanidm_ldap_port}" ];
    };

    environment.systemPackages = lib.lists.optionals cfg.debug [
      pkgs.shelldap
      pkgs.openldap
    ];

    passthru.selfprivacy.auth = {
      kanidm-bind-address = "127.0.0.1:3013";
      oauth2-introspection-url = client_id: client_secret:
        "https://${client_id}:${client_secret}@${auth-fqdn}/oauth2/token/introspect";
      oauth2-discovery-url = client_id: "https://${auth-fqdn}/oauth2/openid/${client_id}/.well-known/openid-configuration";
    };
  };
}
