{ lib, fetchgit, buildGoModule, ... }:
buildGoModule rec {
  pname = "alps";
  version = "v1.0.0"; # latest available tag at the moment

  src = fetchGit {
    url = "https://git.selfprivacy.org/ilchub/selfprivacy-alps";
    rev = "dc2109ca2fdabfbda5d924faa4947f5694d5d758";
  };

  vendorSha256 = "0bqg0qjam4mvh07wfil6l5spz32mk5a7kfxxnwfyva805pzmn6dk";

  deleteVendor = false;
  runVend = true;

  buildPhase = ''
    go build ./cmd/alps
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp -r * $out/bin
  '';

  meta = with lib; {
    description = "Webmail application for the dovecot/postfix mailserver";
    homepage = "https://git.selfprivacy.org/ilchub/selfprivacy-alps";
    license = licenses.mit;
  };
}
