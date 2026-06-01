#!/usr/bin/env bash
# Fetch the vendored blesh-contrib snapshot into contrib/ (no git submodule).
#
# This downloads a pinned commit of https://github.com/akinomyoga/blesh-contrib
# as a tarball and lays it down under contrib/ so the contrib component is built
# locally from in-tree sources.  Re-run to refresh or restore the snapshot.

set -euo pipefail

# Pinned upstream commit (akinomyoga/blesh-contrib).
CONTRIB_COMMIT=261b2297aadea0e338eed95f9be70257e8e8b339
CONTRIB_REPO=akinomyoga/blesh-contrib

# Resolve repo root from this script's location (make/..).
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/.." && pwd)
dest=$repo_root/contrib

url=https://codeload.github.com/$CONTRIB_REPO/tar.gz/$CONTRIB_COMMIT

tmp=$(mktemp -d "${TMPDIR:-/tmp}/blesh-contrib.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

echo "fetch-contrib: downloading $CONTRIB_REPO @ ${CONTRIB_COMMIT:0:12} ..." >&2
if command -v curl >/dev/null 2>&1; then
  curl -fsSL -o "$tmp/contrib.tar.gz" "$url"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$tmp/contrib.tar.gz" "$url"
else
  echo "fetch-contrib: need curl or wget to download contrib" >&2
  exit 1
fi

echo "fetch-contrib: extracting ..." >&2
tar -xzf "$tmp/contrib.tar.gz" -C "$tmp"
src=$tmp/blesh-contrib-$CONTRIB_COMMIT
[[ -d $src ]] || { echo "fetch-contrib: unexpected tarball layout" >&2; exit 1; }

echo "fetch-contrib: installing into $dest ..." >&2
mkdir -p "$dest"
cp -R "$src"/. "$dest"/

echo "fetch-contrib: done ($CONTRIB_REPO @ ${CONTRIB_COMMIT:0:12})" >&2
