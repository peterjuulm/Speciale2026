#!/bin/bash
#
# merge-checks.sh [REPO]
#
# The checks of the merge of main into thesis/reproducible-builds that need
# no database and no Docker, as CI's .NET job runs them
# (00-reusable-dotnet-build.yml), with SDK 10.0.401 in ~/rb1-dotnet-10.0.401
# (installed by the branch's scripts/install-dotnet-sdk.py). REPO is the
# merge worktree (default ~/rb1-phoenix-merge). Each step's log goes to
# OUT (default /private/tmp/rb1-merge-checks); a summary line per step to
# OUT/summary.txt.
#
#   C1  locked restore with GITHUB_ACTIONS=true: no NU1004, no NU1201
#   C2  dotnet build of the solution, Release
#   C3  the order of the names in PostgresMigrations.g.cs (MSBuild's glob)
#   C4  dotnet tool restore, then verify-nuget-downloads.py --tools
#   C5  CI's model check: has-pending-model-changes, from src/WebAPI
#   C6  dotnet ef migrations list --no-connect with each startup project:
#       Infrastructure.Migrations, DbMigrator, and the SQL Server context
#   C7  the unit tier, CI's filter
#
# Written 23 November 2026.

set -u
repo=${1:-$HOME/rb1-phoenix-merge}
out=${OUT:-/private/tmp/rb1-merge-checks}
mkdir -p "$out"
: > "$out/summary.txt"
export DOTNET_ROOT=$HOME/rb1-dotnet-10.0.401
export PATH=$DOTNET_ROOT:$HOME/.dotnet/tools:/usr/bin:/bin:/usr/sbin:/sbin
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
cd "$repo" || exit 2

step() {  # step NAME LOG COMMAND...
    local name=$1 log=$2
    shift 2
    "$@" > "$out/$log" 2>&1
    local rc=$?
    echo "$name exit $rc ($log)" | tee -a "$out/summary.txt"
    return $rc
}

{ echo "dotnet $(dotnet --version)"; git -C "$repo" log -1 --format='HEAD %H'; git -C "$repo" status --short | wc -l | sed 's/^/changed paths: /'; } >> "$out/summary.txt"

GITHUB_ACTIONS=true step C1 c1-restore.log dotnet restore ./WS.Phoenix.sln
grep -E 'NU1004|NU1201|error' "$out/c1-restore.log" | sed 's/^/  C1: /' | tee -a "$out/summary.txt"
GITHUB_ACTIONS=true step C1b c1b-restore-opcdaprobe.log dotnet restore tools/OpcDaProbe/OpcDaProbe.csproj

step C2 c2-build.log dotnet build ./WS.Phoenix.sln --configuration Release --no-restore
grep -E ' error |Warn|Error' "$out/c2-build.log" | tail -3 | sed 's/^/  C2: /' | tee -a "$out/summary.txt"

g=$(find src/Infrastructure/obj -name PostgresMigrations.g.cs | head -1)
grep -oE '"2[^"]+"' "$g" | tr -d '"' > "$out/c3-generated-order.txt"
find src/Infrastructure.Migrations/Data/Migrations -maxdepth 1 -name '2*.cs' ! -name '*.Designer.cs' \
    | sed 's#.*/##; s#\.cs$##' | LC_ALL=C sort > "$out/c3-files-ordinal.txt"
if cmp -s "$out/c3-generated-order.txt" "$out/c3-files-ordinal.txt"; then
    echo "C3 $(wc -l < "$out/c3-files-ordinal.txt" | tr -d ' ') names in $g, in ordinal order of the files" | tee -a "$out/summary.txt"
else
    echo "C3 the generated order differs from the files' ordinal order" | tee -a "$out/summary.txt"
fi

step C4a c4a-tool-restore.log dotnet tool restore
step C4b c4b-nuget-check.log python3 scripts/verify-nuget-downloads.py --tools
tail -2 "$out/c4b-nuget-check.log" | sed 's/^/  C4: /' | tee -a "$out/summary.txt"

(cd src/WebAPI && step C5 c5-model-check.log dotnet ef migrations has-pending-model-changes --configuration Release --no-build \
    --context DatabaseContext -p ../Infrastructure.Migrations/Infrastructure.Migrations.csproj \
    -s ../Infrastructure.Migrations/Infrastructure.Migrations.csproj)
tail -2 "$out/c5-model-check.log" | sed 's/^/  C5: /' | tee -a "$out/summary.txt"

list() {  # list LABEL CONTEXT PROJECT STARTUP
    step "C6 $1" "c6-list-$1.log" dotnet ef migrations list --no-connect --configuration Release --no-build --verbose \
        --context "$2" -p "$3" -s "$4"
    local n last factory
    n=$(grep -cE '^[0-9]{14}_' "$out/c6-list-$1.log")
    last=$(grep -E '^[0-9]{14}_' "$out/c6-list-$1.log" | tail -1)
    factory=$(grep -oE "Using DbContext factory '[^']+'" "$out/c6-list-$1.log" | head -1)
    echo "  C6 $1: $n migrations, last $last; $factory" | tee -a "$out/summary.txt"
}
list migrations DatabaseContext src/Infrastructure.Migrations src/Infrastructure.Migrations
list dbmigrator DatabaseContext src/Infrastructure.Migrations src/DbMigrator
list sqlserver SqlServerDatabaseContext src/Infrastructure src/Infrastructure.Migrations

step C7 c7-unit.log dotnet test ./WS.Phoenix.sln --configuration Release --no-build \
    --filter "FullyQualifiedName~tests.UnitTests" --logger "trx;LogFileName=unit.trx" --results-directory "$out/trx"
grep -E '^(Passed|Failed)!|Total tests|Failed |error' "$out/c7-unit.log" | tail -5 | sed 's/^/  C7: /' | tee -a "$out/summary.txt"
