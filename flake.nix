{
  description = "Provenant - supply chain attestation tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        version = "0.1.14";

        srcInfo = {
          x86_64-linux = {
            url = "https://github.com/mstykow/provenant/releases/download/v${version}/provenant-linux-x86_64.tar.gz";
            hash = "sha256-2rsYd4d3sXVPQf5MRKrwq8p5d2UTRWJLX/qgtirRhhc=";
          };
          aarch64-linux = {
            url = "https://github.com/mstykow/provenant/releases/download/v${version}/provenant-linux-aarch64.tar.gz";
            hash = "sha256-U9otuFvAQUJ1LXULw1fjL9lYB+cAZp+jP/awPHhBo+s=";
          };
          x86_64-darwin = {
            url = "https://github.com/mstykow/provenant/releases/download/v${version}/provenant-macos-x86_64.tar.gz";
            hash = "sha256-ih6PxyHOCvzQx6McaHBAN31kbsZnOn8hOn43SrRvMTk=";
          };
          aarch64-darwin = {
            url = "https://github.com/mstykow/provenant/releases/download/v${version}/provenant-macos-aarch64.tar.gz";
            hash = "sha256-XybPoXtWGK2cnzim8DpeuxIURhEEabhO0OGzejFB0ds=";
          };
        };

        info = srcInfo.${system};

        provenant =
          if pkgs.stdenv.isLinux then
            pkgs.stdenv.mkDerivation
              {
                pname = "provenant";
                version = version;

                src = pkgs.fetchurl {
                  url = info.url;
                  hash = info.hash;
                };

                sourceRoot = ".";

                nativeBuildInputs = [ pkgs.autoPatchelfHook ];

                buildInputs = with pkgs; [
                  gcc.cc.lib
                  glibc
                ];

                installPhase = ''
                  runHook preInstall
                  mkdir -p $out/bin
                  install -m755 provenant $out/bin/provenant
                  runHook postInstall
                '';

                meta = with pkgs.lib; {
                  description = "Provenant - supply chain attestation tool";
                  homepage = "https://github.com/mstykow/provenant";
                  license = licenses.asl20;
                  platforms = builtins.attrNames srcInfo;
                  mainProgram = "provenant";
                };
              }
          else
            pkgs.stdenv.mkDerivation
              {
                pname = "provenant";
                version = version;

                src = pkgs.fetchurl {
                  url = info.url;
                  hash = info.hash;
                };

                sourceRoot = ".";

                installPhase = ''
                  runHook preInstall
                  mkdir -p $out/bin
                  install -m755 provenant $out/bin/provenant
                  runHook postInstall
                '';

                meta = with pkgs.lib; {
                  description = "Provenant - supply chain attestation tool";
                  homepage = "https://github.com/mstykow/provenant";
                  license = licenses.asl20;
                  platforms = builtins.attrNames srcInfo;
                  mainProgram = "provenant";
                };
              };

      in
      {
        packages = {
          provenant = provenant;
          default = provenant;
        };

        apps.default = {
          type = "app";
          program = "${provenant}/bin/provenant";
        };
      }
    ) // {
      overlays.default = final: prev: {
        provenant = self.packages.${final.system}.provenant;
      };
    };
}
