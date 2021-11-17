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
        rev = "82b7f97dcece9b879c19e32c95daafeaae0091ec";
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
