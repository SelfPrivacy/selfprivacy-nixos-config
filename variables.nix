{ pkgs, lib, ... }:
let
  jsonData = builtins.fromJSON (builtins.readFile ./userdata/userdata.json);
in
{
  services.userdata = {
    hostname = lib.attrsets.attrByPath [ "hostname" ] null jsonData;
    domain = lib.attrsets.attrByPath [ "domain" ] null jsonData;
    timezone = lib.attrsets.attrByPath [ "timezone" ] "Europe/Uzhgorod" jsonData;
    stateVersion = lib.attrsets.attrByPath [ "stateVersion" ] "22.05" jsonData;
    autoUpgrade = {
      enable = lib.attrsets.attrByPath [ "autoUpgrade" "enable" ] true jsonData;
      allowReboot = lib.attrsets.attrByPath [ "autoUpgrade" "allowReboot" ] true jsonData;
    };
    username = lib.attrsets.attrByPath [ "username" ] null jsonData;
    hashedMasterPassword = lib.attrsets.attrByPath [ "hashedMasterPassword" ] null jsonData;
    sshKeys = lib.attrsets.attrByPath [ "sshKeys" ] [ ] jsonData;
    api = {
      enableSwagger = lib.attrsets.attrByPath [ "api" "enableSwagger" ] false jsonData;
      skippedMigrations = lib.attrsets.attrByPath [ "api" "skippedMigrations" ] [ ] jsonData;
    };
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
    bitwarden = {
      enable = lib.attrsets.attrByPath [ "bitwarden" "enable" ] false jsonData;
      location = lib.attrsets.attrByPath [ "bitwarden" "location" ] "sda1" jsonData;
    };
    gitea = {
      enable = lib.attrsets.attrByPath [ "gitea" "enable" ] false jsonData;
      location = lib.attrsets.attrByPath [ "gitea" "location" ] "sda1" jsonData;
    };
    nextcloud = {
      enable = lib.attrsets.attrByPath [ "nextcloud" "enable" ] false jsonData;
      location = lib.attrsets.attrByPath [ "nextcloud" "location" ] "sda1" jsonData;
    };
    pleroma = {
      enable = lib.attrsets.attrByPath [ "pleroma" "enable" ] false jsonData;
      location = lib.attrsets.attrByPath [ "pleroma" "location" ] "sda1" jsonData;
    };
    jitsi = {
      enable = lib.attrsets.attrByPath [ "jitsi" "enable" ] false jsonData;
    };
    ocserv = {
      enable = lib.attrsets.attrByPath [ "ocserv" "enable" ] false jsonData;
    };
    mastodon = {
      enable = lib.attrsets.attrByPath [ "mastodon" "enable" ] false jsonData;
      location = lib.attrsets.attrByPath [ "mastodon" "location" ] "sda1" jsonData;
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
    useBinds = lib.attrsets.attrByPath [ "useBinds" ] false jsonData;
  };
}
