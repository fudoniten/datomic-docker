{ repo, name, datomicVersion, datomicZip, tag ? datomicVersion, config, lib
, pkgs, ... }:

with lib;
let
  datomicDrv = pkgs.stdenvNoCC.mkDerivation {
    name = "datomic-pro-${datomicVersion}";
    src = datomicZip;
    nativeBuildInputs = with pkgs; [ unzip ];
    installPhase = ''
      mkdir -p $out/datomic-pro
      cp -a $src/* $out/datomic-pro/
    '';
  };

in pkgs.dockerTools.buildImage {
  name = "${repo}/${name}";
  inherit tag;

  copyToRoot = pkgs.buildEnv {
    name = "datomic-image-root";
    paths = with pkgs; [
      datomicDrv
      bashInteractive
      coreutils
      dnsutils
      cacert
      glibc
      glibcLocalesUtf8
      nss
    ];
    pathsToLink = [ "/bin" ];
  };

  runAsRoot = ''
    mkdir -p /opt
    cp -a ${datomicDrv}/datomic-pro /opt/datomic/pro
    chmod u+w -R /opt/datomic-pro
    chown -R 9999:9999 /opt/datomic-pro
  '';

  config = {
    Entrypoint = [ "/opt/datomic-pro/bin/transactor" ];
    Cmd = [ "/etc/datomic/transactor.properties" ];
    User = "9999:9999";
    Env = mapAttrsToList (k: v: "${k}=${v}") (rec {
      PATH =
        concatStringsSep ":" [ "/opt/datomic-pro/jdk-17/bin" "$PATH" "/bin" ];
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      NIX_SSL_CERT_FILE = SSL_CERT_FILE;
      LOCALE_ARCHIVE = "${pkgs.glibcLocalesUtf8}/lib/locale/locale-archive";
      LANG = "C.UTF-8";
      LC_ALL = "C.UTF-8";
      TZ = "UTC";
    });
    Volumes = { "/etc/datomic" = { }; };
  };
}
