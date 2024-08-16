system:
_final: _prev:
{
  # Here is a template to bring a specific package from a given nixpkgs commit:
  #   PACKAGE_NAME = (builtins.getFlake "github:nixos/nixpkgs/NIXPKGS_COMMIT_SHA1").legacyPackages.${system}.PACKAGE_NAME;
  # Substitute `PACKAGE_NAME` and `NIXPKGS_COMMIT_SHA1` accordingly.
  # If a package already exists it is overlaid (previous one gets inaccessible).
  # roundcube CVE fix example (from nixpkgs PR (https://github.com/NixOS/nixpkgs/pull/332654)):
  #   roundcube = (builtins.getFlake "github:nixos/nixpkgs/9e2f16514b23963621325d93920c9f896ec54ca3").legacyPackages.${system}.roundcube;
}
