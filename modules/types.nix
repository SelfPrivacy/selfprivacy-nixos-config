{ lib, ... }:
{
  selfprivacy.passthru.types = rec {
    subdomainType = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9]";
    subdomainOption =
      default:
      (lib.mkOption {
        inherit default;
        type = subdomainType;
        description = "Subdomain";
      })
      // {
        meta = {
          widget = "subdomain";
          type = "string";
          regex = "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
          weight = 0;
        };
      };
  };
}
