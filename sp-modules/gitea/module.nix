{ config, lib, ... }:
let
  sp = config.selfprivacy;
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
    systemd.services.gitea.unitConfig = lib.mkIf sp.useBinds {
      RequiresMountsFor = "/var/lib/gitea";
      ConditionPathIsMountPoint = "/var/lib/gitea";
    };
    services = {
      gitea = {
        enable = true;
        stateDir = "/var/lib/gitea";
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
          path = "/var/lib/gitea/data/gitea.db";
          createDatabase = true;
        };
        # ssh = {
        #   enable = true;
        #   clonePort = 22;
        # };
        lfs = {
          enable = true;
          contentDir = "/var/lib/gitea/lfs";
        };
        appName = "SelfPrivacy git Service";
        repositoryRoot = "/var/lib/gitea/repositories";
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
            ROOT_PATH = "/var/lib/gitea/log";
            LEVEL = "Warn";
          };
        };
      };
    };
  };
}
