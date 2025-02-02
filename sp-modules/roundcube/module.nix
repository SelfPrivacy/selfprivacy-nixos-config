{ config, lib, pkgs, ... }:
let
  domain = config.selfprivacy.domain;
  cfg = config.selfprivacy.modules.roundcube;
  is-auth-enabled = cfg.enableSso && config.selfprivacy.sso.enable;
  auth-passthru = config.selfprivacy.passthru.auth;
  auth-fqdn = auth-passthru.auth-fqdn;
  sp-module-name = "roundcube";
  user = "roundcube";
  group = "roundcube";
  oauth-donor = config.selfprivacy.passthru.mailserver;
  kanidm-oauth-client-secret-fp =
    "/run/keys/${group}/kanidm-oauth-client-secret";
  kanidmExecStartPreScriptRoot = pkgs.writeShellScript
    "${sp-module-name}-kanidm-ExecStartPre-root-script.sh"
    ''
      # set-group-ID bit allows for kanidm user to create files inheriting group
      mkdir -p -v --mode=u+rwx,g+rs,g-w,o-rwx /run/keys/${group}
      chown kanidm:${group} /run/keys/${group}

      install -v -m640 -o kanidm -g ${group} ${oauth-donor.oauth-client-secret-fp} ${kanidm-oauth-client-secret-fp}
    '';
in
{
  options.selfprivacy.modules.roundcube = {
    enable = (lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable";
    }) // {
      meta = {
        type = "enable";
      };
    };
    subdomain = (lib.mkOption {
      default = "roundcube";
      type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
      description = "Subdomain";
    }) // {
      meta = {
        widget = "subdomain";
        type = "string";
        regex = "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
        weight = 0;
      };
    };
    enableSso = (lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable SSO for Roundcube";
    }) // {
      meta = {
        type = "enable";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.enableSso -> config.selfprivacy.sso.enable;
          message =
            "SSO cannot be enabled for Roundcube when SSO is disabled globally.";
        }
      ];
      services.roundcube = {
        enable = true;
        # this is the url of the vhost, not necessarily the same as the fqdn of
        # the mailserver
        hostName = "${cfg.subdomain}.${config.selfprivacy.domain}";
        extraConfig = ''
          # starttls needed for authentication, so the fqdn required to match
          # the certificate
          $config['smtp_host'] = "tls://${config.mailserver.fqdn}";
          $config['smtp_user'] = "%u";
          $config['smtp_pass'] = "%p";
        '';
      };

      services.nginx.virtualHosts."${cfg.subdomain}.${domain}" = {
        forceSSL = true;
        useACMEHost = domain;
        enableACME = false;
      };

      systemd.slices.roundcube.description = "Roundcube service slice";
      # Roundcube depends on Dovecot and its OAuth2 client secret.
      systemd.services.roundcube.after = [ "dovecot2.service" ];
    }
    # the following part is active only when "auth" module is enabled
    (lib.mkIf is-auth-enabled {
      # for phpfpm-roundcube to have access to get through /run/keys directory
      users.groups.keys.members = [ user ];
      services.roundcube.extraConfig = lib.mkAfter ''
        $config['oauth_provider'] = 'generic';
        $config['oauth_provider_name'] = '${auth-passthru.oauth2-provider-name}';
        $config['oauth_client_id'] = '${oauth-donor.oauth-client-id}';
        $config['oauth_client_secret'] = file_get_contents('${kanidm-oauth-client-secret-fp}');
        $config['oauth_auth_uri'] = 'https://${auth-fqdn}/ui/oauth2';
        $config['oauth_token_uri'] = 'https://${auth-fqdn}/oauth2/token';
        $config['oauth_identity_uri'] = 'https://${auth-fqdn}/oauth2/openid/${oauth-donor.oauth-client-id}/userinfo';
        $config['oauth_scope'] = 'email profile openid'; # FIXME
        $config['oauth_auth_parameters'] = [];
        $config['oauth_identity_fields'] = ['email'];
        $config['oauth_login_redirect'] = true;
        $config['auto_create_user'] = true;
        $config['oauth_verify_peer'] = false; # FIXME
        # $config['oauth_pkce'] = 'S256'; # FIXME
      '';
      systemd.services.roundcube = {
        after = [ auth-passthru.oauth2-systemd-service ];
        requires = [ auth-passthru.oauth2-systemd-service ];
      };
      systemd.services.kanidm = {
        serviceConfig.ExecStartPre = lib.mkBefore [
          ("-+" + kanidmExecStartPreScriptRoot)
        ];
      };
      services.kanidm.provision = {
        groups = {
          "sp.roundcube.admins".members = [ auth-passthru.admins-group ];
          "sp.roundcube.users".members =
            [ "sp.roundcube.admins" auth-passthru.full-users-group ];
        };
        systems.oauth2.${oauth-donor.oauth-client-id} = {
          displayName = "Roundcube";
          originUrl = "https://${cfg.subdomain}.${domain}/index.php/login/oauth";
          originLanding = "https://${cfg.subdomain}.${domain}/";
          basicSecretFile = kanidm-oauth-client-secret-fp;
          # when true, name is passed to a service instead of name@domain
          preferShortUsername = false;
          allowInsecureClientDisablePkce = true; # FIXME is it needed?
          scopeMaps = {
            "sp.roundcube.users" = [
              "email"
              "openid"
              "profile"
            ];
          };
          removeOrphanedClaimMaps = true;
        };
      };
    })
  ]);
}
