# Emela overlay factory.
#
# Adds to a nixpkgs package set:
#   emela              - the latest pinned release binary (no Rust toolchain)
#   emela-source       - the same package built from main HEAD (`emela-src`)
#   emelaVersions.<v>  - each pinned release binary, keyed by version string
#
# Switch versions with `emela.override { version = "0.6.0"; }` or
# `emelaVersions."0.6.0"`. Build main HEAD with `emela.override { fromSource = true; }`.
#
# The source build uses `emelaRustPlatform` when the package set defines it
# (flake.nix pins it to emela's rust-toolchain.toml), else nixpkgs' `rustPlatform`.
{ emela-src }:

final: prev:
let
  callEmela = args: final.callPackage ./pkgs/emela ({
    inherit emela-src;
    rustPlatform = final.emelaRustPlatform or final.rustPlatform;
  } // args);

  data = builtins.fromJSON (builtins.readFile ./pkgs/emela/versions.json);
in
{
  emela = callEmela { };
  emela-source = callEmela { fromSource = true; };

  # Every pinned release, e.g. `pkgs.emelaVersions."0.7.0"`.
  emelaVersions = final.lib.genAttrs (builtins.attrNames data.releases)
    (v: callEmela { version = v; });
}
