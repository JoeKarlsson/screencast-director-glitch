#!/usr/bin/env bash
# Copies each effect into Screencast Director's personal Effects folder (copies, not links: a video
# freezes its own copy on first use, and a link would freeze as a link).
set -euo pipefail
cd "$(dirname "$0")"
dest="$HOME/Library/Application Support/Screencast Director/Effects"
mkdir -p "$dest"
for dir in effects/*/; do
  name=$(basename "$dir")
  rm -rf "${dest:?}/$name"
  cp -R "$dir" "$dest/$name"
  echo "installed $name"
done
