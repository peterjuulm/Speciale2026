#!/bin/bash
# The Mac rebuild against the release's assets (written 21 October 2026,
# for phoenix-mac-rebuild): zips by sha256, then entry by entry, and the
# frontend export against the release zip's wwwroot/.
set -u
P=/private/tmp/rb1-mac-run R=$P/release L=$P/local C=$P/compare TAG=v0.0.0-thesis.6
rm -rf "$C" && mkdir -p "$C"
hashes() { ( cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 ); }
for z in ws-pems-linux-x64 ws-pems-job-worker-linux-x64; do
  a=$(shasum -a 256 < "$R/$z-$TAG.zip" | cut -d' ' -f1) b=$(shasum -a 256 < "$L/linux/$z-$TAG.zip" | cut -d' ' -f1)
  [ "$a" = "$b" ] && echo "same  $z-$TAG.zip  $a" || echo "DIFF  $z-$TAG.zip  release $a  mac $b"
  mkdir -p "$C/$z" && unzip -q "$L/linux/$z-$TAG.zip" -d "$C/$z/mac"
  hashes "$R/unz/$z" > "$C/$z/release.sha256"; hashes "$C/$z/mac" > "$C/$z/mac.sha256"
  if cmp -s "$C/$z/release.sha256" "$C/$z/mac.sha256"; then
    echo "same    $z: entries' contents ($(wc -l < "$C/$z/release.sha256" | tr -d ' ') / $(wc -l < "$C/$z/mac.sha256" | tr -d ' ') files)"
  else
    echo "DIFF    $z: entries' contents ($(wc -l < "$C/$z/release.sha256" | tr -d ' ') / $(wc -l < "$C/$z/mac.sha256" | tr -d ' ') files)"
    diff "$C/$z/release.sha256" "$C/$z/mac.sha256" > "$C/$z/contents.diff"; grep -c '^[<>]' "$C/$z/contents.diff" | sed 's/^/        lines differing: /'
  fi
  zipinfo -v "$R/$z-$TAG.zip" | tail -n +2 > "$C/$z/release.zipinfo"; zipinfo -v "$L/linux/$z-$TAG.zip" | tail -n +2 > "$C/$z/mac.zipinfo"
  cmp -s "$C/$z/release.zipinfo" "$C/$z/mac.zipinfo" && echo "same    $z: zipinfo -v" || { echo "DIFF    $z: zipinfo -v"; diff "$C/$z/release.zipinfo" "$C/$z/mac.zipinfo" > "$C/$z/zipinfo.diff"; }
done
# The export: each of its files against the same path under the release's wwwroot/.
w=$R/unz/ws-pems-linux-x64/ws-pems-linux-x64/wwwroot
hashes "$L/frontend-out" > "$C/export-mac.sha256"
( cd "$w" && sed 's/^[0-9a-f]*  //' "$C/export-mac.sha256" | tr '\n' '\0' | xargs -0 shasum -a 256 ) > "$C/export-release.sha256" 2> "$C/export-missing.txt"
if cmp -s "$C/export-release.sha256" "$C/export-mac.sha256"; then
  echo "same  frontend export against the release's wwwroot/ ($(wc -l < "$C/export-mac.sha256" | tr -d ' ') files)"
else
  echo "DIFF  frontend export against the release's wwwroot/ ($(wc -l < "$C/export-mac.sha256" | tr -d ' ') files)"
  diff "$C/export-release.sha256" "$C/export-mac.sha256" > "$C/export.diff"; grep -c '^[<>]' "$C/export.diff" | sed 's/^/      lines differing: /'
fi
