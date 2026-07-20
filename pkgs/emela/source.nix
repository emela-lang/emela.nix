# Emela built from source (the `emela-src` tree, i.e. main HEAD as pinned in
# flake.lock). `rustPlatform` is normally the toolchain pinned to emela's
# rust-toolchain.toml (see flake.nix / overlay.nix).
{ lib
, rustPlatform
, emela-src
}:

assert lib.assertMsg (emela-src != null)
  "emela (fromSource): `emela-src` must be provided (the emela source tree / flake input).";

let
  cargoToml = builtins.fromTOML (builtins.readFile "${emela-src}/Cargo.toml");
  baseVersion = cargoToml.workspace.package.version;
  # Distinguish successive HEAD builds when emela-src is a git flake input.
  version = baseVersion + lib.optionalString (emela-src ? shortRev) "-g${emela-src.shortRev}";
in
rustPlatform.buildRustPackage {
  pname = "emela";
  inherit version;

  src = emela-src;

  # Vendored from the checked-in lockfile, so no cargoHash to maintain and no
  # network access at build time.
  cargoLock.lockFile = "${emela-src}/Cargo.lock";

  # Build only the `emela` CLI crate. The `emela-wasm` crate is excluded from
  # upstream `default-members` (it needs wasm-pack/wasm-bindgen), so keep it out.
  cargoBuildFlags = [ "-p" "emela" ];
  cargoTestFlags = [ "-p" "emela" ];

  # The upstream suite is thorough but slow and unnecessary to produce a working
  # `emela`. Set `doCheck = true` (or override) to run it at build time.
  doCheck = false;

  meta = {
    description = "Emela compiler and CLI (built from the main HEAD source)";
    homepage = "https://github.com/emela-lang/emela";
    license = lib.licenses.asl20;
    mainProgram = "emela";
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    platforms = lib.platforms.unix;
  };
}
