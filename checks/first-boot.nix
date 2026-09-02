{
  inputs,
  nixpkgs,
  self,
  system,
  testHooks ? { },
}:
let
  lib = nixpkgs.lib;
  pkgs = nixpkgs.legacyPackages.${system};

  testLib = import ../lib/nixos-test.nix { inherit inputs nixpkgs self; };

  domain = "example.test";
  acmeIp = "10.20.30.2";
  targetIp = "10.20.30.3";

  tsigSecret = "YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXo="; # base64 of abcdefghijklmnopqrstuvwxyz

  testCertificates = ./test-ca;

  zoneFile = pkgs.writeText "${domain}.zone" ''
    $TTL 60
    $ORIGIN ${domain}.
    @ IN SOA ns.${domain}. hostmaster.${domain}. ( 1 60 60 60 60 )
    @ IN NS ns.${domain}.
    ns IN A ${acmeIp}
    @ IN A ${targetIp}
    @ IN MX 10 ${domain}.
    * IN A 127.0.0.1
  '';

  selfprivacyZoneFile = pkgs.writeText "selfprivacy.org.zone" ''
    $TTL 60
    $ORIGIN selfprivacy.org.
    @ IN SOA ns.selfprivacy.org. hostmaster.selfprivacy.org. ( 1 60 60 60 60 )
    @ IN NS ns.selfprivacy.org.
    ns IN A ${acmeIp}
    git IN A ${acmeIp}
  '';

  rfc2136Environment = pkgs.writeText "rfc2136.env" ''
    RFC2136_NAMESERVER=${acmeIp}:53
    RFC2136_TSIG_KEY=acme-key
    RFC2136_TSIG_SECRET=${tsigSecret}
    RFC2136_TSIG_ALGORITHM=hmac-sha256.
  '';

  acmeModule =
    { ... }:
    {
      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = acmeIp;
          prefixLength = 24;
        }
      ];
      networking.firewall.allowedTCPPorts = [
        53
        443
        8443
      ];
      networking.firewall.allowedUDPPorts = [ 53 ];
      networking.nameservers = lib.mkForce [ acmeIp ];

      environment.etc."selfprivacy/secrets.json".text = builtins.toJSON {
        dns.token = tsigSecret;
      };

      services.bind = {
        enable = true;
        checkConfig = false;
        cacheNetworks = [ "10.20.30.0/24" ];
        forwarders = [ ];
        extraOptions = ''
          empty-zones-enable no;
          recursion no;
        '';
        extraConfig = ''
          key "acme-key" {
            algorithm hmac-sha256;
            secret "${tsigSecret}";
          };
        '';
        zones = [
          {
            name = domain;
            master = true;
            file = "/var/lib/bind/${domain}.zone";
            extraConfig = ''
              allow-update { key "acme-key"; };
            '';
          }
          {
            name = "selfprivacy.org";
            master = true;
            file = "/var/lib/bind/selfprivacy.org.zone";
          }
        ];
      };
      systemd.tmpfiles.rules = [
        "d /var/lib/bind 0750 named named - -"
        "C /var/lib/bind/${domain}.zone 0640 named named - ${zoneFile}"
        "C /var/lib/bind/selfprivacy.org.zone 0640 named named - ${selfprivacyZoneFile}"
      ];

      # Caddy is a bit easier to setup than NixOS ACME + NGINX
      services.caddy = {
        enable = true;
        virtualHosts."git.selfprivacy.org".extraConfig = ''
          tls {
            issuer acme {
              dir https://acme:8443/acme/acme/directory
              trusted_roots ${testCertificates}/root_ca.crt
              disable_http_challenge
            }
          }

          @modules path /api/v1/repos/SelfPrivacy/selfprivacy-nixos-config/contents/sp-modules
          header @modules Content-Type application/json
          respond @modules "[]" 200
          respond 404
        '';
      };
      systemd.services.caddy = {
        after = [
          "bind.service"
          "step-ca.service"
        ];
        requires = [
          "bind.service"
          "step-ca.service"
        ];
      };

      services.step-ca = {
        enable = true;
        address = acmeIp;
        port = 8443;
        settings = {
          dnsNames = [
            "acme"
            "localhost"
          ];
          root = "${testCertificates}/root_ca.crt";
          crt = "${testCertificates}/intermediate_ca.crt";
          key = "${testCertificates}/intermediate_ca.key";
          db = {
            type = "badger";
            dataSource = "/var/lib/step-ca/db";
          };
          authority.provisioners = [
            {
              type = "ACME";
              name = "acme";
            }
          ];
        };
      };
    };

  systemParts = testLib.mkTestSystem {
    inherit system;
    spModules = testHooks.spModules or testLib.baseSpModules;
    userdata = testLib.mkTestUserdata (
      {
        modules.nextcloud.enable = false;
        domain = domain;
        hostname = "first-boot";
      }
      // (testHooks.userdataOverrides or { })
    );
    extraModules = [
      (
        { config, ... }:
        {
          networking.nameservers = lib.mkForce [ acmeIp ];
          networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
            {
              address = targetIp;
              prefixLength = 24;
            }
          ];
          environment.etc."selfprivacy/secrets.json".text = builtins.toJSON {
            api.token = "insecure-test-api-token";
            dns.token = tsigSecret;
          };

          # https://git.selfprivacy.org/SelfPrivacy/selfprivacy-rest-api/pulls/288
          systemd.services.selfprivacy-api.environment.SSL_CERT_FILE = config.security.pki.caBundle;
          systemd.services.selfprivacy-api-worker.environment.SSL_CERT_FILE = config.security.pki.caBundle;

          environment.systemPackages = [ pkgs.curl ]; # for tests
          networking.extraHosts = "${acmeIp} acme";
          networking.firewall.allowedTCPPorts = [ 80 ];
          security.pki.certificateFiles = [ "${testCertificates}/root_ca.crt" ];
          mailserver.ldap.caFile = lib.mkForce config.security.pki.caBundle;
          security.acme = {
            defaults = {
              server = lib.mkForce "https://acme:8443/acme/acme/directory";
              dnsResolver = lib.mkForce "${acmeIp}:53";
            };
            certs.${domain} = {
              dnsProvider = lib.mkForce "rfc2136";
              environmentFile = lib.mkForce rfc2136Environment;
              dnsPropagationCheck = lib.mkForce false;
            };
            certs."root-${domain}".webroot = lib.mkForce "/var/lib/acme/acme-challenge";
          };
        }
      )
    ]
    ++ (testHooks.extraModules or [ ]);
  };
