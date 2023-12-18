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
    services = {
      gitea = {
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
        domain = "git.${sp.domain}";
        rootUrl = "https://git.${sp.domain}/";
        httpAddress = "0.0.0.0";
        httpPort = 3000;
        #      cookieSecure = true;
        settings = {
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
    };
    systemd.services.gitea.unitConfig.RequiresMountsFor =
      lib.mkIf sp.useBinds "/volumes/${sp.modules.gitea.location}/gitea";
  };
}
