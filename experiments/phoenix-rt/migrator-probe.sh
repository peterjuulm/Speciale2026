#!/bin/bash
# The database migrator, src/DbMigrator, built twice (written 13 October 2026).
#
# Exports COMMIT to two fresh labs at different paths, restores the solution
# locked as the release does (GITHUB_ACTIONS=true), publishes the migrator for
# linux-x64 and win-x64 with the release jobs' commands, and compares the two
# builds byte for byte. The win-x64 file is cross-built here and unsigned.
#
#   OUT=<private folder> migrator-probe.sh COMMIT
#
# DOTNET_DIR selects the SDK (default Microsoft's 10.0.401 in
# /private/tmp/rb1-dotnet10/sdk). APP_VERSION is v9.9.9 in both builds, as a
# release tag would set it. The labs stay for later runs.
set -u
OUT=${OUT:?set OUT to a private data folder}
commit=${1:?COMMIT}
DN=${DOTNET_DIR:-/private/tmp/rb1-dotnet10/sdk}
repo=/home/leos/Dev/Weel-Sandvig/WS.Phoenix-repro
here=$(cd "$(dirname "$0")" && pwd)
tops=(/private/tmp/rb1-mig-a /private/tmp/rb1-mig-bb)
labs=(/private/tmp/rb1-mig-a/x /private/tmp/rb1-mig-bb/longer/path/x)
mkdir -p "$OUT"
ENV=(env -i HOME="$HOME" USER="$USER" LOGNAME="$LOGNAME" SHELL=/bin/bash PATH="$DN:/usr/local/bin:/usr/bin"
     DOTNET_ROOT="$DN" DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1
     MSBUILDDISABLENODEREUSE=1 LC_ALL=C.UTF-8 GITHUB_ACTIONS=true APP_VERSION=v9.9.9)
for n in 1 2; do
  top=${tops[$((n-1))]} lab=${labs[$((n-1))]}
  rm -rf "$top" && mkdir -p "$lab"
  git -C "$repo" archive "$commit" -- . ':(exclude).claude' | tar -x -C "$lab"
  python3 "$here/../labcheck.py" "$repo" "$commit" "$lab" | tail -1 | tee "$OUT/labcheck-$n.txt"
  ( cd "$lab" && "${ENV[@]}" bash -c '
      dotnet restore ./WS.Phoenix.sln &&
      dotnet publish ./src/DbMigrator/DbMigrator.csproj -c Release -o ./publish/migrator -r linux-x64 --self-contained true --no-restore &&
      dotnet publish ./src/DbMigrator/DbMigrator.csproj -c Release -o ./publish/migrator-win -r win-x64 --self-contained true --no-restore' ) > "$OUT/build-$n.log" 2>&1
  echo "build-$n exit $? $(date +%H:%M:%S)"
  mkdir -p "$OUT/build-$n"
  cp "$lab/publish/migrator/ws-pems-db-migrator" "$lab/publish/migrator-win/ws-pems-db-migrator.exe" "$OUT/build-$n/"
  (cd "$OUT/build-$n" && sha256sum ws-pems-db-migrator ws-pems-db-migrator.exe) > "$OUT/build-$n.sha256"
  "${ENV[@]}" dotnet build-server shutdown > /dev/null 2>&1
done
for f in ws-pems-db-migrator ws-pems-db-migrator.exe; do
  cmp -s "$OUT/build-1/$f" "$OUT/build-2/$f" && echo "$f identical" || echo "$f differs"
done
