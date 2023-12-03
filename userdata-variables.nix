jsonData: { lib, ... }:
{
  selfprivacy = jsonData // {
    hostname = lib.attrsets.attrByPath [ "hostname" ] null jsonData;
    domain = lib.attrsets.attrByPath [ "domain" ] null jsonData;
    timezone = lib.attrsets.attrByPath [ "timezone" ] "Europe/Uzhgorod" jsonData;
    stateVersion = lib.attrsets.attrByPath [ "stateVersion" ] "22.05" jsonData;
    username = lib.attrsets.attrByPath [ "username" ] null jsonData;
    hashedMasterPassword = lib.attrsets.attrByPath [ "hashedMasterPassword" ] null jsonData;
    sshKeys = lib.attrsets.attrByPath [ "sshKeys" ] [ ] jsonData;
    dns = {
      provider = lib.attrsets.attrByPath [ "dns" "provider" ] "CLOUDFLARE" jsonData;
      useStagingACME = lib.attrsets.attrByPath [ "dns" "useStagingACME" ] false jsonData;
    };
    backup = {
      bucket = lib.attrsets.attrByPath [ "backup" "bucket" ] (lib.attrsets.attrByPath [ "backblaze" "bucket" ] "" jsonData) jsonData;
    };
    server = {
      provider = lib.attrsets.attrByPath [ "server" "provider" ] "HETZNER" jsonData;
    };
    gitea = {
      enable = lib.attrsets.attrByPath [ "gitea" "enable" ] false jsonData;
      location = lib.attrsets.attrByPath [ "gitea" "location" ] "sda1" jsonData;
    };
    jitsi = {
      enable = lib.attrsets.attrByPath [ "jitsi" "enable" ] false jsonData;
    };
    ssh = {
      enable = lib.attrsets.attrByPath [ "ssh" "enable" ] true jsonData;
      rootKeys = lib.attrsets.attrByPath [ "ssh" "rootKeys" ] [ "" ] jsonData;
      passwordAuthentication = lib.attrsets.attrByPath [ "ssh" "passwordAuthentication" ] true jsonData;
    };
    email = {
      location = lib.attrsets.attrByPath [ "email" "location" ] "sda1" jsonData;
    };
    users = lib.attrsets.attrByPath [ "users" ] [ ] jsonData;
    volumes = lib.attrsets.attrByPath [ "volumes" ] [ ] jsonData;
  };
}
