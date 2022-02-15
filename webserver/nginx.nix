{ pkgs, config, lib, ... }:
let
  domain = config.services.userdata.domain;
in
{
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    sslProtocols = lib.mkForce "TLSv1.2 TLSv1.3";
    sslCiphers = lib.mkForce "ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:!SHA1:!SHA256:!SHA384:!DSS:!aNULL";
    clientMaxBodySize = "1024m";
    commonHttpConfig = ''
      map $scheme $hsts_header {
          https   "max-age=31536000; includeSubdomains; preload";
      }
    '';

    virtualHosts = {
      "${domain}" = {
        sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${domain}/key.pem";
        forceSSL = true;
        extraConfig = ''
          add_header Strict-Transport-Security $hsts_header;
          #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;
          add_header 'Referrer-Policy' 'origin-when-cross-origin';
          add_header X-Frame-Options DENY;
          add_header X-Content-Type-Options nosniff;
          add_header X-XSS-Protection "1; mode=block";
          proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
          expires 10m;
        '';
      };
      "vpn.${domain}" = {
        sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${domain}/key.pem";
        forceSSL = true;
        extraConfig = ''
          add_header Strict-Transport-Security $hsts_header;
          #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;
          add_header 'Referrer-Policy' 'origin-when-cross-origin';
          add_header X-Frame-Options DENY;
          add_header X-Content-Type-Options nosniff;
          add_header X-XSS-Protection "1; mode=block";
          proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
          expires 10m;
        '';
      };
      "git.${domain}" = {
        sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${domain}/key.pem";
        forceSSL = true;
        extraConfig = ''
          add_header Strict-Transport-Security $hsts_header;
          #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;
          add_header 'Referrer-Policy' 'origin-when-cross-origin';
          add_header X-Frame-Options DENY;
          add_header X-Content-Type-Options nosniff;
          add_header X-XSS-Protection "1; mode=block";
          proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
          expires 10m;
        '';
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
        extraConfig = ''
          add_header Strict-Transport-Security $hsts_header;
          #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;
          add_header 'Referrer-Policy' 'origin-when-cross-origin';
          add_header X-Frame-Options DENY;
          add_header X-Content-Type-Options nosniff;
          add_header X-XSS-Protection "1; mode=block";
          proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
          expires 10m;
        '';
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
          add_header Strict-Transport-Security $hsts_header;
          #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;
          add_header 'Referrer-Policy' 'origin-when-cross-origin';
          add_header X-Frame-Options DENY;
          add_header X-Content-Type-Options nosniff;
          add_header X-XSS-Protection "1; mode=block";
          proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
          expires 10m;
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
        extraConfig = ''
          add_header Strict-Transport-Security $hsts_header;
          #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;
          add_header 'Referrer-Policy' 'origin-when-cross-origin';
          add_header X-Frame-Options DENY;
          add_header X-Content-Type-Options nosniff;
          add_header X-XSS-Protection "1; mode=block";
          proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
          expires 10m;
        '';
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
        extraConfig = ''
          add_header Strict-Transport-Security $hsts_header;
          #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;
          add_header 'Referrer-Policy' 'origin-when-cross-origin';
          add_header X-Frame-Options DENY;
          add_header X-Content-Type-Options nosniff;
          add_header X-XSS-Protection "1; mode=block";
          proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
          expires 10m;
        '';
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
        extraConfig = ''
          add_header Strict-Transport-Security $hsts_header;
          #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;
          add_header 'Referrer-Policy' 'origin-when-cross-origin';
          add_header X-Frame-Options DENY;
          add_header X-Content-Type-Options nosniff;
          add_header X-XSS-Protection "1; mode=block";
          proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
          expires 10m;
        '';
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:4000";
          };
        };
      };
    };
  };
}
