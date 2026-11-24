#!/bin/bash
#
# fe-build.sh COMMIT NODE_DIR LAB OUT
#
# One build of stage 3 (the frontend's static export) of COMMIT, as
# dotnet-rebuild-experiments/1-ws-pems/scripts/3-frontend/build.sh does it:
# the lab is made fresh from git archive, as shared/make-lab.sh makes it,
# outside any git repository, and build.sh runs in it under env -i with
# HOME, PATH and NODE_DIR. npm ci runs offline from /private/tmp/rb1-npm.
#
#   OUT.hashes.sha256   build.sh's hashes of every file under out/
#   OUT.log             build.sh's output, with Node's and npm's versions
#
# REPO is the WS.Phoenix clone (default ~/Dev/Weel-Sandvig/WS.Phoenix).
#
# Written 23 November 2026 for the npm pin (E1-S3-08).

set -euo pipefail
[ $# -eq 4 ] || { echo "usage: fe-build.sh COMMIT NODE_DIR LAB OUT" >&2; exit 1; }
commit=$1 node_dir=$2 lab=$3 out=$4
repo=${REPO:-$HOME/Dev/Weel-Sandvig/WS.Phoenix}
build=$HOME/Dev/leosakharoff/dotnet-rebuild-experiments/1-ws-pems/scripts/3-frontend/build.sh

commit=$(git -C "$repo" rev-parse --verify "$commit^{commit}")
rm -rf "$lab"
mkdir -p "$lab"
git -C "$repo" archive "$commit" -- . ':(exclude).claude' | tar -x -C "$lab"
if git -C "$lab" rev-parse --git-dir > /dev/null 2>&1; then
    echo "fe-build.sh: $lab is inside a git repository" >&2
    exit 1
fi
{
    echo "commit $commit"
    echo "lab $lab"
    echo "node $("$node_dir/bin/node" --version), npm $(PATH="$node_dir/bin:/usr/bin:/bin" npm --version)"
    echo "build.sh sha256 $(shasum -a 256 "$build" | cut -d' ' -f1)"
    echo "start $(date -u +%FT%TZ)"
} > "$out.log"
(cd "$lab" && env -i HOME="$HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin NODE_DIR="$node_dir" \
    bash "$build") >> "$out.log" 2>&1
echo "end $(date -u +%FT%TZ)" >> "$out.log"
cp "$lab/hashes.sha256" "$out.hashes.sha256"
echo "$out: $(wc -l < "$out.hashes.sha256") files"
