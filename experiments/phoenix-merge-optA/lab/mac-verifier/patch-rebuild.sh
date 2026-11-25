#!/bin/bash
# patch-rebuild.sh REBUILD_SH: the two Mac-only changes to a checkout of
# scripts/release/rebuild.sh, made in the verifier's own clone (never in a
# WS repository), 24 November 2026. Neither is on the branch.
#
# 1. run() passes DOCKER_DEFAULT_PLATFORM through its env -i. Without it,
#    buildx builds for the VM's own platform, linux/arm64 (dry run 5, try 2:
#    the arm64 canvas prebuilt then fails mcp-server's tests on libexpat).
# 2. Right after rebuild.sh starts its builder, BuildKit's bundled QEMU for
#    x86-64 is moved aside in the builder's container, so that the kernel
#    hands the x86-64 steps to Rosetta, as in the Rosetta note of 24/11
#    (2026-11-24-rosetta-cache-layer.md). Under BuildKit's QEMU, dotnet
#    restore aborts (signal 6) and the build hangs (dry run 5, try 3).
set -euo pipefail
f=$1
sed -i 's/\${DOCKER_HOST:+DOCKER_HOST=/${DOCKER_DEFAULT_PLATFORM:+DOCKER_DEFAULT_PLATFORM="$DOCKER_DEFAULT_PLATFORM"} &/' "$f"
sed -i '/^trap .docker buildx rm "\$builder"/a docker exec "buildx_buildkit_${builder}0" mv /usr/bin/buildkit-qemu-x86_64 /usr/bin/buildkit-qemu-x86_64.off || die "could not move BuildKit'"'"'s QEMU aside"' "$f"
grep -c 'DOCKER_DEFAULT_PLATFORM:+' "$f" | grep -qx 1 || { echo "patch 1 did not apply" >&2; exit 1; }
grep -q 'buildkit-qemu-x86_64.off' "$f" || { echo "patch 2 did not apply" >&2; exit 1; }
