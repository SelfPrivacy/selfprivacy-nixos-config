nixpkgs-2411: { config, lib, pkgs, ... }:
let
  domain = config.selfprivacy.domain;
  subdomain = "auth";
  auth-fqdn = subdomain + "." + domain;

  ldap-host = "127.0.0.1";
  ldap-port = 3636;

  keys-path = "/run/keys";

  admins-group = "sp.admins";
  full-users-group = "sp.full_users";

  kanidm-bind-address = "127.0.0.1:3013";

  selfprivacy-group = config.users.users."selfprivacy-api".group;

  selfprivacy-service-account-name = "sp.selfprivacy-api.service-account";

  kanidm-service-account-token-name =
    "${selfprivacy-group}-service-account-token";
  kanidm-service-account-token-fp =
    "${keys-path}/${selfprivacy-group}/kanidm-service-account-token";
  kanidmExecStartPreScriptRoot = pkgs.writeShellScript
    "${selfprivacy-group}-kanidm-ExecStartPre-root-script.sh"
    ''
      # set-group-ID bit allows for kanidm user to create files,
      mkdir -p -v --mode=u+rwx,g+rs,g-w,o-rwx /run/keys/${selfprivacy-group}
      chown kanidm:${selfprivacy-group} /run/keys/${selfprivacy-group}
    '';

  spApiUserExecStartPostScript =
    pkgs.writeShellScript "spApiUserExecStartPostScript" ''
      export HOME=$RUNTIME_DIRECTORY/client_home
      readonly KANIDM="${pkgs.kanidm}/bin/kanidm"

      # get Kanidm service account for SelfPrivacyAPI
      KANIDM_SERVICE_ACCOUNT="$($KANIDM service-account list --name idm_admin | grep -E "^name: ${selfprivacy-service-account-name}$")"
      echo KANIDM_SERVICE_ACCOUNT: "$KANIDM_SERVICE_ACCOUNT"
      if [ -n "$KANIDM_SERVICE_ACCOUNT" ]
      then
          echo "kanidm service account \"${selfprivacy-service-account-name}\" is found"
      else
          echo "kanidm service account \"${selfprivacy-service-account-name}\" is not found"
          echo "creating new kanidm service account \"${selfprivacy-service-account-name}\""
          if $KANIDM service-account create --name idm_admin "${selfprivacy-service-account-name}" "SelfPrivacy API service account" idm_admin
          then
              echo "kanidm service account \"${selfprivacy-service-account-name}\" created"
          else
              echo "error: cannot create kanidm service account \"${selfprivacy-service-account-name}\""
              exit 1
          fi
      fi

      $KANIDM group add-members idm_admins "${selfprivacy-service-account-name}"

      # create a new read-write token for kanidm
      if ! KANIDM_SERVICE_ACCOUNT_TOKEN_JSON="$($KANIDM service-account api-token generate --name idm_admin "${selfprivacy-service-account-name}" "${kanidm-service-account-token-name}" --output json)"
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
      ${kanidm-service-account-token-fp}
      then
          echo "error: cannot write token to \"${kanidm-service-account-token-fp}\""
          exit 1
      fi
    '';

  # lua stuff for nginx for debugging only
  lua_core_path = "${pkgs.luajitPackages.lua-resty-core}/lib/lua/5.1/?.lua";
  lua_lrucache_path = "${pkgs.luajitPackages.lua-resty-lrucache}/lib/lua/5.1/?.lua";
  lua_path = "${lua_core_path};${lua_lrucache_path};";
in
lib.mkIf config.selfprivacy.sso.enable {
  nixpkgs.overlays = [
    (
      _final: prev: {
        inherit (nixpkgs-2411.legacyPackages.${prev.system}) kanidm;
        kanidm-provision =
          (nixpkgs-2411.legacyPackages.${prev.system}).callPackage
            ./kanidm-provision.nix
            { };
      }
    )
  ];

  networking.hosts = {
    # Allow the services to communicate with kanidm even if
    # there is no DNS record yet
    "127.0.0.1" = [ auth-fqdn ];
  };


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
      origin = "https://" + auth-fqdn;

      # TODO revise this: maybe kanidm must not have access to a public TLS
      tls_chain =
        "${config.security.acme.certs.${domain}.directory}/fullchain.pem";
      tls_key =
        "${config.security.acme.certs.${domain}.directory}/key.pem";

      # nginx should proxy requests to it
      bindaddress = kanidm-bind-address;

      ldapbindaddress =
        "${ldap-host}:${toString ldap-port}";

      # kanidm is behind a proxy
      trust_x_forward_for = true;

      log_level = if config.selfprivacy.sso.debug then "trace" else "info";
    };
    provision = {
      enable = true;
      autoRemove = true; # if false, obsolete oauth2 scopeMaps remain
      groups.${admins-group}.present = true;
      groups.${full-users-group}.present = true;
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
      lib.mkIf config.selfprivacy.sso.debug [ pkgs.nginxModules.lua ];
    commonHttpConfig = lib.mkIf config.selfprivacy.sso.debug ''
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
        extraConfig = lib.mkIf config.selfprivacy.sso.debug ''
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

  systemd.services.kanidm.serviceConfig.ExecStartPre =
    [ ("+" + kanidmExecStartPreScriptRoot) ];
  systemd.services.kanidm.serviceConfig.ExecStartPost = lib.mkAfter
    [ spApiUserExecStartPostScript ];

  selfprivacy.passthru.auth = {
    inherit
      admins-group
      auth-fqdn
      full-users-group
      ldap-host
      ldap-port
      keys-path
      ;
    oauth2-introspection-url-prefix = client_id: "https://${client_id}:";
    oauth2-introspection-url-postfix =
      "@${auth-fqdn}/oauth2/token/introspect";
    oauth2-discovery-url = client_id:
      "https://${auth-fqdn}/oauth2/openid/${client_id}/.well-known/openid-configuration";
    oauth2-provider-name = "Kanidm";
    oauth2-systemd-service = "kanidm.service";

    # e.g. "dc=mydomain,dc=com"
    ldap-base-dn =
      lib.strings.concatMapStringsSep
        ","
        (x: "dc=" + x)
        (lib.strings.splitString "." domain);

    # TODO consider to pass a value or throw exception if token is not generated
    mkServiceAccountTokenFP = linuxGroup:
      "${keys-path}/${linuxGroup}/kanidm-service-account-token";

    mkOAuth2ClientSecretFP = linuxGroup:
      "${keys-path}/${linuxGroup}/kanidm-oauth-client-secret";
  };
}
