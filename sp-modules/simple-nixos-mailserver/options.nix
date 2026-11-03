{
  selfprivacy,
  lib,
  ...
}:
{
  options.selfprivacy.modules.simple-nixos-mailserver = {
    enable = selfprivacy.types.enableOption "mail server";
    location = selfprivacy.types.locationOption;
  };

  options.selfprivacy.emails =
    with lib;
    mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              systemdServices = mkOption {
                type = with types; listOf str;
                default = [ ];
                example = [ "myservice" ];
                description = "Systemd service(s) which requires generated password.";
              };

              user = mkOption {
                type = with types; str;
                example = "user";
                description = "Mailboxes and password file owner user.";
              };

              group = mkOption {
                type = with types; str;
                example = "group";
                description = "Mailboxes and password file owner group.";
              };

              sendOnly = mkOption {
                type = types.bool;
                default = true;
                description = "Reject incoming mail to this service account.";
              };

              passwordFile = mkOption {
                type = types.str;
                default = "/run/sp-mailboxes/${name}/password";
                readOnly = true;
                description = "Generated plaintext password file path.";
              };
            };
          }
        )
      );

      description = ''
        This option gives modules possibility to create mailboxes to send emails, e.g. notifications or reminders.
        Services must follow the format 'name.service' for their email addresses.
        Add your services to the selfprivacy.emails.<name>.systemdServices to make them depend on password generation service.

        Don't use this option to create regular users!!!
      '';

      example = {
        "noreply.mastodon" = {
          systemdServices = [ "mastodon" ];
          user = "mastodon";
          group = "mastodon";
          sendOnly = true;
        };
      };

      default = { };
    };
}
