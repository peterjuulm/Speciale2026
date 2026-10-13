#!/bin/bash
# PR validation's migration guard on a fresh export (written 13 October 2026).
#
# 01-pr-validation.yml's migration-guard job runs `dotnet tool restore` and
# then `dotnet ef migrations has-pending-model-changes` on a fresh
# checkout. This runs the same two commands on a fresh export of COMMIT,
# with GITHUB_ACTIONS=true as on a runner (so restores are locked, see
# Directory.Build.props), and logs to OUT/guard-N.log.
#
#   OUT=<private folder> guard-probe.sh COMMIT N RESTORE
#
# RESTORE=1 first runs `dotnet restore ./WS.Phoenix.sln`, the fix. The
# connection string points at a closed local port: the check compares the
# model with the snapshot and needs no database, and no real one is reached.
set -u
commit=${1:?COMMIT} n=${2:?N} restore=${3:?RESTORE}
W=/home/leos/Dev/Weel-Sandvig/WS.Phoenix-repro
E=/home/leos/Dev/Speciale2026/experiments
O=${OUT:?set OUT to a private data folder}
DN=${DOTNET_DIR:-/private/tmp/rb1-dotnet10/sdk}
T=/private/tmp/rb1-guard
mkdir -p "$O"
rm -rf "$T" && mkdir -p "$T"
git -C "$W" archive "$commit" -- . ':(exclude).claude' | tar -x -C "$T"
python3 "$E/labcheck.py" "$W" "$commit" "$T" | tail -1
ENV=(env -i HOME="$HOME" USER="$USER" LOGNAME="$LOGNAME" SHELL=/bin/bash PATH="$DN:/usr/local/bin:/usr/bin"
     DOTNET_ROOT="$DN" DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1
     MSBUILDDISABLENODEREUSE=1 LC_ALL=C.UTF-8 GITHUB_ACTIONS=true
     'ConnectionStrings__CatalogConnection=Host=127.0.0.1;Port=9;Database=none;Username=none')
pre=true
[ "$restore" = 1 ] && pre='dotnet restore ./WS.Phoenix.sln'
( cd "$T" && "${ENV[@]}" bash -c "$pre"' && dotnet tool restore && cd src/WebAPI && dotnet ef migrations has-pending-model-changes --context DatabaseContext -p ../Infrastructure/Infrastructure.csproj -s WebAPI.csproj' ) > "$O/guard-$n.log" 2>&1
echo "guard-$n exit $? $(date +%H:%M:%S)"
"${ENV[@]}" dotnet build-server shutdown > /dev/null 2>&1
rm -rf "$T"
