#!/bin/bash
# The release's .NET images built twice (written 13 October 2026).
#
# Exports COMMIT to a fresh lab, builds the frontend export there as CI's
# frontend job does (APP_VERSION from the tag), then builds each image twice
# with buildx's docker-container driver, as setup-buildx-action sets it up in
# CI, without cache and without provenance, into OCI tarballs, and compares
# them with oci-diff.py. With EPOCH=<seconds> the builds also get
# SOURCE_DATE_EPOCH and the exporter's rewrite-timestamp=true, the fix the
# layer plan names for layer 5.
#
#   OUT=<private folder> [EPOCH=<s>] image-probe.sh COMMIT LABEL
#
# DOCKER_CONFIG must hold buildx (a builder named rb1). TAG is the version
# the release passes as APP_VERSION. IMAGES is "webapi worker" by default.
# The OCI tarballs land in /private/tmp/rb1-img-out/LABEL, outside the data
# folder; OUT keeps the logs and the comparisons.
set -u
OUT=${OUT:?set OUT to a private data folder}
commit=${1:?COMMIT} label=${2:?LABEL}
here=$(cd "$(dirname "$0")" && pwd)
repo=/home/leos/Dev/Weel-Sandvig/WS.Phoenix-repro
lab=/private/tmp/rb1-img/x TAG=${TAG:-v0.0.0-thesis} IMAGES=${IMAGES:-webapi worker}
NODE=${NODE_DIR:-/private/tmp/rb1-node22}
O=$OUT/$label; T=/private/tmp/rb1-img-out/$label; mkdir -p "$O" "$T"
docker buildx inspect rb1 > /dev/null || { echo "no buildx builder rb1 (DOCKER_CONFIG)"; exit 2; }
# The marker sits beside the lab, not in it: the lab is the build context.
if [ ! -d "$lab/src/WebAPI/ClientApp/out" ] || [ "$(cat /private/tmp/rb1-img/commit 2>/dev/null)" != "$commit" ]; then
  rm -rf /private/tmp/rb1-img && mkdir -p "$lab"
  git -C "$repo" archive "$commit" -- . ':(exclude).claude' | tar -x -C "$lab"
  python3 "$here/../labcheck.py" "$repo" "$commit" "$lab" | tail -1 | tee "$O/labcheck.txt"
  ( cd "$lab/src/WebAPI/ClientApp" && env -i HOME=/private/tmp/rb1-img PATH="$NODE/bin:/usr/bin" CI=true \
      npm_config_cache=/private/tmp/rb1-npm npm_config_update_notifier=false NEXT_TELEMETRY_DISABLED=1 \
      APP_VERSION="$TAG" LC_ALL=C.UTF-8 sh -c 'npm ci --offline --no-audit --no-fund && npm run build && rm -rf node_modules .next' ) > "$O/frontend.log" 2>&1 \
    || { echo "frontend build failed"; exit 1; }
  echo "$commit" > /private/tmp/rb1-img/commit
fi
args=(--build-arg "APP_VERSION=$TAG")
outopt=""
if [ -n "${EPOCH:-}" ]; then args+=(--build-arg "SOURCE_DATE_EPOCH=$EPOCH"); outopt=",rewrite-timestamp=true"; fi
for img in $IMAGES; do
  case $img in
    webapi) file=src/WebAPI/Dockerfile; extra=(--build-arg SKIP_SPA_BUILD=true) ;;
    worker) file=src/BackgroundJobExecutor/Dockerfile; extra=() ;;
    *) echo "unknown image $img"; exit 2 ;;
  esac
  for n in 1 2; do
    docker buildx build --builder rb1 --no-cache --provenance=false -f "$lab/$file" "${args[@]}" "${extra[@]}" \
      --output "type=oci,dest=$T/$img-$n.oci.tar$outopt" "$lab" > "$O/$img-$n.log" 2>&1
    echo "$img-$n exit $? $(date +%T)"
  done
  python3 "$here/oci-diff.py" "$T/$img-1.oci.tar" "$T/$img-2.oci.tar" > "$O/$img-diff.txt" 2>&1
  head -3 "$O/$img-diff.txt"
done
