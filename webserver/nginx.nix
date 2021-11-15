{ pkgs, config, ... }:
let
  domain = config.services.userdata.domain;
in
{
  services.nginx = {
    enable = true;
    enableReload = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    clientMaxBodySize = "1024m";

    virtualHosts = {
      "${domain}" = {
        sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${domain}/key.pem";
        forceSSL = true;
      };
      "vpn.${domain}" = {
        sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${domain}/key.pem";
        forceSSL = true;
      };
      "git.${domain}" = {
        sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${domain}/key.pem";
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:3000";
          };
        };
      };
      "cloud.${domain}" = {
        sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${domain}/key.pem";
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:80/";
          };
        };
      };
      "meet.${domain}" = {
        forceSSL = true;
        sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${domain}/key.pem";
        root = pkgs.jitsi-meet;
        extraConfig = ''
          ssi on;
        '';
        locations = {
          "@root_path" = {
            extraConfig = ''
              rewrite ^/(.*)$ / break;
            '';
          };
          "~ ^/([^/\\?&:'\"]+)$" = {
            tryFiles = "$uri @root_path";
          };
          "=/http-bind" = {
            proxyPass = "http://localhost:5280/http-bind";
            extraConfig = ''
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header Host $host;
            '';
          };
          "=/external_api.js" = {
            alias = "${pkgs.jitsi-meet}/libs/external_api.min.js";
          };
          "=/config.js" = {
            alias = "${pkgs.jitsi-meet}/config.js";
          };
          "=/interface_config.js" = {
            alias = "${pkgs.jitsi-meet}/interface_config.js";
          };
        };
      };
      "password.${domain}" = {
        sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${domain}/key.pem";
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:8222";
          };
        };
      };
      "api.${domain}" = {
        sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${domain}/key.pem";
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:5050";
          };
        };
      };
      "social.${domain}" = {
        sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${domain}/key.pem";
        root = "/var/www/social.${domain}";
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:4000";
          };
        };
        extraConfig = ''
          client_max_body_size 1024m;
        '';
      };
    };
  };
}
