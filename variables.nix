{ pkgs, ... }:
{
  services = {
    userdata = builtins.fromJSON (builtins.readFile "./userdata/userdata.json");
  };
}
