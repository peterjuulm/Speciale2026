# The Mac Studio, 24 November evening: scripts/release/rebuild.sh (from the
# branch's tip) against dry run 5 (GitHub run RUN, commit 8491a0d63,
# v0.0.0-dryrun.5), in a Linux x86-64 container under Rosetta in colima (a
# vz VM, aarch64), since rebuild.sh needs Linux x64. The container
# (rb1-verifier:amd64: Ubuntu 24.04 with git, python3, curl, unzip, zip, and
# Docker's CLI and buildx) reaches the VM's Docker through its socket; the
# work folder is a Docker volume mounted at the same path inside and
# outside, so the paste's docker run finds it. DOCKER_DEFAULT_PLATFORM=
# linux/amd64, so the builder rebuild.sh makes runs BuildKit as x86-64 too.
# The source is read from Leo's WS.Phoenix repository (read-only mount).
# The first try (dry run 5, 24/11 afternoon) built the images for arm64:
# rebuild.sh runs each job under env -i, which drops DOCKER_DEFAULT_PLATFORM,
# so buildx took the VM's own platform. The second try then ran the x86-64
# steps under BuildKit's bundled QEMU, where dotnet restore aborted and the
# build hung. PATCH=1 applies mac-verifier/patch-rebuild.sh to the
# verifier's checkout only: the platform passed through, and BuildKit's
# QEMU moved aside so that Rosetta runs the steps.
set -uo pipefail
RUN=${RUN:-45403522195} T=${T:-v0.0.0-dryrun.5} TIP=${TIP:-96e2990a6} H=$HOME/rb1-mac-t7/${NAME:-dry5}
export PATH=/private/tmp/rb1-ms-docker/bin:$PATH DOCKER_CONFIG=/private/tmp/rb1-ms-docker/config
# REUSE=1 keeps the assets of an earlier try (macOS bash 3.2 failed on the
# empty ca array under set -u, 24/11 19:24, after the download).
if [ -n "${REUSE:-}" ] && [ -d "$H/assets" ]; then find "$H" -mindepth 1 -maxdepth 1 ! -name assets ! -name run -exec rm -rf {} +; else rm -rf "$H"; mkdir -p "$H/assets"; fi
if [ -n "${REUSE:-}" ] && [ "$(ls "$H/assets" | wc -l)" -gt 0 ]; then
  ca=()
  [ -z "${PUBLISHED:-}" ] && ca=(-e SIGNING_CA=/host/run/thesis-test-ca/ca.pem -e ALLOW_UNTAGGED=1)
elif [ -z "${PUBLISHED:-}" ]; then
  for a in dry-run-release thesis-test-ca; do gh run download $RUN -R Weel-Sandvig/WS.Phoenix -n $a -D "$H/run/$a" > /dev/null || echo "FAILED $a"; done
  find "$H/run/dry-run-release/release" -type f -exec cp {} "$H/assets/" \;
  ca=(-e SIGNING_CA=/host/run/thesis-test-ca/ca.pem -e ALLOW_UNTAGGED=1)
else
  gh release download "$T" -R Weel-Sandvig/WS.Phoenix -D "$H/assets" > /dev/null || echo "FAILED release download"
  ca=()
fi
echo "assets: $(ls "$H/assets" | wc -l) files"
vol=rb1${NAME:-dry5}; docker volume rm "$vol" > /dev/null 2>&1; docker volume create "$vol" > /dev/null
V=/var/lib/docker/volumes/$vol/_data
# NO_OUTER_PLATFORM=1 (25/11, step 76): the container gets no
# DOCKER_DEFAULT_PLATFORM, as a user would run it; rebuild.sh from 1c90ad428
# on sets the platform itself when Docker is not x86_64.
pe=(-e DOCKER_DEFAULT_PLATFORM=linux/amd64); [ -n "${NO_OUTER_PLATFORM:-}" ] && pe=()
echo "== rebuild.sh in the x86-64 container $(date +%H:%M:%S)"
docker run --rm --platform linux/amd64 ${pe[@]+"${pe[@]}"} -e ASSETS=/host/assets ${ca[@]+"${ca[@]}"} \
  -v /var/run/docker.sock:/var/run/docker.sock -v "$vol:$V" -v "$H:/host" -v "$HOME/Dev/Weel-Sandvig/WS.Phoenix:/repo:ro" -v "$(cd "$(dirname "$0")" && pwd)/mac-verifier:/lab:ro" \
  rb1-verifier:amd64 bash -c "
    git clone -q --no-checkout /repo $V/src && git -C $V/src checkout -q --detach $TIP && echo \"verifier: \$(git -C $V/src log -1 --format='%h %s')\"
    if [ -n \"${PATCH:-}\" ]; then bash /lab/patch-rebuild.sh $V/src/scripts/release/rebuild.sh && git -C $V/src diff | grep '^[+-] '; fi
    uname -m; $V/src/scripts/release/rebuild.sh $T $V/work > /host/rebuild.log 2>&1; echo \"rebuild exit \$?\"
    grep -E '^== |SAME|DIFFERENT|^  pkg|published' /host/rebuild.log | tail -14
    cp $V/work/build-manifest.json /host/build-manifest-rebuilt.json 2>/dev/null
    (cd $V/work/release 2>/dev/null && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) > /host/release.sha256
    for f in $V/work/images/*.oci.tar; do printf '%s ' \$(basename \$f); tar -xOf \$f index.json | python3 -c 'import json,sys; print(json.load(sys.stdin)[\"manifests\"][0][\"digest\"])'; done > /host/images.txt
  "
echo "== done $(date +%H:%M:%S)"
