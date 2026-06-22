{
  description = "Provenant - supply chain attestation tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      srcInfo = builtins.fromJSON (builtins.readFile ./srcInfo.json);
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        version = srcInfo.version;
        info = srcInfo.platforms.${system};

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
                  platforms = builtins.attrNames srcInfo.platforms;
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
                  platforms = builtins.attrNames srcInfo.platforms;
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
