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
#
# Added 14 October: when the run signed the Windows binaries with a
# throwaway certificate (the artifact thesis-test-ca), the local unsigned
# build gets CI's signatures pasted, as deployment/signing/README.md says a
# rebuild is checked: paste-signatures.sh in SIGNING_IMAGE, then the
# commit's pack-release-zip.sh; its zips and migrator are compared with
# CI's. Also the SQL script, all five images, and SHA256SUMS, written here
# over the local outputs with the release job's command. CLONE is a clone
# of the tag (for the packing script, the signing root and upgrade.sh).
set -u
P=${1:?P} TAG=${2:?TAG}
CLONE=${CLONE:-/private/tmp/rb1-ci/windows} SIGNING_IMAGE=${SIGNING_IMAGE:-ws-signing:rb-dry}
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
mig=ws-pems-db-migrator-win-x64-$TAG.exe
win=$L/windows
if [ -f "$C/thesis-test-ca/ca.pem" ]; then
  W=$R/windows; win=$W/zips
  mkdir -p "$W/ci" "$W/local" "$W/keys" "$win"
  for z in ws-pems-win-x64 ws-pems-job-worker-win-x64; do
    unzip -q "$C/release-zips-windows/$z-$TAG.zip" -d "$W/ci" && unzip -q "$L/windows/$z-$TAG.zip" -d "$W/local"
  done
  # A downloaded migrator has no mode; both get 0644, as the README says.
  cp "$C/db-migration-bundles-windows/$mig" "$W/ci/" && cp "$L/windows/$mig" "$W/local/" && chmod 644 "$W/ci/$mig" "$W/local/$mig"
  cat "$C/thesis-test-ca/ca.pem" "$CLONE/deployment/signing/microsoft-identity-verification-root-2020.pem" > "$W/keys/verify.pem"
  docker run --rm --user "$(id -u):$(id -g)" -v "$W:$W" -w "$W" -e VERIFY_CAFILE="$W/keys/verify.pem" \
    --entrypoint /opt/signing/paste-signatures.sh "$SIGNING_IMAGE" ci local pasted > "$R/paste.log" 2>&1
  echo "paste-signatures.sh, CI's signatures onto the local build: exit $?, $(tail -1 "$R/paste.log")"
  epoch=$(git -C "$CLONE" log -1 --format=%ct)
  ( cd "$W/pasted" && for z in ws-pems-win-x64 ws-pems-job-worker-win-x64; do
      env PATH=/private/tmp/rb1-tools:/usr/bin SOURCE_DATE_EPOCH="$epoch" "$CLONE/scripts/pack-release-zip.sh" "$z" "$win/$z-$TAG.zip" || exit 1
    done ) > "$R/pack-pasted.log" 2>&1
  cp "$W/pasted/$mig" "$win/"
fi
for z in ws-pems-win-x64 ws-pems-job-worker-win-x64; do
  same "$C/release-zips-windows/$z-$TAG.zip" "$win/$z-$TAG.zip" "$z-$TAG.zip" \
    || zipdiff "$C/release-zips-windows/$z-$TAG.zip" "$win/$z-$TAG.zip" "$z"
done

same "$C/db-migration-bundles-linux/ws-pems-db-migrator-linux-x64-$TAG" \
  "$L/migrator/ws-pems-db-migrator-linux-x64-$TAG" "ws-pems-db-migrator-linux-x64-$TAG"
same "$C/db-migration-bundles-windows/$mig" "$win/$mig" "$mig"
if [ -f "$L/migrator/bootstrap-postgresql-$TAG.sql" ]; then
  same "$C/db-migration-bundles-linux/bootstrap-postgresql-$TAG.sql" "$L/migrator/bootstrap-postgresql-$TAG.sql" "bootstrap-postgresql-$TAG.sql"
fi
if [ -f "$C/sha256sums/SHA256SUMS" ]; then
  S=$R/sums; mkdir -p "$S/db"
  cp "$L/linux/"*.zip "$win/"*.zip "$S/" && cp "$L/migrator/"* "$win/$mig" "$S/db/" && cp "$CLONE/scripts/upgrade.sh" "$S/"
  ( cd "$S" && export LC_ALL=C && sha256sum *.zip db/* upgrade.sh > SHA256SUMS )
  same "$C/sha256sums/SHA256SUMS" "$S/SHA256SUMS" "SHA256SUMS ($(wc -l < "$S/SHA256SUMS") lines)" \
    || diff "$C/sha256sums/SHA256SUMS" "$S/SHA256SUMS"
fi

for n in ws-pems ws-pems-job-worker wspems-mcp-server wspems-chat-server wspems-mcp-auth-broker; do
  [ -f "$C/image-$n/$n.oci.tar" ] || continue
  python3 "$here/oci-diff.py" "$C/image-$n/$n.oci.tar" "$L/images/$n.oci.tar" > "$R/$n-image-diff.txt" 2>&1
  echo "image $n: $(head -1 "$R/$n-image-diff.txt")"
done
