{
  description = "Actual (aka Actual Budget) is a super fast and privacy-focused app for managing your finances.";

  outputs =
    { ... }:
    {
      nixosModules.default = import ./module.nix;

      meta =
        { lib, ... }:
        {
          spModuleSchemaVersion = 1;
          id = "actual";
          name = "Actual";
          description = "Actual (aka Actual Budget) is a super fast and privacy-focused app for managing your finances.";
          svgIcon = builtins.readFile ./icon.svg;
          showUrl = true;
          primarySubdomain = "subdomain";
          isMovable = true;
          isRequired = false;
          canBeBackedUp = true;
          backupDescription = "Your budgets, settings, and account secrets (where applicable).";
          systemdServices = [
            "actual.service"
          ];
          user = "actual";
          group = "actual";
          folders = [
            "/var/lib/actual"
          ];

          license = [
            lib.licenses.mit
          ];
          homepage = "https://actualbudget.org/";
          sourcePage = "https://github.com/actualbudget/actual";
          supportLevel = "community";
        };
    };
}
