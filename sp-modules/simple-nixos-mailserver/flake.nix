{
  description = "PoC SP module for the simple-nixos-mailserver";

  inputs.mailserver.url =
    gitlab:simple-nixos-mailserver/nixos-mailserver;

  outputs = { self, mailserver }: {
    nixosModules.default = _: {
      imports = [
        mailserver.nixosModules.default
        ./options.nix
        ./config.nix
        ./auth-postfix.nix
        ./auth-dovecot.nix
      ];
    };
    configPathsNeeded =
      builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
    meta = { lib, ... }: {
      spModuleSchemaVersion = 1;
      id = "simple-nixos-mailserver";
      name = "Mail Server";
      description = "E-Mail for company and family.";
      svgIcon = builtins.readFile ./icon.svg;
      isMovable = true;
      isRequired = true;
      canBeBackedUp = true;
      backupDescription = "Mail boxes and filters.";
      systemdServices = [
        "dovecot2.service"
        "postfix.service"
      ];
      user = "virtualMail";
      folders = [
        "/var/vmail"
        "/var/sieve"
      ];
      supportLevel = "normal";
    };

    # TODO generate json docs from module? something like:
    # nix eval --impure --expr 'let flake = builtins.getFlake (builtins.toPath ./.); pkgs = flake.inputs.mailserver.inputs.nixpkgs.legacyPackages.x86_64-linux; in (pkgs.nixosOptionsDoc { inherit (pkgs.lib.evalModules { modules = [ flake.nixosModules.default ]; }) options; }).optionsJSON'
    # (doesn't work because of `assertions`)
  };
}
