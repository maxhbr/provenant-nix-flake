# Provenant Nix Flake

A [Nix flake](https://nix.dev/concepts/flakes) providing [provenant](https://github.com/mstykow/provenant) as a package, app, and overlay.

```bash
nix run .#                          # run provenant
nix build .#                        # build the package
```

## Install on NixOS

Add this flake as an input and apply its overlay, then include `provenant` in `systemPackages`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    provenant.url = "github:mstykow/provenant-nix-flake";
  };

  outputs = { self, nixpkgs, provenant }:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          nixpkgs.overlays = [ provenant.overlays.default ];
          environment.systemPackages = [ nixpkgs.legacyPackages.x86_64-linux.provenant ];
        }
      ];
    };
}
```

Then `nixos-rebuild switch --flake .#` — `provenant` is on `PATH`.

# License

Licensed under **Apache License 2.0** — see [LICENSE](./LICENSE).
