{
  config,
  lib,
  pkgs,
  selfprivacy,
  ...
}:
let
  domain = config.selfprivacy.domain;
  sp = config.selfprivacy;
  cfg = sp.modules.mumble;
in
{
  options.selfprivacy.modules.mumble = {
    enable = selfprivacy.types.enableOption "Mumble";
    subdomain = selfprivacy.types.subdomainOption "mumble";
    location = selfprivacy.types.locationOption;
    appName =
      (lib.mkOption {
        default = "SelfPrivacy Mumble Service";
        type = lib.types.str;
        description = "The name of your Mumble server";
      })
      // {
        meta = {
          type = "string";
          weight = 1;
        };
      };
    welcomeText =
      (lib.mkOption {
        default = "Welcome to my Mumble server!";
        type = lib.types.str;
        description = "Welcome message";
      })
      // {
        meta = {
          type = "string";
          weight = 2;
        };
      };
  };

  config = lib.mkIf cfg.enable {
    fileSystems = lib.mkIf sp.useBinds {
      "/var/lib/murmur" = {
        device = "/volumes/${cfg.location}/murmur";
        options = [
          "bind"
          "x-systemd.required-by=murmur.service"
          "x-systemd.required-by=murmur-ensure-folder-ownership.service"
          "x-systemd.before=murmur.service"
          "x-systemd.before=murmur-ensure-folder-ownership.service"
        ];
      };
    };
    services.murmur = {
      enable = true;
      openFirewall = true;
      registerHostname = "${cfg.subdomain}.${domain}";
      hostName = "${cfg.subdomain}.${domain}";
      registerName = cfg.appName;
    };
    systemd = {
      services = {
        murmur = {
          serviceConfig.Slice = "mumble.slice";
        };
        murmur-ensure-folder-ownership = {
          description = "Ensure murmur folder ownership";
          before = [ "murmur.service" ];
          requiredBy = [ "murmur.service" ];
          serviceConfig.Type = "oneshot";
          serviceConfig.Slice = "mumble.slice";
          path = with pkgs; [ coreutils ];
          script = ''
            chown -R murmur:murmur /var/lib/murmur
          '';
        };
      };
      slices.mumble = {
        description = "Mumble service slice";
      };
    };
  };
}
