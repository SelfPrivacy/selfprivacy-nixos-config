{ config, lib, pkgs, ... }:
let
  domain = config.selfprivacy.domain;
  cfg = config.selfprivacy.modules.roundcube;
  auth-module = config.selfprivacy.modules.auth;
  auth-fqdn = auth-module.subdomain + "." + domain;
  oauth-client-id = "roundcube";
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
    services.roundcube = {
      enable = true;
      # this is the url of the vhost, not necessarily the same as the fqdn of
      # the mailserver
      hostName = "${cfg.subdomain}.${config.selfprivacy.domain}";
      extraConfig = ''
        # starttls needed for authentication, so the fqdn required to match
        # the certificate
        $config['smtp_server'] = "tls://${config.mailserver.fqdn}";
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
        $config['oauth_auth_parameters'] = [];
        $config['oauth_identity_fields'] = ['email'];
        $config['oauth_login_redirect'] = true;
        $config['auto_create_user'] = true;
      '';
    };
    services.nginx.virtualHosts."${cfg.subdomain}.${domain}" = {
      forceSSL = true;
      useACMEHost = domain;
      enableACME = false;
    };
    systemd = {
      services = {
        phpfpm-roundcube.serviceConfig.Slice = lib.mkForce "roundcube.slice";
      };
      slices.roundcube = {
        description = "Roundcube service slice";
      };
    };

    services.kanidm.provision = lib.mkIf auth-module.enable {
      groups.roundcube_users.present = true;
      systems.oauth2.roundcube =
        {
          displayName = "Roundcube";
          originUrl = "https://${cfg.subdomain}.${domain}/";
          originLanding = "https://${cfg.subdomain}.${domain}/";
          basicSecretFile = pkgs.writeText "bs-roundcube" "VERYSTRONGSECRETFORROUNDCUBE";
          # when true, name is passed to a service instead of name@domain
          preferShortUsername = false;
          allowInsecureClientDisablePkce = true; # FIXME is it needed?
          scopeMaps.roundcube_users = [
            "email"
            # "groups"
            "profile"
            "openid"
            # "dovecotprofile"
          ];
        };
    };
  };
}
