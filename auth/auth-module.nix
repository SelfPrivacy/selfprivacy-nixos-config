{ config, lib, pkgs, ... }:
let
  inherit (lib)
    mkOption
    types
    ;
  auth-passthru = config.selfprivacy.passthru.auth;
  keys-path = auth-passthru.keys-path;
  # TODO consider tmpfiles.d for creating a directory in ${keys-path}
  # generate OAuth2 client secret
  mkKanidmExecStartPreScript = oauthClientID: linuxGroup:
    let
      secretFP = auth-passthru.mkOAuth2ClientSecretFP linuxGroup;
    in
    pkgs.writeShellScript
      "${oauthClientID}-kanidm-ExecStartPre-script.sh" ''
      [ -f "${secretFP}" ] || \
        "${lib.getExe pkgs.openssl}" rand -base64 -out "${secretFP}" 32 && \
        chmod 640 "${secretFP}"
    '';
  mkKanidmExecStartPostScript = oauthClientID: linuxGroup:
    let
      kanidmServiceAccountName = "sp.${oauthClientID}.service-account";
      kanidmServiceAccountTokenName = "${oauthClientID}-service-account-token";
      kanidmServiceAccountTokenFP =
        auth-passthru.mkServiceAccountTokenFP linuxGroup;
    in
    pkgs.writeShellScript
      "${oauthClientID}-kanidm-ExecStartPost-script.sh"
      ''
        export HOME=$RUNTIME_DIRECTORY/client_home
        readonly KANIDM="${pkgs.kanidm}/bin/kanidm"

        # try to get existing Kanidm service account
        KANIDM_SERVICE_ACCOUNT="$($KANIDM service-account list --name idm_admin | grep -E "^name: ${kanidmServiceAccountName}$")"
        echo KANIDM_SERVICE_ACCOUNT: "$KANIDM_SERVICE_ACCOUNT"
        if [ -n "$KANIDM_SERVICE_ACCOUNT" ]
        then
            echo "kanidm service account \"${kanidmServiceAccountName}\" is found"
        else
            echo "kanidm service account \"${kanidmServiceAccountName}\" is not found"
            echo "creating new kanidm service account \"${kanidmServiceAccountName}\""
            if $KANIDM service-account create --name idm_admin "${kanidmServiceAccountName}" "${kanidmServiceAccountName}" idm_admin
            then
                echo "kanidm service account \"${kanidmServiceAccountName}\" created"
            else
                echo "error: cannot create kanidm service account \"${kanidmServiceAccountName}\""
                exit 1
            fi
        fi

        # add Kanidm service account to `idm_mail_servers` group
        $KANIDM group add-members idm_mail_servers "${kanidmServiceAccountName}"

        # create a new read-only token for kanidm
        if ! KANIDM_SERVICE_ACCOUNT_TOKEN_JSON="$($KANIDM service-account api-token generate --name idm_admin "${kanidmServiceAccountName}" "${kanidmServiceAccountTokenName}" --output json)"
        then
            echo "error: kanidm CLI returns an error when trying to generate service-account api-token"
            exit 1
        fi
        if ! KANIDM_SERVICE_ACCOUNT_TOKEN="$(echo "$KANIDM_SERVICE_ACCOUNT_TOKEN_JSON" | ${lib.getExe pkgs.jq} -r .result)"
        then
            echo "error: cannot get service-account API token from JSON"
            exit 1
        fi

        if ! install --mode=640 \
        <(printf "%s" "$KANIDM_SERVICE_ACCOUNT_TOKEN") \
        ${kanidmServiceAccountTokenFP}
        then
            echo "error: cannot write token to \"${kanidmServiceAccountTokenFP}\""
            exit 1
        fi
      '';
