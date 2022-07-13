{ pkgs, ... }:
let
  jsonData = builtins.fromJSON (builtins.readFile ./userdata/userdata.json);
in
{
  services.userdata = {
    hostname = (if jsonData ? "hostname" then jsonData.hostname else null);
    domain = (if jsonData ? "domain" then jsonData.domain else null);
    timezone = (if jsonData ? "timezone" then jsonData.timezone else "Europe/Uzhgorod");
    autoUpgrade = {
      enable = (
        if (jsonData ? "autoUpgrade" && jsonData.autoUpgrade ? "enable")
        then jsonData.autoUpgrade.enable
        else true
      );
      allowReboot = (
        if (jsonData ? "autoUpgrade" && jsonData.autoUpgrade ? "allowReboot")
        then jsonData.autoUpgrade.allowReboot
        else true
      );
    };
    username = (if jsonData ? "username" then jsonData.username else null);
    hashedMasterPassword = (if jsonData ? "hashedMasterPassword" then jsonData.hashedMasterPassword else null);
    sshKeys = (if jsonData ? "sshKeys" then jsonData.sshKeys else [ ]);
    api = {
      token = jsonData.api.token;
      enableSwagger = (
        if (jsonData ? "api" && jsonData.api "enableSwagger")
        then jsonData.api.enableSwagger
        else false
      );
      skippedMigrations = (
        if (jsonData ? "api" && jsonData.api ? "skippedMigrations")
        then jsonData.api.skippedMigrations
        else [ ]
      );
    };
    backblaze = {
      bucket = (
        if (jsonData ? "backblaze" && jsonData.backblaze ? "bucket")
        then jsonData.backblaze.bucket
        else ""
      );
      accountId = (
        if (jsonData ? "backblaze" && jsonData.backblaze ? "accountId")
        then jsonData.backblaze.accountId
        else ""
      );
      accountKey = (
        if (jsonData ? "backblaze" && jsonData.backblaze ? "accountKey")
        then jsonData.backblaze.accountKey
        else ""
      );
    };
    cloudflare = {
      apiKey = (
        if (jsonData ? "cloudflare" && jsonData.cloudflare ? "apiKey")
        then jsonData.cloudflare.apiKey
        else null
      );
    };
    databasePassword = (if jsonData ? "databasePassword" then jsonData.databasePassword else null);
    bitwarden = {
      enable = (
        if (jsonData ? "bitwarden" && jsonData.bitwarden ? "enable")
        then jsonData.bitwarden.enable
        else false
      );
    };
    gitea = {
      enable = (
        if (jsonData ? "gitea" && jsonData.gitea ? "enable")
        then jsonData.gitea.enable
        else false
      );
    };
    nextcloud = {
      enable = (
        if (jsonData ? "nextcloud" && jsonData.nextcloud ? "enable")
        then jsonData.nextcloud.enable
        else false
      );
      adminPassword = (
        if (jsonData ? "nextcloud" && jsonData.nextcloud ? "adminPassword")
        then jsonData.nextcloud.adminPassword
        else null
      );
    };
    pleroma = {
      enable = (
        if (jsonData ? "pleroma" && jsonData.pleroma ? "enable")
        then jsonData.pleroma.enable
        else false
      );
    };
    jitsi = {
      enable = (
        if (jsonData ? "jitsi" && jsonData.jitsi ? "enable")
        then jsonData.jitsi.enable
        else false
      );
    };
    ocserv = {
      enable = (
        if (jsonData ? "ocserv" && jsonData.ocserv ? "enable")
        then jsonData.ocserv.enable
        else false
      );
    };
    resticPassword = (if jsonData ? "resticPassword" then jsonData.resticPassword else null);
    ssh = {
      enable = (
        if (jsonData ? "ssh" && jsonData.ssh ? "enable")
        then jsonData.ssh.enable
        else true
      );
      rootKeys = (
        if (jsonData ? "ssh" && jsonData.ssh ? "rootKeys")
        then jsonData.ssh.rootKeys
        else [ "" ]
      );
      passwordAuthentication = (
        if (jsonData ? "ssh" && jsonData.ssh ? "passwordAuthentication")
        then jsonData.ssh.passwordAuthentication
        else true
      );
    };
    users = (if jsonData ? "users" then jsonData.users else [ ]);
  };
}
