# D1: CI's .NET job (00-reusable-dotnet-build.yml) on the merge thesis-merge
# (30b5c745d), in a git archive outside git, with SDK 10.0.401 and a NuGet
# folder of its own. Every heavy step runs under the shared guard
# /tmp/claude-1000/ws-mem-run.sh <cap GB>, without build servers, and prints
# its scope's memory.peak. LC_ALL=C.UTF-8 as on CI's runners.
set -uo pipefail
src=/private/tmp/rb1-merge-src lab=/private/tmp/rb1-optA-ci
export DOTNET_ROOT=$HOME/rb1-dotnet-10.0.401 PATH=$HOME/rb1-dotnet-10.0.401:/usr/bin:/bin
export LC_ALL=C.UTF-8 DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 DOTNET_CLI_USE_MSBUILD_SERVER=0
export NUGET_PACKAGES=/private/tmp/rb1-optA-nuget
g() { local cap=$1; shift; /tmp/claude-1000/ws-mem-run.sh "$cap" bash -c '"$@"; rc=$?; echo "memory.peak $(( $(cat /sys/fs/cgroup$(cut -d: -f3 /proc/self/cgroup)/memory.peak) / 1048576 )) MiB"; exit $rc' _ "$@"; }
step() { echo; echo "== $1  $(date +%H:%M:%S)"; }
rm -rf "$lab" "$NUGET_PACKAGES"; mkdir -p "$lab"
git -C "$src" archive thesis-merge -- . ':(exclude).claude' | tar -x -C "$lab"
cd "$lab"; echo "commit $(git -C "$src" rev-parse thesis-merge)"; dotnet --version
step "C1 locked restore";  GITHUB_ACTIONS=true g 6 dotnet restore ./WS.Phoenix.sln --disable-build-servers 2>&1 | grep -E 'NU1004|NU1201|error|Restored|memory.peak' ; echo "C1 exit ${PIPESTATUS[0]}"
step "C2 build";           g 10 dotnet build ./WS.Phoenix.sln -c Release --no-restore --disable-build-servers -p:UseSharedCompilation=false 2>&1 | tail -4; echo "C2 exit ${PIPESTATUS[0]}"
step "C3 tool restore";    dotnet tool restore | tail -2; echo "C3 exit ${PIPESTATUS[0]}"
step "C4 nuget check";     python3 scripts/verify-nuget-downloads.py --tools | tail -3; echo "C4 exit ${PIPESTATUS[0]}"
step "C5 model check";     (cd src/WebAPI && g 6 dotnet ef migrations has-pending-model-changes --configuration Release --no-build --context DatabaseContext -p ../Infrastructure.Migrations/Infrastructure.Migrations.csproj -s ../Infrastructure.Migrations/Infrastructure.Migrations.csproj 2>&1 | tail -2); echo "C5 exit ${PIPESTATUS[0]}"
for tier in UnitTests IntegrationTests FunctionalTests; do
  step "C6 $tier"
  g 10 dotnet test ./WS.Phoenix.sln -c Release --no-build --disable-build-servers --filter "FullyQualifiedName~tests.$tier" --logger "trx;LogFileName=$tier.trx" --results-directory /private/tmp/rb1-optA-trx 2>&1 | grep -E '^(Passed|Failed)!|Total tests|^\s+Failed |error|memory.peak' | tail -12
  echo "C6 $tier exit ${PIPESTATUS[0]}"
done
echo; echo "== done $(date +%H:%M:%S)"
