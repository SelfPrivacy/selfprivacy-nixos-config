{ config, pkgs, ... }:
let
  cfg = config.services.userdata;
in
{
  services = {
    gitea = {
      enable = cfg.gitea.enable;
      stateDir = "/var/lib/gitea";
      log = {
        rootPath = "/var/lib/gitea/log";
        level = "Warn";
      };
      user = "gitea";
      database = {
        type = "sqlite3";
        host = "127.0.0.1";
        name = "gitea";
        user = "gitea";
        path = "/var/lib/gitea/data/gitea.db";
        createDatabase = true;
      };
      ssh = {
        enable = true;
        clonePort = 22;
      };
      lfs = {
        enable = true;
        contentDir = "/var/lib/gitea/lfs";
      };
      appName = "SelfPrivacy git Service";
      repositoryRoot = "/var/lib/gitea/repositories";
      domain = "git.${cfg.domain}";
      rootUrl = "https://${cfg.domain}/";
      httpAddress = "0.0.0.0";
      httpPort = 3000;
      cookieSecure = true;
      settings = {
        mailer = {
          ENABLED = false;
        };
        ui = {
          DEFAULT_THEME = "arc-green";
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
      };
    };
  };
}
