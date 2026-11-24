# D2: the release's .NET publishes of thesis-merge (30b5c745d), twice, from
# git archive exports at two paths, as publish-twice.sh ran them on
# macstudio: one locked restore, then DbMigrator linux-x64 and win-x64, the
# WebAPI and the job worker linux-x64, all self-contained, APP_VERSION
# v0.0.0-thesis, LC_ALL=C.UTF-8, GITHUB_ACTIONS=true. Then the two against
# each other and against macstudio's list (81b0e8450, the same tree but for
# src/WebAPI/Dockerfile, which no publish reads).
set -uo pipefail
src=/private/tmp/rb1-merge-src out=/private/tmp/rb1-optA-pub-results
export DOTNET_ROOT=$HOME/rb1-dotnet-10.0.401 PATH=$HOME/rb1-dotnet-10.0.401:/usr/bin:/bin
export LC_ALL=C.UTF-8 DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 DOTNET_CLI_USE_MSBUILD_SERVER=0
export APP_VERSION=v0.0.0-thesis GITHUB_ACTIONS=true NUGET_PACKAGES=/private/tmp/rb1-optA-nuget
g() { local cap=$1; shift; /tmp/claude-1000/ws-mem-run.sh "$cap" bash -c '"$@"; rc=$?; f=/sys/fs/cgroup$(grep "^0::" /proc/self/cgroup | cut -d: -f3)/memory.peak; if [ -r "$f" ]; then echo "memory.peak $(( $(cat "$f") / 1048576 )) MiB"; else echo "memory.peak unreadable: $f"; fi; exit $rc' _ "$@"; }
rm -rf "$out"; mkdir -p "$out"
for lab in /private/tmp/rb1-optA-pub-a /private/tmp/rb1-optA-pub-b-other; do
  n=$(basename $lab); echo; echo "== $n $(date +%H:%M:%S)"
  rm -rf "$lab"; mkdir -p "$lab"; git -C "$src" archive thesis-merge -- . ':(exclude).claude' | tar -x -C "$lab"; cd "$lab"
  g 6 dotnet restore ./WS.Phoenix.sln --disable-build-servers 2>&1 | grep -E 'NU1004|NU1201|error|memory.peak'
  g 10 dotnet publish ./src/DbMigrator/DbMigrator.csproj -c Release -o ./publish/migrator -r linux-x64 --self-contained true --no-restore --disable-build-servers -p:UseSharedCompilation=false 2>&1 | grep -E 'error|memory.peak|->'
  g 10 dotnet publish src/DbMigrator/DbMigrator.csproj --configuration Release --output publish/migrator-win --runtime win-x64 --self-contained true --no-restore --disable-build-servers -p:UseSharedCompilation=false 2>&1 | grep -E 'error|memory.peak|->'
  g 10 dotnet publish ./src/WebAPI/WebAPI.csproj -c Release -o ./release/ws-pems-linux-x64 -r linux-x64 --self-contained true --no-restore /p:SkipSpaBuild=true --disable-build-servers -p:UseSharedCompilation=false 2>&1 | grep -E 'error|memory.peak'
  g 10 dotnet publish ./src/BackgroundJobExecutor/BackgroundJobExecutor.csproj -c Release -o ./release/ws-pems-job-worker-linux-x64 -r linux-x64 --self-contained true --no-restore --disable-build-servers -p:UseSharedCompilation=false 2>&1 | grep -E 'error|memory.peak'
  (find publish/migrator publish/migrator-win release/ws-pems-linux-x64 release/ws-pems-job-worker-linux-x64 -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) > "$out/$n.sha256"
  echo "$n: $(wc -l < "$out/$n.sha256") files"
done
cd "$out"
cmp -s rb1-optA-pub-a.sha256 rb1-optA-pub-b-other.sha256 && echo "a = b-other: identical" || { echo "a != b-other:"; diff rb1-optA-pub-a.sha256 rb1-optA-pub-b-other.sha256 | head -20; }
m=/private/tmp/rb1-merge-expected/mac-publish-81b0e8450.sha256
cmp -s rb1-optA-pub-a.sha256 "$m" && echo "arch = macstudio: identical ($(wc -l < $m) files)" || { echo "arch != macstudio: $(diff <(awk '{print $2,$1}' rb1-optA-pub-a.sha256) <(awk '{print $2,$1}' $m) | grep -c '^[<>]') lines differ"; diff <(awk '{print $2" "$1}' rb1-optA-pub-a.sha256) <(awk '{print $2" "$1}' "$m") | head -30; }
grep -cE 'release/.*/Infrastructure\.Migrations\.dll$' rb1-optA-pub-a.sha256 | sed 's/^/Infrastructure.Migrations.dll in the WebAPI or job worker folders: /'