in
pkgs.testers.runNixOSTest {
  name = "selfprivacy-first-boot";

  node.specialArgs = systemParts.specialArgs;
  node.pkgsReadOnly = false;

  nodes.acme = {
    imports = [ acmeModule ];
  };

  nodes.machine = {
    imports = systemParts.modules;
  };

  testScript = ''
    import json

    def wait_for_https(subdomain, path="/"):
      return machine.wait_until_succeeds(
        f"curl --fail --silent --show-error --cacert ${testCertificates}/root_ca.crt https://{subdomain}.${domain}{path}",
        timeout=120,
      )

    acme.start()
    acme.wait_for_unit("bind.service")
    acme.wait_for_unit("step-ca.service")
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("nginx.service")
    machine.wait_until_succeeds("curl --fail --silent --show-error --cacert ${testCertificates}/root_ca.crt https://auth.${domain}/", timeout=120)
    machine.wait_until_succeeds("curl --fail --silent --show-error --cacert ${testCertificates}/root_ca.crt https://api.${domain}/api/version", timeout=120)

    graphql_response = json.loads(machine.succeed(
      """token="$(sp-print-api-token)"
      test -n "$token"
      curl --fail --silent --show-error \
        --cacert ${testCertificates}/root_ca.crt \
        --header "Authorization: Bearer $token" \
        --json '{"query":"query { api { devices { name isCaller } } system { domainInfo { domain hostname provider } settings { timezone } } }"}' \
        https://api.${domain}/graphql
      """
    ))
    assert "errors" not in graphql_response, graphql_response
    assert any(device["isCaller"] for device in graphql_response["data"]["api"]["devices"]), graphql_response
    domain_info = graphql_response["data"]["system"]["domainInfo"]
    assert domain_info == {
      "domain": "${domain}",
      "hostname": "first-boot",
      "provider": "CLOUDFLARE",
    }, graphql_response
    assert graphql_response["data"]["system"]["settings"]["timezone"] == "Etc/UTC", graphql_response

    ${testHooks.testScript or ""}

    for node in machines:
      failed_units = node.succeed("systemctl list-units --failed --no-legend --plain")
      assert not failed_units.strip(), f"Failed systemd units on {node.name}:\n{failed_units}"
  '';
}
