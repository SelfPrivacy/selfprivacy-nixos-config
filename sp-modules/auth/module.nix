{ config, lib, pkgs, ... }:
let
  passthru = config.passthru.selfprivacy.auth;
  cfg = config.selfprivacy.modules.auth;
  domain = config.selfprivacy.domain;

  kanidm-bind-address = "127.0.0.1:3013";

  # lua stuff for debugging only
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

    # for ExecStartPost scripts to have access to /run/keys/*
    users.groups.keys.members = [ "kanidm" ];

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
        origin = "https://" + passthru.auth-fqdn;

        # TODO revise this: maybe kanidm must not have access to a public TLS
        tls_chain =
          "${config.security.acme.certs.${domain}.directory}/fullchain.pem";
        tls_key =
          "${config.security.acme.certs.${domain}.directory}/key.pem";

        # nginx should proxy requests to it
        bindaddress = kanidm-bind-address;

        ldapbindaddress =
          "${passthru.ldap-host}:${toString passthru.ldap-port}";

        # kanidm is behind a proxy
        trust_x_forward_for = true;

        log_level = if cfg.debug then "trace" else "info";
      };
      provision = {
        enable = true;
        autoRemove = true; # if false, obsolete oauth2 scopeMaps remain
        groups."sp.admins".present = true;
      };
      enableClient = true;
      clientSettings = {
        uri = "https://" + passthru.auth-fqdn;
        verify_ca = false; # FIXME
        verify_hostnames = false; # FIXME
      };
    };

    services.nginx = {
      enable = true;
      additionalModules =
        lib.mkIf cfg.debug [ pkgs.nginxModules.lua ];
      commonHttpConfig = lib.mkIf cfg.debug ''
        log_format kanidm escape=none '$request $status\n'
                                      '[Request body]: $request_body\n'
                                      '[Header]: $resp_header\n'
                                      '[Response Body]: $resp_body\n\n';
        lua_package_path "${lua_path}";
      '';
      virtualHosts.${passthru.auth-fqdn} = {
        useACMEHost = domain;
        forceSSL = true;
        locations."/" = {
          extraConfig = lib.mkIf cfg.debug ''
            access_log /var/log/nginx/kanidm.log kanidm;

            lua_need_request_body on;

            # log header
            set $req_header "";
            set $resp_header "";
            header_filter_by_lua '
              local h = ngx.req.get_headers()
              for k, v in pairs(h) do
                if type(v) == "table" then
                  ngx.var.req_header = ngx.var.req_header .. k .. "=" .. table.concat(v, ", ") .. " "
                else
                  ngx.var.req_header = ngx.var.req_header .. k .. "=" .. v .. " "
                end
              end
              local rh = ngx.resp.get_headers()
              for k, v in pairs(rh) do
                if type(v) == "table" then
                  ngx.var.resp_header = ngx.var.resp_header .. k .. "=" .. table.concat(v, ", ") .. " "
                else
                  ngx.var.resp_header = ngx.var.resp_header .. k .. "=" .. v .. " "
                end
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
    };

    passthru.selfprivacy.auth = rec {
      auth-fqdn = cfg.subdomain + "." + domain;
      oauth2-introspection-url = client_id: client_secret:
        "https://${client_id}:${client_secret}@${auth-fqdn}/oauth2/token/introspect";
      oauth2-discovery-url = client_id:
        "https://${auth-fqdn}/oauth2/openid/${client_id}/.well-known/openid-configuration";
      oauth2-provider-name = "kanidm";
      oauth2-systemd-service = "kanidm.service";

      # e.g. "dc=mydomain,dc=com"
      ldap-base-dn =
        lib.strings.concatMapStringsSep
          ","
          (x: "dc=" + x)
          (lib.strings.splitString "." domain);
      ldap-host = "127.0.0.1";
      ldap-port = 3636;
    };
  };
}
