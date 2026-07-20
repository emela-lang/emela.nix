# Emela package entry point.
#
#   fromSource = false (default) -> prebuilt GitHub release binary (binary.nix)
#   fromSource = true            -> build main HEAD from source     (source.nix)
#   version    = null  (default) -> latest pinned release (see versions.json);
#                "0.6.0" etc.    -> that pinned release (binary only)
#
# Both flags are overridable, e.g.
#   pkgs.emela.override { fromSource = true; }
#   pkgs.emela.override { version = "0.6.0"; }
{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, rustPlatform
, emela-src ? null
, fromSource ? false
, version ? null
}:

if fromSource then
  import ./source.nix { inherit lib rustPlatform emela-src; }
else
  import ./binary.nix { inherit lib stdenv fetchurl autoPatchelfHook version; }
