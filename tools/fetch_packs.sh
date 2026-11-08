#!/usr/bin/env bash
# Downloads the CC0 packs in tools/asset_sources.txt into vendor/<name>/ (not committed).
set -u
mkdir -p vendor
grep -v '^#' tools/asset_sources.txt | while IFS='|' read -r name page; do
  name=$(echo "$name" | xargs); page=$(echo "$page" | xargs)
  [ -z "$name" ] && continue
  [ -d "vendor/$name" ] && continue
  html=$(curl -fsSL --retry 3 "$page" || true)
  rel=$(echo "$html" | grep -oE '/sites/default/files/[^"]+\.zip' | head -1)
  [ -z "$rel" ] && { echo "NO ZIP for $name"; continue; }
  curl -fsSL --retry 3 -o "vendor/$name.zip" "https://opengameart.org$rel" && mkdir -p "vendor/$name" && unzip -q -o "vendor/$name.zip" -d "vendor/$name"
done
