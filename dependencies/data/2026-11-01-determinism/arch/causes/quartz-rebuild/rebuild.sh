#!/bin/bash
# Quartz 3.13.1 twice, in two different paths, with the experiment's configured props; keeps nupkg AND snupkg.
set -u
LAB=/private/tmp/nupkg-determinism
S=$(dirname "$(readlink -f "$0")")
MIRROR=$LAB/mirrors/https_github.com_quartznet_quartznet.git
COMMIT=f3ec5fa7476070c1aa20add02ced82499c9e8d4b
export PATH=$LAB/sdk:$LAB/tools:$PATH DOTNET_ROOT=$LAB/sdk DOTNET_CLI_HOME=$LAB/clihome NUGET_PACKAGES=$LAB/nuget/ DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 NuGetAudit=false
PROPS="-p:UseSharedCompilation=false -p:ContinuousIntegrationBuild=true -p:Deterministic=true -p:DeterministicTimestamp=1730541062"
for D in "$S/A/src" "$S/B/a/much/deeper/directory/for/the/second/build/src"; do
  echo "== $D $(date -Iseconds)"
  mkdir -p "$(dirname "$D")"
  git clone -q --shared --no-checkout "$MIRROR" "$D" && cd "$D" || exit 1
  git config core.autocrlf false; git remote set-url origin https://github.com/quartznet/quartznet
  git -c advice.detachedHead=false checkout -q $COMMIT
  [ -f .gitmodules ] && git submodule update --init --recursive -q
  python3 -I -c "import json; p='global.json'; g=json.load(open(p)); g.pop('sdk',None); json.dump(g,open(p,'w'),indent=2)"
  dotnet restore src/Quartz/Quartz.csproj -p:UseSharedCompilation=false > restore.log 2>&1 || { echo "restore failed"; tail -5 restore.log; exit 1; }
  rm -rf out
  dotnet build src/Quartz/Quartz.csproj -c Release --no-restore $PROPS > build.log 2>&1 && dotnet pack src/Quartz/Quartz.csproj -c Release --no-build -o out $PROPS >> build.log 2>&1
  echo "rc=$? $(date -Iseconds)"; ls out; dotnet build-server shutdown >/dev/null 2>&1
done
echo "== compare"
sha256sum "$S"/A/src/out/* "$S"/B/a/much/deeper/directory/for/the/second/build/src/out/*
echo "== REBUILD DONE"
