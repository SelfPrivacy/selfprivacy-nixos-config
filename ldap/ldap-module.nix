{ config, pkgs, lib, ... }:
let
  cfg = config.selfprivacy.ldap;
  domain = lib.concatMapStringsSep "," (x: "dc=${x}") (lib.splitString "." cfg.domain);
  openssh-ldap-publickey = pkgs.fetchFromGitHub {
    owner = "AndriiGrytsenko";
    repo = "openssh-ldap-publickey";
    rev = "v1.0.2";
    hash = "sha256-Citukp6dQrmFUGFTRSXAhoUpjKUlEvkAOffx2/P5Gag=";
  };
in
{
  options = {
    selfprivacy.ldap = {
      enable = lib.mkEnableOption (lib.mdDoc "LDAP integration");
      domain = lib.mkOption {
        type = lib.types.str;
        example = "example.com";
        description = ''
          LDAP domain.
        '';
      };
      rootUser = lib.mkOption {
        type = lib.types.str;
        default = "root";
        description = lib.mdDoc ''
          LDAP root user.
        '';
      };
      rootHashedPassword = lib.mkOption {
        type = lib.types.passwdEntry lib.types.str;
        description = lib.mdDoc ''
          LDAP root user hashed password.
        '';
      };
      users = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            username = lib.mkOption {
              type = lib.types.passwdEntry lib.types.str;
              example = "john";
              description = lib.mdDoc ''
                User's username.
              '';
            };
            hashedPassword = lib.mkOption {
              type = lib.types.passwdEntry lib.types.str;
              description = lib.mdDoc ''
                Specifies the hashed password for the user.
              '';
            };
            sshKeys = lib.mkOption {
              type = lib.types.listOf lib.types.singleLineStr;
              default = [ ];
              description = lib.mdDoc ''
                A list of user's OpenSSH public keys.
              '';
            };
            email = lib.mkOption {
              type = lib.types.str;
              example = "john@example.com";
              description = lib.mdDoc ''
                User email for LDAP.
              '';
            };
            displayName = lib.mkOption {
              type = lib.types.str;
              example = "John Doe";
              default = "";
              description = lib.mdDoc ''
                Display name for LDAP.
              '';
            };
            firstName = lib.mkOption {
              type = lib.types.str;
              example = "John";
              default = "";
              description = lib.mdDoc ''
                User's first name for LDAP.
              '';
            };
            lastName = lib.mkOption {
              type = lib.types.str;
              example = "Doe";
              default = "";
              description = lib.mdDoc ''
                User's last name for LDAP.
              '';
            };
            jpegPhoto = lib.mkOption {
              type = lib.types.nullOr lib.types.singleLineStr;
              default = null;
              description = lib.mdDoc ''
                A jpegPhoto attribute for LDAP, base64-encoded.
              '';
            };
            groups = lib.mkOption {
              type = lib.types.listOf (lib.types.enum [
                "admin"
                "gitea"
                "nextcloud"
                "pleroma"
                "mastodon"
              ]);
              example = [ "gitea" ];
              default = [ ];
              description = lib.mdDoc ''
                Which services the user is allowed to use.
              '';
            };
          };
        });
        default = [ ];
        description = lib.mdDoc ''
          List of LDAP users.
        '';
      };
    };
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.openldap =
        let
          filterUsers = group: users: lib.filter
            (user: builtins.elem group user.groups)
            users;
          mkUser = usersNamespace: user: lib.concatStringsSep "\n" ([
            "dn: uid=${user.username},ou=${usersNamespace},${domain}"
            "objectClass: inetOrgPerson"
            "objectClass: shadowAccount"
          ] ++ lib.optionals (user.sshKeys != [ ]) [
            "objectClass: ldapPublicKey"
          ] ++ lib.optionals (user.jpegPhoto != null) [
            "jpegPhoto:: ${user.jpegPhoto}"
          ] ++ (map (key: "sshPublicKey: ${key}") user.sshKeys)
          ++ [
            "mail: ${user.email}"
            "displayName: ${user.displayName}"
            "cn: ${user.firstName}"
            "sn: ${user.lastName}"
            "userPassword: {crypt}${user.hashedPassword}"
          ]);
          mkGroup = usersNamespace: users: group:
            let
              groupUsers = (filterUsers group users);
            in
            lib.optionalString (groupUsers != [ ]) ''
              dn: cn=${group},ou=groups,${domain}
              objectClass: groupOfNames
              ${lib.concatMapStringsSep
                "\n"
                (user: "member: uid=${user.username},ou=${usersNamespace},${domain}")
                groupUsers
              }
            '';
          mkUsersNamespace = usersNamespace: users: ''
            dn: ou=${usersNamespace},${domain}
            objectClass: organizationalUnit

            ${lib.concatMapStringsSep "\n\n" (mkUser usersNamespace) users}
          '';
          mkGroupsNamespace = usersNamespace: users: groupsNamespace: groups: ''
            dn: ou=${groupsNamespace},${domain}
            objectClass: organizationalUnit

            ${lib.concatMapStringsSep "\n\n" (mkGroup usersNamespace users) groups}
          '';
        in
        {
          enable = true;
          urlList = [ "ldap://localhost:389" ];
          declarativeContents."${domain}" = ''
            dn: ${domain}
            objectClass: domain

            ${mkUsersNamespace "users" cfg.users}

            # Make a root user for some services to bind
            dn: uid=root,ou=users,${domain}
            objectClass: inetOrgPerson
            cn: root
            sn: root
            mail: root@${domain}
            # Password is "root"
            userPassword: {crypt}$6$teiD8ySLE58taSvY$veZS9QRSmfBcox2JfgYH/AWv24cpHD4P7IUzFv8WgxUaio.j7Y4aqMcC4a17v3PvOdCu8vgkKAtu/jhhKjVQm0


            ${mkGroupsNamespace "users" cfg.users "groups" [
              "admin"
              "gitea"
              "nextcloud"
              "mastodon"
            ]}

            # pleroma has no support for ldap filters
            # so we just put pleroma users under separate namespace
            # https://git.pleroma.social/pleroma/pleroma/-/issues/1645
            ${mkUsersNamespace "pleroma" (filterUsers "pleroma" cfg.users)}
          '';
          settings = {
            children = {
              "cn=schema".includes = [
                "${pkgs.openldap}/etc/schema/core.ldif"
                "${pkgs.openldap}/etc/schema/cosine.ldif"
                "${pkgs.openldap}/etc/schema/dyngroup.ldif"
                "${pkgs.openldap}/etc/schema/inetorgperson.ldif"
                "${pkgs.openldap}/etc/schema/nis.ldif"
                "${openssh-ldap-publickey}/misc/openssh-lpk-openldap.ldif"
              ];
              "cn=modules" = {
                attrs = {
                  objectClass = [ "olcModuleList" ];
                  olcModuleLoad = "dynlist";
                };
              };
              "olcDatabase={0}config" = {
                attrs = {
                  objectClass = [ "olcDatabaseConfig" ];
                  olcDatabase = "{0}config";
                  olcRootDN = "cn=${cfg.rootUser},cn=config";
                  olcRootPW = "{crypt}${cfg.rootHashedPassword}";
                };
              };
              "olcDatabase={1}mdb" = {
                attrs = {
                  objectClass = [ "olcDatabaseConfig" "olcMdbConfig" ];
                  olcDatabase = "{1}mdb";
                  olcDbDirectory = "/var/lib/openldap/db";
                  olcSuffix = "${domain}";
                  olcRootDN = "cn=${cfg.rootUser},${domain}";
                  olcRootPW = "{crypt}${cfg.rootHashedPassword}";
                };
              };
              "olcOverlay=dynlist,olcDatabase={1}mdb" = {
                attrs = {
                  objectClass = [ "olcOverlayConfig" "olcDynListConfig" ];
                  olcDynListAttrSet = "groupOfURLs memberURL member+memberOf@groupOfNames";
                };
              };
            };
          };
        };
    })
    (lib.mkIf config.services.gitea.enable {
      systemd.services.gitea.preStart = lib.mkAfter ''
        ldap_id=$(${config.services.gitea.package}/bin/gitea admin auth list | grep nixos-ldap | ${pkgs.gawk}/bin/awk '{ print $1 }' || true)

        ${lib.optionalString (!cfg.enable) ''
          if [ ! -z "$ldap_id" ]; then
            ${config.services.gitea.package}/bin/gitea admin auth update-ldap \
              --id $ldap_id \
              --not-active
          fi
        ''}

        ${lib.optionalString cfg.enable ''
          if [ -z "$ldap_id" ]; then
            auth_command="add-ldap"
          else
            auth_command="update-ldap --id $ldap_id"
          fi

          # https://docs.gitea.io/en-us/command-line/#admin
          ${config.services.gitea.package}/bin/gitea admin auth $auth_command \
            --name nixos-ldap \
            --security-protocol unencrypted \
            --host 127.0.0.1 \
            --port 389 \
            --bind-dn "${domain}" \
            --user-search-base "ou=users,${domain}" \
            --user-filter "(&(objectClass=shadowAccount)(memberOf=cn=gitea,ou=groups,${domain})(uid=%s))" \
            --admin-filter "(&(objectClass=shadowAccount)(memberOf=cn=admin,ou=groups,${domain}))" \
            --username-attribute uid \
            --email-attribute mail \
            --firstname-attribute cn \
            --surname-attribute sn \
            --avatar-attribute jpegPhoto \
            --public-ssh-key-attribute sshPublicKey \
            --synchronize-users
        ''}
      '';
    })
    (lib.mkIf config.services.nextcloud.enable {
      # No support for admins via LDAP yet:
      # https://github.com/nextcloud/server/issues/6428
      systemd.services.nextcloud-setup.script =
        let
          # https://docs.nextcloud.com/server/25/admin_manual/configuration_server/occ_command.html#ldap-commands
          # https://docs.nextcloud.com/server/25/admin_manual/configuration_user/user_auth_ldap_api.html#configuration-keys
          occAction = action: "nextcloud-occ --no-interaction ${action}";
          ldapAction = action: occAction "ldap:${action}";
          ldapConfigIdFile = lib.escapeShellArg "${config.services.nextcloud.datadir}/config/.ldap-nixos-config-id";
          ldapConfigAction = action: "${ldapAction action} $(<${ldapConfigIdFile})";
          ldapSetConfig = ldapConfigAction "set-config";
          ldapTestConfig = ldapConfigAction "test-config";
        in
        lib.mkAfter ''
          ${lib.optionalString (!cfg.enable) ''
            if [ -f ${ldapConfigIdFile} ]; then
              ${ldapSetConfig} ldapConfigurationActive 0
            fi
          ''}

          ${lib.optionalString cfg.enable ''
            if [ ! -f ${ldapConfigIdFile} ]; then
              ${occAction "app:enable"} user_ldap
              if ! ${ldapAction "create-empty-config"} --only-print-prefix > ${ldapConfigIdFile}; then
                rm ${ldapConfigIdFile}
                echo "Failed to create LDAP configuration"
                exit 1
              fi
            fi

            ${ldapSetConfig} ldapHost 127.0.0.1
            ${ldapSetConfig} ldapPort 389
            ${ldapSetConfig} ldapBase "${domain}"
            ${ldapSetConfig} ldapBaseUsers "ou=users,${domain}"
            ${ldapSetConfig} ldapUserFilter "(&(objectClass=shadowAccount)(memberOf=cn=nextcloud,ou=groups,${domain}))"
            ${ldapSetConfig} ldapLoginFilter "(&(objectClass=shadowAccount)(memberOf=cn=nextcloud,ou=groups,${domain})(uid=%uid))"
            ${ldapSetConfig} ldapExpertUsernameAttr uid
            ${ldapSetConfig} ldapEmailAttribute mail
            ${ldapSetConfig} ldapUserDisplayName displayName
            ${ldapSetConfig} ldapUserAvatarRule "data:jpegPhoto"

            if ${ldapTestConfig} | grep -q 'configuration is valid and the connection could be established'; then
              ${ldapSetConfig} ldapConfigurationActive 1
            else
              echo "LDAP configuration is invalid, disabling"
              ${ldapSetConfig} ldapConfigurationActive 0
            fi
          ''}
        '';
    })
    (lib.mkIf (config.services.mastodon.enable && cfg.enable) {
      services.mastodon.extraConfig = {
        LDAP_ENABLED = true;
        LDAP_HOST = "127.0.0.1";
        LDAP_PORT = 389;
        LDAP_BASE = "ou=users,${domain}";
        LDAP_BIND_DN = "uid=root,ou=users,${domain}";
        LDAP_BIND_PASSWORD = "root";
        LDAP_UID = "uid";
        LDAP_MAIL = "mail";
        LDAP_SEARCH_FILTER = "(&(objectClass=shadowAccount)(memberOf=cn=mastodon,ou=groups,${domain})(uid=%{username}))";
      };
    })
    (lib.mkIf (config.services.pleroma.enable && cfg.enable) {
      services.pleroma.configs = [
        ''
          import Config
          config :pleroma, Pleroma.Web.Auth.Authenticator, Pleroma.Web.Auth.LDAPAuthenticator
          config :pleroma, :ldap,
            enabled: true,
            host: "localhost",
            port: 389,
            ssl: false,
            base: "ou=pleroma,${domain}",
            uid: "uid"
        ''
      ];
    })
  ];
}
