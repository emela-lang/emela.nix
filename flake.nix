{
  description = "Nix overlay and packages for the Emela toolchain (prebuilt release binary, or a main-HEAD source build)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Tracks emela's main HEAD. `nix flake update emela-src` moves the source
    # build to the latest commit; `flake = false` because emela isn't a flake.
    emela-src = {
      url = "github:emela-lang/emela";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, emela-src }:
    let
      inherit (nixpkgs) lib;
      baseOverlay = import ./overlay.nix { inherit emela-src; };
    in
    {
      # The headline deliverable: `pkgs.emela` is the prebuilt release binary.
      overlays.default = baseOverlay;

      # Same, but `pkgs.emela` becomes the main-HEAD source build (needs the
      # rust-overlay/`emelaRustPlatform` from flake.nix, or falls back to
      # nixpkgs' `rustPlatform`).
      overlays.fromSource = lib.composeExtensions baseOverlay
        (final: prev: { emela = final.emela-source; });
    }
    // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            rust-overlay.overlays.default
            # Pin the source build's toolchain to emela's rust-toolchain.toml.
            (final: prev: {
              emelaRustPlatform =
                let toolchain = final.rust-bin.fromRustupToolchainFile "${emela-src}/rust-toolchain.toml";
                in final.makeRustPlatform {
                  cargo = toolchain;
                  rustc = toolchain;
                };
            })
            baseOverlay
          ];
        };

        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile "${emela-src}/rust-toolchain.toml";

        # Prebuilt binaries exist only for these systems; elsewhere the default
        # package is the source build.
        hasBinary = builtins.elem system [ "aarch64-darwin" "x86_64-linux" ];
        mainPkg = if hasBinary then pkgs.emela else pkgs.emela-source;
      in
      {
        packages = {
          # main HEAD, built from source with the pinned Rust toolchain.
          emela-source = pkgs.emela-source;
          default = mainPkg;
        } // lib.optionalAttrs hasBinary {
          # prebuilt release binary
          emela = pkgs.emela;
        };

        apps.default = {
          type = "app";
          program = lib.getExe mainPkg;
        };

        # `nix run .#update [-- <version>]` re-pins versions.json to a new (or
        # the latest) release. Run it from a checkout so it can write the file.
        apps.update = {
          type = "app";
          program = lib.getExe (pkgs.writeShellApplication {
            name = "emela-update";
            runtimeInputs = [ pkgs.curl pkgs.jq pkgs.gnused pkgs.git pkgs.nix ];
            text = builtins.readFile ./pkgs/emela/update.sh;
          });
        };

        # Rust environment for building / hacking on emela from source, matching
        # the upstream rust-toolchain.toml (stable + rustfmt + clippy).
        devShells.default = pkgs.mkShell {
          packages = [
            rustToolchain
            pkgs.rust-analyzer
          ];
          shellHook = ''
            echo "emela dev shell — $(rustc --version)"
            echo "source tree (main HEAD): ${emela-src}"
            echo "build the CLI with:  cargo build -p emela --release"
          '';
        };
      });
}
