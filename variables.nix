{ pkgs, lib, ... }:
let
  jsonData = builtins.fromJSON (builtins.readFile ./userdata/userdata.json);
in
{
  services.userdata = {
    hostname = lib.attrsets.attrByPath [ "hostname" ] null jsonData;
    domain = lib.attrsets.attrByPath [ "domain" ] null jsonData;
    timezone = lib.attrsets.attrByPath [ "timezone" ] "Europe/Uzhgorod" jsonData;
    autoUpgrade = {
      enable = lib.attrsets.attrByPath [ "autoUpgrade" "enable" ] true jsonData;
      allowReboot = lib.attrsets.attrByPath [ "autoUpgrade" "allowReboot" ] true jsonData;
    };
    username = lib.attrsets.attrByPath [ "username" ] null jsonData;
    hashedMasterPassword = lib.attrsets.attrByPath [ "hashedMasterPassword" ] null jsonData;
    sshKeys = lib.attrsets.attrByPath [ "sshKeys" ] [] jsonData;
    api = {
      token = jsonData.api.token;
      enableSwagger = lib.attrsets.attrByPath [ "api" "enableSwagger" ] false jsonData;
      skippedMigrations = lib.attrsets.attrByPath [ "api" "skippedMigrations" ] [] jsonData;
    };
    backblaze = {
      bucket = lib.attrsets.attrByPath [ "backblaze" "bucket" ] "" jsonData;
    };
    cloudflare = {
      apiKey = lib.attrsets.attrByPath [ "cloudflare" "apiKey" ] "" jsonData;
    };
    databasePassword = lib.attrsets.attrByPath [ "databasePassword" ] null jsonData;
    bitwarden = {
      enable = lib.attrsets.attrByPath [ "bitwarden" "enable" ] false jsonData;
    };
    gitea = {
      enable = lib.attrsets.attrByPath [ "gitea" "enable" ] false jsonData;
    };
    nextcloud = {
      enable = lib.attrsets.attrByPath [ "nextcloud" "enable" ] false jsonData;
      adminPassword = lib.attrsets.attrByPath [ "nextcloud" "adminPassword" ] "" jsonData;
    };
    pleroma = {
      enable = lib.attrsets.attrByPath [ "pleroma" "enable" ] false jsonData;
    };
    jitsi = {
      enable = lib.attrsets.attrByPath [ "jitsi" "enable" ] false jsonData;
    };
    ocserv = {
      enable = lib.attrsets.attrByPath [ "ocserv" "enable" ] false jsonData;
    };
    resticPassword = lib.attrsets.attrByPath [ "resticPassword" ] null jsonData;
    ssh = {
      enable = lib.attrsets.attrByPath [ "ssh" "enable" ] true jsonData;
      rootKeys = lib.attrsets.attrByPath [ "ssh" "rootKeys" ] [ "" ] jsonData;
      passwordAuthentication = lib.attrsets.attrByPath [ "ssh" "passwordAuthentication" ] true jsonData;
    };
    users = lib.attrsets.attrByPath [ "users" ] [] jsonData;
  };
}
