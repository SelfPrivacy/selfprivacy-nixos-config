{
  selfprivacy,
  ...
}:
{
  # embed top-level flake source folder into the build
  environment.etc."selfprivacy/nixos-config-source".source = selfprivacy.topLevelFlake;

  # embed commit sha1 for `nixos-version --configuration-revision`
  system.configurationRevision =
    selfprivacy.config.source.rev or "@${selfprivacy.config.source.lastModifiedDate}"; # for development

  nix = {
    registry.nixpkgs.flake = selfprivacy.config.inputs.nixpkgs;
    channel.enable = false;
    gc = {
      automatic = true; # TODO it's debatable, because of IO&CPU load
      options = "--delete-older-than 7d";
    };

    settings = {
      sandbox = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      allowed-users = [
        "root"
      ];
      substituters = [
        "https://cache.selfprivacy.org/nixos"
      ];
      trusted-public-keys = [
        # nixos is not cache.nixos.org. it's attic cache name on cache.selfprivacy.org
        "nixos:XI4AhGwIOTvDIfKg8fr4p6PfVRske/5kHluWnc9cvfs="
      ];

      # TODO(nhnn): Why this was false before?
      allow-dirty = true;
    };
  };
}
