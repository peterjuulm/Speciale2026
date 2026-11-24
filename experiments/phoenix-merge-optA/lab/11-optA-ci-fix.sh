# D1, the steps whose exit codes the first run lost to a bug in its memory
# helper (/proc/self/cgroup has two lines on arch): the build (incremental,
# for its summary), CI's NuGet check as the build job runs it (no --tools),
# the same as the release's migration job runs it (a CLI home of its own,
# then --tools), and the model check. Same lab and NuGet folder as D1.
set -uo pipefail
lab=/private/tmp/rb1-optA-ci
export DOTNET_ROOT=$HOME/rb1-dotnet-10.0.401 PATH=$HOME/rb1-dotnet-10.0.401:/usr/bin:/bin
export LC_ALL=C.UTF-8 DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 DOTNET_CLI_USE_MSBUILD_SERVER=0
export NUGET_PACKAGES=/private/tmp/rb1-optA-nuget
g() { local cap=$1; shift; /tmp/claude-1000/ws-mem-run.sh "$cap" bash -c '"$@"; rc=$?; f=/sys/fs/cgroup$(grep "^0::" /proc/self/cgroup | cut -d: -f3)/memory.peak; if [ -r "$f" ]; then echo "memory.peak $(( $(cat "$f") / 1048576 )) MiB"; else echo "memory.peak unreadable: $f"; fi; exit $rc' _ "$@"; }
cd "$lab"
echo "== C2b build (incremental)"; g 10 dotnet build ./WS.Phoenix.sln -c Release --no-restore --disable-build-servers -p:UseSharedCompilation=false 2>&1 | grep -E 'Build succeeded|Warning\(s\)|Error\(s\)|error |memory.peak'; echo "C2b exit ${PIPESTATUS[0]}"
echo "== C4a NuGet check, as CI's build job"; python3 scripts/verify-nuget-downloads.py | tail -4; echo "C4a exit ${PIPESTATUS[0]}"
echo "== C4b NuGet check, as the release's migration job"; rm -rf /private/tmp/rb1-optA-cli-home
DOTNET_CLI_HOME=/private/tmp/rb1-optA-cli-home dotnet tool restore | tail -1
DOTNET_CLI_HOME=/private/tmp/rb1-optA-cli-home python3 scripts/verify-nuget-downloads.py --tools | tail -4; echo "C4b exit ${PIPESTATUS[0]}"
echo "== C5 model check"; (cd src/WebAPI && g 6 dotnet ef migrations has-pending-model-changes --configuration Release --no-build --context DatabaseContext -p ../Infrastructure.Migrations/Infrastructure.Migrations.csproj -s ../Infrastructure.Migrations/Infrastructure.Migrations.csproj 2>&1 | grep -v -E 'warning NU19' | tail -3; exit ${PIPESTATUS[0]}); echo "C5 exit $?"
