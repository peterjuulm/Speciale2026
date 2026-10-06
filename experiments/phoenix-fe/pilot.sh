#!/bin/bash
#
# Layer 3 pilot: build Phoenix's frontend twice in the same folder and keep
# both static exports.
#
#   OUT=<private folder> pilot.sh
#
# Each build starts from a fresh git archive of the whole commit, always at
# the same path, installs from the filled npm cache without network, and runs
# the release's build command. The whole commit, because the frontend imports
# code from mcp/ and src/WebAPI/utilities/, outside ClientApp. OUT gets, per
# build N, out-N/ (a copy of the export), out-N.sha256, build-id-N and
# build-N.log, and once environment.txt and compare.txt.
#
# Fill the npm cache first; see notes/2026-10-06-phoenix-layer3.md.

set -uo pipefail

repo=/home/leos/Dev/Weel-Sandvig/WS.Phoenix-repro
commit=4e5237a33b5737f6f781bb3ee85cec540309833f
lab=/private/tmp/rb1-fe
app=$lab/src/WebAPI/ClientApp
node_bin=/opt/rb1-node/bin
cache=/private/tmp/rb1-npm
here=$(cd "$(dirname "$0")" && pwd)

if [ -z "${OUT:-}" ]; then
    echo "pilot.sh: set OUT to a private data folder" >&2
    exit 1
fi
for n in 1 2; do
    if [ -e "$OUT/out-$n" ]; then
        echo "pilot.sh: $OUT/out-$n exists" >&2
        exit 2
    fi
done
mkdir -p "$OUT"

# The build's whole environment. LANG and CI are what GitHub's runner sets;
# the last three keep npm and Next.js off the network.
build_env=(env -i HOME="$HOME" PATH="$node_bin:/usr/bin" LANG=C.UTF-8 CI=true
    npm_config_cache="$cache" npm_config_update_notifier=false
    NEXT_TELEMETRY_DISABLED=1)
build='npm ci --offline --no-audit --no-fund && npm run build'

{
    date -Is
    uname -srm
    echo "umask $(umask), $(nproc) CPUs"
    echo "node $("$node_bin/node" --version), npm $(PATH="$node_bin:/usr/bin" npm --version)"
    sha256sum "$node_bin/node"
    echo "next $(git -C "$repo" show "$commit:src/WebAPI/ClientApp/package-lock.json" |
        python3 -c 'import json, sys; print(json.load(sys.stdin)["packages"]["node_modules/next"]["version"])')"
    echo "commit $commit"
    echo "npm cache $cache, $(du -sh "$cache" | cut -f1)"
    echo "build environment: ${build_env[*]:2}"
    echo "build command: $build"
} > "$OUT/environment.txt"

for n in 1 2; do
    rm -rf "$lab"
    mkdir -p "$lab"
    git -C "$repo" archive "$commit" | tar -x -C "$lab" || exit 1

    echo "build $n started $(date -Is)"
    (cd "$app" && "${build_env[@]}" sh -c "$build") > "$OUT/build-$n.log" 2>&1
    status=$?
    echo "build $n exit $status $(date -Is)"
    if [ $status != 0 ]; then
        echo "pilot.sh: build $n failed, see $OUT/build-$n.log" >&2
        exit 1
    fi

    cp "$app/.next/BUILD_ID" "$OUT/build-id-$n"
    (cd "$app" && find out -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) > "$OUT/out-$n.sha256"
    cp -a "$app/out" "$OUT/out-$n"
done

python3 "$here/compare-out.py" "$OUT/out-1" "$OUT/out-2" \
    "$(cat "$OUT/build-id-1")" "$(cat "$OUT/build-id-2")" | tee "$OUT/compare.txt"
