{
  description = "Mastodon module";

  outputs =
    { ... }:
    {
      nixosModules.default = import ./module.nix;
      meta =
        { lib, ... }:
        {
          spModuleSchemaVersion = 1;
          id = "mastodon";
          name = "Mastodon";
          description = "Mastodon is a free non-profit decentralized social media, a part of Fediverse network, offering a web client and a mobile app.";
          svgIcon = builtins.readFile ./icon.svg;
          isMovable = true;
          isRequired = false;
          backupDescription = "Mastodon and federation data, attachments and media.";
          systemdServices = [
            "mastodon-web.service"
            "mastodon-sidekiq-all.service"
            "mastodon-streaming-1.service"
            "mastodon-streaming-2.service"
            "mastodon-kanidm-sync.service"
          ];
          folders = [
            "/var/lib/mastodon"
          ];
          postgreDatabases = [
            "mastodon"
          ];
          license = [
            lib.licenses.agpl3Plus
          ];
          homepage = "https://joinmastodon.org";
          sourcePage = "https://github.com/mastodon/mastodon";
          supportLevel = "normal";
          sso = {
            userGroup = "sp.mastodon.users";
            adminsGroup = "sp.mastodon.admins";
          };
        };
    };
}
