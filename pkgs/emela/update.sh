#!/usr/bin/env bash
# Pin a new (or specific) emela release into pkgs/emela/versions.json.
#
#   nix run .#update              # -> latest stable release
#   nix run .#update -- 0.8.0     # -> that exact version
#   ./pkgs/emela/update.sh 0.8.0  # (same, run directly)
#
# Resolving "latest" reads the /releases/latest redirect, so it needs no GitHub
# API token and never hits the API rate limit.
set -euo pipefail

repo="${EMELA_REPO:-emela-lang/emela}"

# Locate versions.json relative to the git checkout (works under `nix run`,
# which executes in the user's cwd), with an env override for other layouts.
if [ -n "${EMELA_VERSIONS_JSON:-}" ]; then
  json="$EMELA_VERSIONS_JSON"
else
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  json="$root/pkgs/emela/versions.json"
fi
[ -f "$json" ] || { echo "versions.json not found at: $json" >&2; exit 1; }

version="${1:-}"
if [ -z "$version" ]; then
  tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/$repo/releases/latest" | sed -n 's#.*/releases/tag/##p')"
  [ -n "$tag" ] || { echo "could not resolve latest release of $repo" >&2; exit 1; }
  version="$tag"
fi
version="${version#v}"
echo "pinning emela v$version -> $json" >&2

# Nix system -> release asset target triple. Keep in sync with binary.nix.
systems="aarch64-darwin:aarch64-apple-darwin x86_64-linux:x86_64-unknown-linux-gnu"

jq_args=(--arg v "$version")
jq_filter='.latest = $v | .releases[$v] = {}'
for pair in $systems; do
  sys="${pair%%:*}"
  target="${pair##*:}"
  url="https://github.com/$repo/releases/download/v$version/emela-v$version-$target.tar.gz"
  echo "  fetching $target ..." >&2
  sri="$(nix hash convert --hash-algo sha256 "$(nix-prefetch-url "$url")")"
  var="h_${sys//[-.]/_}"                 # jq needs identifier-safe variable names
  jq_args+=(--arg "$var" "$sri")
  jq_filter+=" | .releases[\$v][\"$sys\"] = \$$var"
done

tmp="$(mktemp)"
jq "${jq_args[@]}" "$jq_filter" "$json" >"$tmp"
mv "$tmp" "$json"
echo "updated $json:" >&2
jq . "$json"
