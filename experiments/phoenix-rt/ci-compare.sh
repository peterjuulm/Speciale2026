#!/bin/bash
# A CI run's artifacts against ci-local.sh's rebuild (written 13 October 2026).
#
#   ci-compare.sh P TAG
#
# P holds ci/, the run's artifacts as `gh run download` writes them (one
# folder per artifact), and local/, ci-local.sh's outputs. One line per
# output: "same" or "DIFF". For a zip that differs, the entries are
# compared too: their names, contents (from the unpacked trees) and
# metadata (zipinfo -v, one listing per side). Images are compared with
# oci-diff.py. Everything lands in P/compare.
set -u
P=${1:?P} TAG=${2:?TAG}
here=$(cd "$(dirname "$0")" && pwd)
C=$P/ci L=$P/local R=$P/compare
rm -rf "$R" && mkdir -p "$R"

hashes() { ( cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum ); }
same() { if cmp -s "$1" "$2"; then echo "same  $3"; return 0; else echo "DIFF  $3"; return 1; fi; }
zipdiff() {  # ci zip, local zip, label
  local u=$R/unzipped/$3
  mkdir -p "$u/ci" "$u/local"
  unzip -q "$1" -d "$u/ci" && unzip -q "$2" -d "$u/local"
  hashes "$u/ci" > "$u/ci.sha256"; hashes "$u/local" > "$u/local.sha256"
  same "$u/ci.sha256" "$u/local.sha256" "  $3: entries' contents ($(wc -l < "$u/ci.sha256") / $(wc -l < "$u/local.sha256") files)" \
    || diff "$u/ci.sha256" "$u/local.sha256" | head -20
  zipinfo -v "$1" | tail -n +2 > "$u/ci.zipinfo"; zipinfo -v "$2" | tail -n +2 > "$u/local.zipinfo"
  same "$u/ci.zipinfo" "$u/local.zipinfo" "  $3: zipinfo -v" || diff "$u/ci.zipinfo" "$u/local.zipinfo" | head -20
}

hashes "$C/frontend-export" > "$R/frontend-ci.sha256"
hashes "$L/frontend-out" > "$R/frontend-local.sha256"
same "$R/frontend-ci.sha256" "$R/frontend-local.sha256" \
  "frontend export ($(wc -l < "$R/frontend-ci.sha256") / $(wc -l < "$R/frontend-local.sha256") files)" \
  || diff "$R/frontend-ci.sha256" "$R/frontend-local.sha256" | head -20

for z in ws-pems-linux-x64 ws-pems-job-worker-linux-x64; do
  same "$C/release-zips-linux/$z-$TAG.zip" "$L/linux/$z-$TAG.zip" "$z-$TAG.zip" \
    || zipdiff "$C/release-zips-linux/$z-$TAG.zip" "$L/linux/$z-$TAG.zip" "$z"
done
for z in ws-pems-win-x64 ws-pems-job-worker-win-x64; do
  same "$C/release-zips-windows/$z-$TAG.zip" "$L/windows/$z-$TAG.zip" "$z-$TAG.zip" \
    || zipdiff "$C/release-zips-windows/$z-$TAG.zip" "$L/windows/$z-$TAG.zip" "$z"
done

same "$C/db-migration-bundles-linux/ws-pems-db-migrator-linux-x64-$TAG" \
  "$L/migrator/ws-pems-db-migrator-linux-x64-$TAG" "ws-pems-db-migrator-linux-x64-$TAG"
same "$C/db-migration-bundles-windows/ws-pems-db-migrator-win-x64-$TAG.exe" \
  "$L/windows/ws-pems-db-migrator-win-x64-$TAG.exe" "ws-pems-db-migrator-win-x64-$TAG.exe"

for n in ws-pems ws-pems-job-worker; do
  python3 "$here/oci-diff.py" "$C/image-$n/$n.oci.tar" "$L/images/$n.oci.tar" > "$R/$n-image-diff.txt" 2>&1
  echo "image $n: $(head -1 "$R/$n-image-diff.txt")"
done
