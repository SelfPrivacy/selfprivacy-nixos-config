system: final: prev: {
  # Here is a template to bring a specific package from a given nixpkgs commit:
  #   PACKAGE_NAME = (builtins.getFlake "github:nixos/nixpkgs/NIXPKGS_COMMIT_SHA1").legacyPackages.${system}.PACKAGE_NAME;
  # Substitute `PACKAGE_NAME` and `NIXPKGS_COMMIT_SHA1` accordingly.
  # If a package already exists it is overlaid (previous one gets inaccessible).
  # roundcube CVE fix example (from nixpkgs PR (https://github.com/NixOS/nixpkgs/pull/332654)):
  #   roundcube = (builtins.getFlake "github:nixos/nixpkgs/9e2f16514b23963621325d93920c9f896ec54ca3").legacyPackages.${system}.roundcube;
  # Security releases from https://github.com/NixOS/nixpkgs/pull/576853.
  php84 =
    let
      php = prev.php84.override {
        version = "8.4.27";
        hash = "sha256-slMKh3xyL0sIyeF0owywi6wrfhkD7m6eMV8KqfX4LCQ=";
      };
      patchedFilter = php.extensions.filter.overrideAttrs (old: {
        postConfigure = (old.postConfigure or "") + ''
          substituteInPlace \
            tests/oom_filter_input.phpt \
            tests/oom_filter_input_array.phpt \
            tests/oom_filter_default_encoded.phpt \
            --replace-fail "'-n'," "'-n', '-d', 'extension=$PWD/modules/filter.so',"
        '';
      });
    in
    php.withExtensions (
      { enabled, ... }:
      builtins.filter (extension: extension.extensionName != "filter") enabled ++ [ patchedFilter ]
    );
  php = final.php84;
}
