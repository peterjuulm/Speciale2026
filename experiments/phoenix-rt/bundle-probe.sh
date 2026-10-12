#!/bin/bash
# The EF Core migration bundle, built twice (written 12 October 2026).
#
# 03-release.yml's migration-bundles job builds the Linux migrator with
# `dotnet ef migrations bundle`. This builds it twice with the job's
# commands and environment, each time from a fresh copy of the same export
# at the same path, and compares the two bundles. No reprotest: the
# question is whether two plain builds already differ.
#
#   OUT=<private folder> bundle-probe.sh COMMIT
#
# DOTNET_DIR selects the SDK (default Microsoft's 10.0.401 in
# /private/tmp/rb1-dotnet10/sdk). OUT gets build-N/ws-pems-db-migrator
# (the migrator; one file name for both builds, since dotnet ef names the
# bundle's own assembly after it), bundle-N.log, bundle-N.sha256 and the
# export's labcheck line.
# PRE_RESTORE=1 first restores the solution in locked mode, without
# SkipLockedRestore: dotnet-ef 10 reads project metadata before it builds,
# and on a fresh tree that fails (NETSDK1004, measured 13/10).
set -u
OUT=${OUT:?set OUT to a private data folder}
commit=${1:?COMMIT}
DN=${DOTNET_DIR:-/private/tmp/rb1-dotnet10/sdk}
repo=/home/leos/Dev/Weel-Sandvig/WS.Phoenix-repro
here=$(cd "$(dirname "$0")" && pwd)
tree=/private/tmp/rb1-bundle-tree build=/private/tmp/rb1-bundle
mkdir -p "$OUT"
rm -rf "$tree" && mkdir -p "$tree"
git -C "$repo" archive "$commit" -- . ':(exclude).claude' | tar -x -C "$tree"
python3 "$here/../labcheck.py" "$repo" "$commit" "$tree" | tail -1 | tee "$OUT/labcheck.txt"
ENV=(env -i HOME="$HOME" USER="$USER" LOGNAME="$LOGNAME" SHELL=/bin/bash PATH="$DN:/usr/local/bin:/usr/bin"
     DOTNET_ROOT="$DN" DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1
     MSBUILDDISABLENODEREUSE=1 LC_ALL=C.UTF-8 SkipLockedRestore=true)
for n in 1 2; do
  rm -rf "$build" && cp -a "$tree" "$build" && mkdir -p "$OUT/build-$n"
  pre=true
  [ "${PRE_RESTORE:-}" = 1 ] && pre='env -u SkipLockedRestore dotnet restore WS.Phoenix.sln --locked-mode'
  ( cd "$build" && "${ENV[@]}" bash -c "$pre"' && dotnet tool restore && dotnet ef migrations bundle --context DatabaseContext \
      -p src/Infrastructure/Infrastructure.csproj -s src/WebAPI/WebAPI.csproj \
      --self-contained -r linux-x64 --force -o "$0"' "$OUT/build-$n/ws-pems-db-migrator" ) > "$OUT/bundle-$n.log" 2>&1
  echo "bundle-$n exit $? $(date +%H:%M:%S)"
  [ -f "$OUT/build-$n/ws-pems-db-migrator" ] && sha256sum "$OUT/build-$n/ws-pems-db-migrator" | cut -c1-64 > "$OUT/bundle-$n.sha256"
  "${ENV[@]}" dotnet build-server shutdown > /dev/null 2>&1
done
rm -rf "$build"
cmp -s "$OUT/build-1/ws-pems-db-migrator" "$OUT/build-2/ws-pems-db-migrator" && echo "bundles identical" || echo "bundles differ"
