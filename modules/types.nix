{ lib, ... }:
let
  overridableOptionDefinition =
    optionDef: metaDef:
    (lib.mkOption optionDef)
    // {
      meta = metaDef;
      __functor =
        _:
        {
          option ? { },
          meta ? { },
        }:
        overridableOptionDefinition (optionDef // option) (metaDef // meta);
    };
in
{
  selfprivacy.passthru.types = rec {
    subdomainType = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9]";
    subdomainOption =
      default:
      overridableOptionDefinition
        {
          inherit default;
          type = subdomainType;
          description = "Subdomain";
        }
        {
          widget = "subdomain";
          type = "string";
          regex = "[A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9]";
          weight = 0;
        };

    enableOption =
      serviceName:
      overridableOptionDefinition
        {
          default = false;
          type = lib.types.bool;
          description = "Enable ${serviceName}";
        }
        {
          type = "enable";
        };

    locationOption =
      overridableOptionDefinition
        {
          type = lib.types.str;
          description = "Data location";
        }
        {
          type = "location";
        };
  };
}
