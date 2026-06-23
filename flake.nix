{
  description = "Provenant - supply chain attestation tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      index = builtins.fromJSON (builtins.readFile ./index.json);

      # Convert "0.1.14" -> "0_1_14" for valid Nix attribute names
      versionToAttrName = version:
        "provenant_" + (builtins.replaceStrings ["."] ["_"] version);

      # Helper: build a provenant package from a per-tag JSON file
      mkProvenant = jsonFile: system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          srcInfo = builtins.fromJSON (builtins.readFile jsonFile);
          version = srcInfo.version;
          info = srcInfo.platforms.${system};
        in
          if pkgs.stdenv.isLinux then
            pkgs.stdenv.mkDerivation {
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
                description = "Provenant - supply chain attestation tool (v${version})";
                homepage = "https://github.com/mstykow/provenant";
                license = licenses.asl20;
                platforms = builtins.attrNames srcInfo.platforms;
                mainProgram = "provenant";
              };
            }
          else
            pkgs.stdenv.mkDerivation {
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
                description = "Provenant - supply chain attestation tool (v${version})";
                homepage = "https://github.com/mstykow/provenant";
                license = licenses.asl20;
                platforms = builtins.attrNames srcInfo.platforms;
                mainProgram = "provenant";
              };
            };

      lib = nixpkgs.lib;

      # Build version → path mapping from index.json with attr-safe names
      # e.g. { "0_1_14" = ./jsons/0.1.14.json; }
      attrNameMap = lib.mapAttrs'
        (version: rel: {
          name = versionToAttrName version;
          value = ./. + "/${rel}";
        })
        index.versions;

      latestAttrName = versionToAttrName index.latest;

    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Build one package per version
        versionPackages = builtins.mapAttrs
          (name: jsonFile: mkProvenant jsonFile system)
          attrNameMap;

        # The "provenant" alias always points to the latest version
        provenant = versionPackages.${latestAttrName};

      in
      {
        packages = versionPackages // {
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
