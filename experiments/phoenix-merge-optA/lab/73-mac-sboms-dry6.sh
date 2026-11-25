# The Mac Studio, 24 November, late: the SBOM zip again from the rebuilt
# files of dry run 6 (rebuild.sh's work volume rb1dry6, lab step 70), with
# sboms.sh from the branch plus one change not yet committed: a single file
# (a migrator) copied into the scan context gets mode 0644. In step 70 the
# Linux migrator's SBOM differed from GitHub's only in the layerID comment:
# the rebuilt migrator was 0755, the runner's (an artifact download) 0644.
# Expected now: the zip GitHub's runners made twice, 68926ca8.
# Same builder setup as rebuild.sh under PATCH=1: the pinned BuildKit,
# linux/amd64, BuildKit's QEMU moved aside so that Rosetta runs the scanner.
set -uo pipefail
C=${C:-48c5b3cba} V=/var/lib/docker/volumes/rb1dry6/_data
SB=${SB:?path to the changed sboms.sh}
export PATH=/private/tmp/rb1-ms-docker/bin:$PATH DOCKER_CONFIG=/private/tmp/rb1-ms-docker/config
epoch=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["predicate"]["buildDefinition"]["externalParameters"]["env"]["SOURCE_DATE_EPOCH"])' "$HOME/rb1-mac-t7/dry6/assets/build-manifest.json")
docker run --rm --platform linux/amd64 -e DOCKER_DEFAULT_PLATFORM=linux/amd64 -v /var/run/docker.sock:/var/run/docker.sock \
  -v "rb1dry6:$V" -v "$HOME/Dev/Weel-Sandvig/WS.Phoenix:/repo:ro" -v "$SB:/sboms.sh:ro" rb1-verifier:amd64 bash -c "
    set -e
    git clone -q --no-checkout /repo /src && git -C /src checkout -q --detach $C && cp /sboms.sh /src/scripts/release/sboms.sh
    git -C /src diff --stat
    bk=\$(sed -n 's/^  BUILDKIT_IMAGE: //p' /src/.github/workflows/03-release.yml)
    docker buildx create --name sb73 --driver docker-container --driver-opt image=\$bk --bootstrap > /dev/null 2>&1
    docker exec buildx_buildkit_sb730 mv /usr/bin/buildkit-qemu-x86_64 /usr/bin/buildkit-qemu-x86_64.off
    (cd /src && BUILDX_BUILDER=sb73 APP_VERSION=v0.0.0-dryrun.6 SOURCE_DATE_EPOCH=$epoch scripts/release/sboms.sh $V/work/release $V/work/images /tmp/out) > /tmp/sb.log 2>&1 || { tail -30 /tmp/sb.log; }
    grep -E '^== |packages|sbom-|^[0-9a-f]{64}  ' /tmp/sb.log
    docker buildx rm sb73 > /dev/null 2>&1 || true
  "
echo "== done $(date +%H:%M:%S)"