in
{
  options.selfprivacy.auth = {
    clients = mkOption {
      description =
        "Configurations for OAuth2 & LDAP servers clients services. Corresponding Kanidm provisioning configuration and systemd scripts are generated.";
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            clientID = mkOption {
              type = types.nullOr types.str;
              description = ''
                Name of this client service. Used as OAuth2 client ID and to form Kanidm sp.$\{clientID}.* group names. Defaults to attribute name in virtualHosts;
              '';
              default = null;
            };
            displayName = mkOption {
              type = types.nullOr types.str;
              description = "Display name showed in Kanidm Web GUI. Defaults to clientID.";
              default = null;
            };
            enablePkce = mkOption {
              type = lib.types.bool;
              description =
                "Whether PKCE must be used between client and Kanidm.";
              default = false;
            };
            adminsGroup = mkOption {
              type =
                types.nullOr (lib.types.strMatching "sp\.[A-Za-z0-9]+\.admins");
              description =
                "Name of admins group in Kanidm, whose members have admin level access to resources (service) associated with OAuth2 client authorization.";
              default = null;
            };
            usersGroup = mkOption {
              type =
                types.nullOr (lib.types.strMatching "sp\.[A-Za-z0-9]+\.users");
              description =
                "Name of users group in Kanidm, whose members have user level access to resources (service) associated with OAuth2 client authorization.";
              default = null;
            };
            originLanding = mkOption {
              type = types.nullOr lib.types.str;
              description =
                "The origin landing of the service for OAuth2 redirects.";
            };
            originUrl = mkOption {
              type = types.nullOr lib.types.str;
              description =
                "The origin URL of the service for OAuth2 redirects.";
            };
            subdomain = lib.mkOption {
              type =
                lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
              description = "Subdomain of the service.";
            };
            # when true, "name" is passed to a service instead of "name@domain"
            useShortPreferredUsername = mkOption {
              description =
                "Use 'name' instead of 'spn' in the preferred_username claim.";
              type = types.bool;
              default = true;
            };
            linuxUserOfClient = mkOption {
              type = types.nullOr lib.types.str;
              description =
                "Name of a Linux OAuth2 client user, under which it should get access through a folder with keys.";
              default = null;
            };
            linuxGroupOfClient = mkOption {
              type = types.nullOr lib.types.str;
              description =
                "Name of Linux OAuth2 client group, under which it should read an OAuth2 client secret file.";
              default = null;
            };
            isTokenNeeded = mkOption {
              description =
                "Whether a read-only needs to be generated for LDAP access.";
              type = types.bool;
              default = false;
            };
            clientSystemdUnits = mkOption {
              description = "A list of systemd services, which depend on OAuth service";
              # taken from nixos/lib/systemd-lib.nix: unitNameType
              type = types.listOf
                (types.strMatching "[a-zA-Z0-9@%:_.\\-]+[.](service|socket|device|mount|automount|swap|target|path|timer|scope|slice)");
            };
            scopeMaps = mkOption {
              description = ''
                Maps kanidm groups to returned oauth scopes.
                See [Scope Relations](https://kanidm.github.io/kanidm/stable/integrations/oauth2.html#scope-relationships) for more information.
              '';
              type = types.nullOr (types.attrsOf (types.listOf types.str));
              default = null;
            };
            claimMaps = mkOption {
              description = ''
                Adds additional claims (and values) based on which kanidm groups an authenticating party belongs to.
                See [Claim Maps](https://kanidm.github.io/kanidm/master/integrations/oauth2.html#custom-claim-maps) for more information.
              '';
              default = { };
              type = types.attrsOf (
                types.submodule {
                  options = {
                    joinType = mkOption {
                      description = ''
                        Determines how multiple values are joined to create the claim value.
                        See [Claim Maps](https://kanidm.github.io/kanidm/master/integrations/oauth2.html#custom-claim-maps) for more information.
                      '';
                      type = types.enum [
                        "array"
                        "csv"
                        "ssv"
                      ];
                      default = "array";
                    };

                    valuesByGroup = mkOption {
                      description = "Maps kanidm groups to values for the claim.";
                      default = { };
                      type = types.attrsOf (types.listOf types.str);
                    };
                  };
                }
              );
            };
            imageFile = mkOption {
              type = types.nullOr lib.types.path;
              description = ''
                Filepath of an image which is displayed in Kanidm web GUI for a service.
              '';
              default = null;
            };
          };
        }
      );
    };
  };
  config = lib.mkIf config.selfprivacy.sso.enable (
    let
      clientsAttrsList = lib.attrsets.mapAttrsToList
        (name: attrs: attrs // rec {
          clientID =
            if attrs.clientID == null
            then name
            else attrs.clientID;
          displayName =
            if attrs.displayName == null
            then clientID
            else attrs.displayName;
          adminsGroup =
            if attrs.adminsGroup == null
            then "sp.${clientID}.admins"
            else attrs.adminsGroup;
          usersGroup =
            if attrs.usersGroup == null
            then "sp.${clientID}.users"
            else attrs.usersGroup;
          basicSecretFile =
            "${keys-path}/${linuxGroupOfClient}/kanidm-oauth-client-secret";
          linuxUserOfClient =
            if attrs.linuxUserOfClient == null
            then clientID
            else attrs.linuxUserOfClient;
          linuxGroupOfClient =
            if attrs.linuxGroupOfClient == null
            then clientID
            else attrs.linuxGroupOfClient;
          originLanding =
            if attrs.originLanding == null
            then "https://${attrs.subdomain}.${config.selfprivacy.domain}/"
            else attrs.originLanding;
          scopeMaps =
            if attrs.scopeMaps == null
            then { "${usersGroup}" = [ "email" "openid" "profile" ]; }
            else attrs.scopeMaps;
        })
        config.selfprivacy.auth.clients;
    in
    {
      # for each OAuth2 client: member of the `keys` group for directory access
      users.groups.keys.members = lib.mkMerge (lib.forEach
        clientsAttrsList
        ({ linuxUserOfClient, ... }: [ linuxUserOfClient ])
      );

      systemd.tmpfiles.settings."kanidm-secrets" = lib.mkMerge (lib.forEach
        clientsAttrsList
        ({ linuxGroupOfClient, ... }: {
          "${keys-path}/${linuxGroupOfClient}".d = {
            user = "kanidm";
            group = linuxGroupOfClient;
            mode = "2750";
          };
        })
      );

      # for each OAuth2 client: scripts with Kanidm CLI commands
      systemd.services.kanidm = {
        before =
          lib.lists.concatMap
            ({ clientSystemdUnits, ... }: clientSystemdUnits)
            clientsAttrsList;
        serviceConfig =
          lib.mkMerge (lib.forEach
            clientsAttrsList
            ({ clientID, isTokenNeeded, linuxGroupOfClient, ... }: {
              ExecStartPre = [
                # "-" prefix means to ignore exit code of prefixed script
                ("-" + mkKanidmExecStartPreScript clientID linuxGroupOfClient)
              ];
              ExecStartPost = lib.mkIf isTokenNeeded
                (lib.mkAfter [
                  ("-" +
                    mkKanidmExecStartPostScript clientID linuxGroupOfClient)
                ]);
            }));
      };

      # for each OAuth2 client: Kanidm provisioning options
      services.kanidm.provision = lib.mkMerge (lib.forEach
        clientsAttrsList
        ({ adminsGroup
         , basicSecretFile
         , claimMaps
         , clientID
         , displayName
         , enablePkce
         , imageFile
         , originLanding
         , originUrl
         , scopeMaps
         , useShortPreferredUsername
         , usersGroup
         , ...
         }: {
          groups = {
            "${adminsGroup}".members =
              [ auth-passthru.admins-group ];
            "${usersGroup}".members =
              [ adminsGroup auth-passthru.full-users-group ];
          };
          systems.oauth2.${clientID} = {
            inherit
              basicSecretFile
              claimMaps
              displayName
              imageFile
              originLanding
              originUrl
              scopeMaps
              ;
            preferShortUsername = useShortPreferredUsername;
            allowInsecureClientDisablePkce = ! enablePkce;
            removeOrphanedClaimMaps = true;

            # NOTE https://github.com/oddlama/kanidm-provision/issues/15
            # add more scopes when a user is a member of specific group
            # currently not possible due to https://github.com/kanidm/kanidm/issues/2882#issuecomment-2564490144
            # supplementaryScopeMaps."${admins-group}" =
            #   [ "read:admin" "write:admin" ];
          };
        }));
    }
  );
}
