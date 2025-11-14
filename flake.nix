{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.05";
    utils.url = "github:numtide/flake-utils";
    datomic = {
      url =
        "https://datomic-pro-downloads.s3.amazonaws.com/1.0.7469/datomic-pro-1.0.7469.zip";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, utils, datomic, ... }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";
        name = "datomic-transactor";
        repo = "registry.kube.sea.fudo.link";
        version = "1.0.7469";
      in {
        packages = rec {
          default = datomicImage;

          datomicImage = buildDatomicImage {
            inherit version;
            tag = version;
          };

          buildDatomicImage = { version, tag ? version, ... }:
            pkgs.callPackage ./datomic.nix {
              inherit repo name;
              datomicVersion = version;
              inherit tag;
              datomicZip = datomic;
            };

          deployContainer = let
            policyJson = pkgs.writeText "containers-policy.json"
              (builtins.toJSON {
                default = [{ type = "reject"; }];
                transports = {
                  docker = { "" = [{ type = "insecureAcceptAnything"; }]; };
                  docker-archive = {
                    "" = [{ type = "insecureAcceptAnything"; }];
                  };
                };
              });
            containerPushScript = with pkgs.lib;
              concatStringsSep "\n" (map (tag:
                let container = buildDatomicImage { inherit version tag; };
                in ''
                  echo "pushing ${name} -> ${repo}/${name}:${tag}..."
                  skopeo copy --policy ${policyJson} docker-archive:"${container}" "docker://${repo}/${name}:${tag}"
                '') [ version "latest" ]);
          in pkgs.writeShellApplication {
            name = "deployContainer";
            runtimeInputs = with pkgs; [ skopeo coreutils ];
            text = ''
              set -euo pipefail
              ${containerPushScript}
            '';
          };
        };
      });
}
