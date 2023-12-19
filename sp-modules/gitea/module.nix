{ config, lib, ... }:
let
  sp = config.selfprivacy;
  stateDir =
    if sp.useBinds
    then "/volumes/${sp.modules.gitea.location}/gitea"
    else "/var/lib/gitea";
in
{
  options.selfprivacy.modules.gitea = {
    enable = lib.mkOption {
      default = false;
      type = with lib.types; nullOr bool;
    };
    location = lib.mkOption {
      default = "sda1";
      type = with lib.types; nullOr str;
    };
  };

  config = lib.mkIf config.selfprivacy.modules.gitea.enable {
    fileSystems = lib.mkIf sp.useBinds {
      "/var/lib/gitea" = {
        device = "/volumes/${sp.modules.gitea.location}/gitea";
        options = [ "bind" ];
      };
    };
    services.gitea = {
      enable = true;
      inherit stateDir;
      #      log = {
      #        rootPath = "/var/lib/gitea/log";
      #        level = "Warn";
      #      };
      user = "gitea";
      database = {
        type = "sqlite3";
        host = "127.0.0.1";
        name = "gitea";
        user = "gitea";
        path = "${stateDir}/data/gitea.db";
        createDatabase = true;
      };
      # ssh = {
      #   enable = true;
      #   clonePort = 22;
      # };
      lfs = {
        enable = true;
        contentDir = "${stateDir}/lfs";
      };
      appName = "SelfPrivacy git Service";
      repositoryRoot = "${stateDir}/repositories";
      #      cookieSecure = true;
      settings = {
        server = {
          DOMAIN = "git.${sp.domain}";
          ROOT_URL = "https://git.${sp.domain}/";
          HTTP_ADDR = "0.0.0.0";
          HTTP_PORT = 3000;
        };
        mailer = {
          ENABLED = false;
        };
        ui = {
          DEFAULT_THEME = "arc-green";
          SHOW_USER_EMAIL = false;
        };
        picture = {
          DISABLE_GRAVATAR = true;
        };
        admin = {
          ENABLE_KANBAN_BOARD = true;
        };
        repository = {
          FORCE_PRIVATE = false;
        };
        session = {
          COOKIE_SECURE = true;
        };
        log = {
          ROOT_PATH = "${stateDir}/log";
          LEVEL = "Warn";
        };
      };
    };
    services.nginx.virtualHosts."git.${sp.domain}" = {
      sslCertificate = "/var/lib/acme/wildcard-${sp.domain}/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/wildcard-${sp.domain}/key.pem";
      forceSSL = true;
      extraConfig = ''
        add_header Strict-Transport-Security $hsts_header;
        #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;
        add_header 'Referrer-Policy' 'origin-when-cross-origin';
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
        expires 10m;
      '';
      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:3000";
        };
      };
    };
    systemd.services.gitea.unitConfig.RequiresMountsFor =
      lib.mkIf sp.useBinds "/volumes/${sp.modules.gitea.location}/gitea";
  };
}
