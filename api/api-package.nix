{ nixpkgs ? import <nixpkgs> { }, pythonPkgs ? nixpkgs.pkgs.python39Packages }:

let
  inherit (nixpkgs) pkgs;
  inherit pythonPkgs;

  selfprivacy-api = { buildPythonPackage, flask, flask-restful, setuptools, portalocker, flask-swagger, flask-swagger-ui }:
    buildPythonPackage rec {
      pname = "selfprivacy-api";
      version = "1.1";
      src = builtins.fetchGit {
        url = "https://git.selfprivacy.org/ilchub/selfprivacy-rest-api.git";
        rev = "dbb4c1095654bba88d4f0c91b7b195d5262976b6";
      };
      propagatedBuildInputs = [ flask flask-restful setuptools portalocker flask-swagger flask-swagger-ui ];
      meta = {
        description = ''
          SelfPrivacy Server Management API
        '';
      };
    };
  drv = pythonPkgs.callPackage selfprivacy-api { };
in
if pkgs.lib.inNixShell then drv.env else drv
