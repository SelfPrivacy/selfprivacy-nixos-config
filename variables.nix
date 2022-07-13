{ pkgs, ... }:
let
  jsonData = builtins.fromJSON (builtins.readFile ./userdata/userdata.json);
in
{
  services.userdata = {
    hostname = jsonData.hostname;
    domain = jsonData.domain;
    timezone = jsonData.timezone;
    autoUpgrade = {
      enable = jsonData.autoUpgrade.enable;
      allowReboot = jsonData.autoUpgrade.allowReboot;
    };
    username = jsonData.username;
    hashedMasterPassword = jsonData.hashedMasterPassword;
    sshKeys = jsonData.sshKeys;
    api = {
      token = jsonData.api.token;
      enableSwagger = jsonData.api.enableSwagger;
      skippedMigrations = jsonData.api.skippedMigrations;
    };
    backblaze = {
      bucket = jsonData.backblaze.bucket;
      accountId = jsonData.backblaze.accountId;
      accountKey = jsonData.backblaze.accountKey;
    };
    cloudflare = {
      apiKey = jsonData.cloudflare.apiKey;
    };
    databasePassword = jsonData.databasePassword;
    bitwarden = {
      enable = jsonData.bitwarden.enable;
    };
    gitea = {
      enable = jsonData.gitea.enable;
    };
    nextcloud = {
      enable = jsonData.nextcloud.enable;
      adminPassword = jsonData.nextcloud.adminPassword;
    };
    pleroma = {
      enable = jsonData.pleroma.enable;
    };
    jitsi = {
      enable = jsonData.jitsi.enable;
    };
    ocserv = {
      enable = jsonData.ocserv.enable;
    };
    resticPassword = jsonData.resticPassword;
    ssh = {
      enable = jsonData.ssh.enable;
      rootKeys = jsonData.ssh.rootKeys;
      passwordAuthentication = jsonData.ssh.passwordAuthentication;
    };
    users = jsonData.users;
  };
}
