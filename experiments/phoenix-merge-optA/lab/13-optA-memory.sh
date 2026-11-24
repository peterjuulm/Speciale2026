# D3: peak memory of dotnet publish src/WebAPI (release flags, linux-x64,
# SkipSpaBuild) from a fresh export: thesis-merge with SDK 10.0.401, and
# origin/main (8ed4010da) with the system SDK 9.0.123 (main's global.json:
# 9.0.0, latestFeature). The scope's memory.peak, publish only (restore
# before, separately). No build servers, so the compilers run in the scope.
set -uo pipefail
src=/private/tmp/rb1-merge-src
g() { local cap=$1; shift; /tmp/claude-1000/ws-mem-run.sh "$cap" bash -c '"$@"; rc=$?; f=/sys/fs/cgroup$(grep "^0::" /proc/self/cgroup | cut -d: -f3)/memory.peak; if [ -r "$f" ]; then echo "memory.peak $(( $(cat "$f") / 1048576 )) MiB"; else echo "memory.peak unreadable: $f"; fi; exit $rc' _ "$@"; }
for side in merge main; do
  lab=/private/tmp/rb1-mem-$side; rm -rf "$lab"; mkdir -p "$lab"
  if [ $side = merge ]; then ref=thesis-merge; dn=$HOME/rb1-dotnet-10.0.401; else ref=8ed4010dacabf1c60fd6e98e43eb7c6e73f37252; dn=/usr/share/dotnet; fi
  git -C "$src" archive $ref -- . ':(exclude).claude' | tar -x -C "$lab"; cd "$lab"
  export DOTNET_ROOT=$dn PATH=$dn:/usr/bin:/bin LC_ALL=C.UTF-8 DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 DOTNET_CLI_USE_MSBUILD_SERVER=0 NUGET_PACKAGES=/private/tmp/rb1-mem-nuget-$side
  echo; echo "== $side ($ref), dotnet $(dotnet --version)"
  g 6 dotnet restore src/WebAPI/WebAPI.csproj -r linux-x64 --disable-build-servers 2>&1 | grep -E 'error|memory.peak'
  g 14 dotnet publish src/WebAPI/WebAPI.csproj -c Release -o ./out -r linux-x64 --self-contained true --no-restore /p:SkipSpaBuild=true --disable-build-servers -p:UseSharedCompilation=false 2>&1 | grep -E 'error|memory.peak|Time Elapsed'
  echo "Infrastructure.Migrations.dll in the publish: $(ls out | grep -c '^Infrastructure.Migrations.dll$')"
done
