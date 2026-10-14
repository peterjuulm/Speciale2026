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
# the release passes as APP_VERSION. IMAGES is "webapi worker" by default;
# "migrations mcp chat broker" are the migrations image and the three MCP
# images (added 14 October), each from its own context as the release and
# scripts/docker-build-push.sh build them. Only webapi needs the export.
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
case " $IMAGES " in *" webapi "*) need_export=1 ;; *) need_export=0 ;; esac
# The marker sits beside the lab, not in it: the lab is the build context.
if [ "$(cat /private/tmp/rb1-img/commit 2>/dev/null)" != "$commit" ] || { [ $need_export = 1 ] && [ ! -d "$lab/src/WebAPI/ClientApp/out" ]; }; then
  rm -rf /private/tmp/rb1-img && mkdir -p "$lab"
  git -C "$repo" archive "$commit" -- . ':(exclude).claude' | tar -x -C "$lab"
  python3 "$here/../labcheck.py" "$repo" "$commit" "$lab" | tail -1 | tee "$O/labcheck.txt"
  if [ $need_export = 1 ]; then
    ( cd "$lab/src/WebAPI/ClientApp" && env -i HOME=/private/tmp/rb1-img PATH="$NODE/bin:/usr/bin" CI=true \
        npm_config_cache=/private/tmp/rb1-npm npm_config_update_notifier=false NEXT_TELEMETRY_DISABLED=1 \
        APP_VERSION="$TAG" LC_ALL=C.UTF-8 sh -c 'npm ci --offline --no-audit --no-fund && npm run build && rm -rf node_modules .next' ) > "$O/frontend.log" 2>&1 \
      || { echo "frontend build failed"; exit 1; }
  fi
  echo "$commit" > /private/tmp/rb1-img/commit
fi
args=()
outopt=""
if [ -n "${EPOCH:-}" ]; then args+=(--build-arg "SOURCE_DATE_EPOCH=$EPOCH"); outopt=",rewrite-timestamp=true"; fi
version=(--build-arg "APP_VERSION=$TAG")
for img in $IMAGES; do
  ctx=$lab
  case $img in
    webapi) file=src/WebAPI/Dockerfile; extra=("${version[@]}" --build-arg SKIP_SPA_BUILD=true) ;;
    worker) file=src/BackgroundJobExecutor/Dockerfile; extra=("${version[@]}") ;;
    migrations) file=deployment/migrations/Dockerfile; extra=("${version[@]}") ;;
    mcp) file=mcp/Dockerfile; ctx=$lab/mcp; extra=() ;;
    chat) file=mcp/chat-server/Dockerfile; ctx=$lab/mcp; extra=() ;;
    broker) file=mcp/auth-broker/Dockerfile; ctx=$lab/mcp/auth-broker; extra=() ;;
    *) echo "unknown image $img"; exit 2 ;;
  esac
  for n in 1 2; do
    docker buildx build --builder rb1 --no-cache --provenance=false -f "$lab/$file" "${args[@]}" "${extra[@]}" \
      --output "type=oci,dest=$T/$img-$n.oci.tar$outopt" "$ctx" > "$O/$img-$n.log" 2>&1
    echo "$img-$n exit $? $(date +%T)"
  done
  python3 "$here/oci-diff.py" "$T/$img-1.oci.tar" "$T/$img-2.oci.tar" > "$O/$img-diff.txt" 2>&1
  head -3 "$O/$img-diff.txt"
done
