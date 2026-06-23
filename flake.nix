{
  description = "Provenant - supply chain attestation tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
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

      # ── Hardcoded version list ──────────────────────────────────────────
      # Add a new entry here when a new tag JSON is added to ./jsons/
      versions = {
        "0_1_14" = ./jsons/0.1.14.json;
      };

      # The latest version — update when adding a new tag
      latest = "0_1_14";

    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Build one package per version
        versionPackages = builtins.mapAttrs
          (name: jsonFile: mkProvenant jsonFile system)
          versions;

        # The "provenant" alias always points to the latest version
        provenant = versionPackages.${latest};

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
