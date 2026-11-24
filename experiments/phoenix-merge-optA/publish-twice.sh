#!/bin/bash
#
# publish-twice.sh COMMIT
#
# The release's .NET publishes of COMMIT, twice, from fresh git archive
# exports at two paths outside git (/private/tmp/rb1-pub-a and
# /private/tmp/rb1-pub-b-other), with SDK 10.0.401 in ~/rb1-dotnet-10.0.401:
# one locked restore of the solution, then, as 03-release.yml and
# 00-reusable-windows-publish.yml publish them,
#   DbMigrator     linux-x64 and win-x64, self-contained single file
#   WebAPI         linux-x64, self-contained, SkipSpaBuild=true
#   job worker     linux-x64, self-contained
# Then the SHA-256 of every file in each publish folder, compared between
# the two exports. Peak memory of each publish is from /usr/bin/time -l.
# REPO is the repository (default ~/Dev/Weel-Sandvig/WS.Phoenix), OUT the
# results folder (default /private/tmp/rb1-pub-results).
#
# Written 23 November 2026 for the merge of main (option A).

set -u
commit=$1
repo=${REPO:-$HOME/Dev/Weel-Sandvig/WS.Phoenix}
out=${OUT:-/private/tmp/rb1-pub-results}
dotnet_dir=$HOME/rb1-dotnet-10.0.401
mkdir -p "$out"
: > "$out/summary.txt"

run() {  # run LAB LOG COMMAND... : in LAB, under env -i, timed
    local lab=$1 log=$2
    shift 2
    (cd "$lab" && env -i HOME="$HOME" PATH="$dotnet_dir:/usr/bin:/bin:/usr/sbin:/sbin" \
        DOTNET_ROOT="$dotnet_dir" DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 \
        DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 LC_ALL=C.UTF-8 APP_VERSION=v0.0.0-thesis \
        GITHUB_ACTIONS=true /usr/bin/time -l "$@") > "$out/$log" 2>&1
    local rc=$?
    local rss
    rss=$(awk '/maximum resident set size/ {printf "%.1f GB", $1/1073741824}' "$out/$log")
    echo "$log: exit $rc, peak RSS $rss" | tee -a "$out/summary.txt"
}

for lab in /private/tmp/rb1-pub-a /private/tmp/rb1-pub-b-other; do
    name=$(basename "$lab")
    rm -rf "$lab"
    mkdir -p "$lab"
    git -C "$repo" archive "$commit" -- . ':(exclude).claude' | tar -x -C "$lab"
    run "$lab" "$name-restore.log" dotnet restore ./WS.Phoenix.sln
    run "$lab" "$name-migrator-linux.log" dotnet publish ./src/DbMigrator/DbMigrator.csproj -c Release -o ./publish/migrator -r linux-x64 --self-contained true --no-restore
    run "$lab" "$name-migrator-win.log" dotnet publish src/DbMigrator/DbMigrator.csproj --configuration Release --output publish/migrator-win --runtime win-x64 --self-contained true --no-restore
    run "$lab" "$name-webapi.log" dotnet publish ./src/WebAPI/WebAPI.csproj -c Release -o ./release/ws-pems-linux-x64 -r linux-x64 --self-contained true --no-restore /p:SkipSpaBuild=true
    run "$lab" "$name-worker.log" dotnet publish ./src/BackgroundJobExecutor/BackgroundJobExecutor.csproj -c Release -o ./release/ws-pems-job-worker-linux-x64 -r linux-x64 --self-contained true --no-restore
    (cd "$lab" && find publish/migrator publish/migrator-win release/ws-pems-linux-x64 release/ws-pems-job-worker-linux-x64 \
        -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256) > "$out/$name.sha256"
    echo "$name: $(wc -l < "$out/$name.sha256" | tr -d ' ') files" | tee -a "$out/summary.txt"
done

a=$out/rb1-pub-a.sha256 b=$out/rb1-pub-b-other.sha256
if cmp -s "$a" "$b"; then
    echo "identical: every file of the two exports" | tee -a "$out/summary.txt"
else
    echo "DIFFERENT:" | tee -a "$out/summary.txt"
    diff "$a" "$b" | head -40 | tee -a "$out/summary.txt"
fi
for f in ws-pems-db-migrator ws-pems-db-migrator.exe Infrastructure.dll Infrastructure.Migrations.dll; do
    grep -E "/$f\$" "$a" | sed 's/^/  /' | tee -a "$out/summary.txt"
done
echo "Infrastructure.Migrations.dll in the WebAPI or job worker folders: $(grep -cE '^[0-9a-f]+  release/.*/Infrastructure\.Migrations\.dll$' "$a")" | tee -a "$out/summary.txt"
