# Prebuilt Emela release binary, fetched from the GitHub Releases of
# emela-lang/emela. This path needs no Rust toolchain.
#
# Pinned versions and their per-platform hashes live in ./versions.json.
# `version = null` (the default) selects `latest` from that file. Bump/add
# entries with `nix run .#update` (see ./update.sh); switch versions with
# `pkgs.emela.override { version = "0.6.0"; }` or `pkgs.emelaVersions."0.6.0"`.
{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, version ? null
}:

let
  data = builtins.fromJSON (builtins.readFile ./versions.json);

  resolvedVersion = if version == null then data.latest else version;

  release = data.releases.${resolvedVersion} or (throw ''
    emela: no pinned hashes for version '${resolvedVersion}'.
    Known versions: ${lib.concatStringsSep ", " (builtins.attrNames data.releases)}.
    Pin it with `nix run .#update -- ${resolvedVersion}`, or build from source
    via `fromSource = true`.'');

  # Nix system -> Rust target triple used in the release asset name.
  targets = {
    aarch64-darwin = "aarch64-apple-darwin";
    x86_64-linux = "x86_64-unknown-linux-gnu";
  };

  system = stdenv.hostPlatform.system;
  target = targets.${system} or (throw ''
    emela: no prebuilt release binary is published for '${system}'.
    Build from source instead, e.g. `pkgs.emela.override { fromSource = true; }`
    or the `.#emela-source` flake package.'');
  hash = release.${system} or (throw
    "emela ${resolvedVersion}: release has no asset for '${system}'.");
in
stdenv.mkDerivation {
  pname = "emela";
  version = resolvedVersion;

  src = fetchurl {
    url = "https://github.com/emela-lang/emela/releases/download/v${resolvedVersion}/emela-v${resolvedVersion}-${target}.tar.gz";
    inherit hash;
  };

  # The tarball is a single top-level `emela` executable rather than a
  # directory, so unpack it by hand and stay in the build root.
  unpackPhase = ''
    runHook preUnpack
    tar -xzf "$src"
    runHook postUnpack
  '';
  sourceRoot = ".";

  # The Linux asset is a dynamically-linked glibc build, so rewrite its ELF
  # interpreter/rpath for the Nix store. Both are no-ops on Darwin.
  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 emela "$out/bin/emela"
    runHook postInstall
  '';

  # Smoke-test the installed binary (also validates autoPatchelf on Linux).
  doInstallCheck = true;
  installCheckPhase = ''
    "$out/bin/emela" --version
  '';

  meta = {
    description = "Emela compiler and CLI (prebuilt release binary)";
    homepage = "https://github.com/emela-lang/emela";
    changelog = "https://github.com/emela-lang/emela/releases/tag/v${resolvedVersion}";
    license = lib.licenses.asl20;
    mainProgram = "emela";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames targets;
  };
}
