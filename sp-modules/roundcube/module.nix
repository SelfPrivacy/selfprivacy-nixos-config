{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = config.selfprivacy.domain;
  cfg = config.selfprivacy.modules.roundcube;
  auth-passthru = config.selfprivacy.passthru.auth;
  auth-fqdn = auth-passthru.auth-fqdn;

  linuxUserOfService = "roundcube";
  linuxGroupOfService = "roundcube";

  sp-module-name = "roundcube";

  # SelfPrivacy uses SP Module ID to identify the group!
  adminsGroup = "sp.${sp-module-name}.admins";
  usersGroup = "sp.${sp-module-name}.users";

  oauth-donor = config.selfprivacy.passthru.mailserver;
  oauthClientSecretFP = auth-passthru.mkOAuth2ClientSecretFP linuxGroupOfService;
in
{
  options.selfprivacy.modules.roundcube = {
    enable =
      (lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Enable";
      })
      // {
        meta = {
          type = "enable";
        };
      };
    subdomain =
      (lib.mkOption {
        default = "roundcube";
        type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9]";
        description = "Subdomain";
      })
      // {
        meta = {
          widget = "subdomain";
          type = "string";
          regex = "[A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9]";
          weight = 0;
        };
      };
  };

  config = lib.mkIf cfg.enable {

    services.roundcube = {
      enable = true;
      # this is the url of the vhost, not necessarily the same as the fqdn of
      # the mailserver
      hostName = "${cfg.subdomain}.${config.selfprivacy.domain}";
    };

    services.nginx.virtualHosts."${cfg.subdomain}.${domain}" = {
      forceSSL = true;
      useACMEHost = domain;
      enableACME = false;
    };

    systemd.slices.roundcube.description = "Roundcube service slice";
    # Roundcube depends on Dovecot and its OAuth2 client secret.
    systemd.services.phpfpm-roundcube.after = [ "dovecot.service" ];

    services.roundcube.extraConfig = ''
      # starttls needed for authentication, so the fqdn required to match
      # the certificate
      $config['smtp_host'] = "tls://${config.mailserver.fqdn}";
      $config['smtp_user'] = "%u";
      $config['smtp_pass'] = "%p";

      $config['oauth_provider'] = 'generic';
      $config['oauth_provider_name'] = '${auth-passthru.oauth2-provider-name}';
      $config['oauth_client_id'] = '${oauth-donor.oauth-client-id}';
      $config['oauth_client_secret'] = file_get_contents('${oauthClientSecretFP}');
      $config['oauth_auth_uri'] = 'https://${auth-fqdn}/ui/oauth2';
      $config['oauth_token_uri'] = 'https://${auth-fqdn}/oauth2/token';
      $config['oauth_identity_uri'] = 'https://${auth-fqdn}/oauth2/openid/${oauth-donor.oauth-client-id}/userinfo';
      $config['oauth_scope'] = 'email profile openid';
      $config['oauth_auth_parameters'] = [];
      $config['oauth_identity_fields'] = ['email'];
      $config['oauth_login_redirect'] = true;
      $config['auto_create_user'] = true;
    '';
    systemd.services.roundcube = {
      after = [ "dovecot.service" ];
      requires = [ "dovecot.service" ];
    };
    systemd.services.kanidm.serviceConfig = {
      ExecStartPre = lib.mkAfter [
        (pkgs.writeShellScript "copy-mailserver-client-secret-to-roundcube" ''
          install -v -m640 -o kanidm -g ${linuxGroupOfService} ${oauth-donor.oauth-client-secret-fp} ${oauthClientSecretFP}
        '')
      ];
      SystemCallFilter = [
        "@chown"
      ];
    };

    selfprivacy.auth.clients."${oauth-donor.oauth-client-id}" = {
      inherit adminsGroup usersGroup;
      imageFile = ./icon.svg;
      displayName = "Roundcube";
      subdomain = cfg.subdomain;
      isTokenNeeded = false;
      isMailserver = true;
      originUrl = "https://${cfg.subdomain}.${domain}/index.php/login/oauth";
      originLanding = "https://${cfg.subdomain}.${domain}/";
      useShortPreferredUsername = false;
      clientSystemdUnits = [
        "dovecot.service"
        "phpfpm-roundcube.service"
      ];
      enablePkce = false;
      linuxUserOfClient = linuxUserOfService;
      linuxGroupOfClient = linuxGroupOfService;
      scopeMaps = {
        "${usersGroup}" = [
          "email"
          "openid"
          "profile"
        ];
      };
    };
  };
}
