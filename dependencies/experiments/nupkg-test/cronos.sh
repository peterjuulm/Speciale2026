#!/bin/bash
# Build Cronos 0.9.0 as its AppVeyor release did, for the nupkg test.
#
# Usage: cronos.sh WORKDIR SDK_DIR [pathmap|nopathmap]
#
# WORKDIR must not exist. The script clones HangfireIO/Cronos from GitHub at
# the declared commit (Source Link reads the remote), then runs the steps of
# Hangfire.Build 0.5.0's psake-common.ps1 (Restore, Compile) with
# APPVEYOR=True under env -i. "pathmap" (the default) maps WORKDIR/src to
# C:\projects\cronos\, the build path the published PDB records. The net6.0
# DLL is copied to WORKDIR/out/.
#
# Written 21 October 2026 for the nupkg pilot.
set -euo pipefail
work=$1 sdk=$2 mode=${3:-pathmap}
commit=14ca2b146d55f8d16a36eded60a74425b1b00f51
[ -e "$work" ] && { echo "$work exists" >&2; exit 1; }
mkdir -p "$work/home" "$work/nuget" "$work/out"
git clone -q https://github.com/HangfireIO/Cronos.git "$work/src"
git -C "$work/src" checkout -q "$commit"
cd "$work/src"

extra=()
[ "$mode" = pathmap ] && extra=("-p:PathMap=$PWD/=C:\\projects\\cronos\\")

run() {
  env -i HOME="$work/home" DOTNET_CLI_HOME="$work/home" PATH="$sdk:/usr/bin:/bin" \
    DOTNET_ROOT="$sdk" DOTNET_MULTILEVEL_LOOKUP=0 DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 NUGET_PACKAGES="$work/nuget" \
    APPVEYOR=True "$sdk/dotnet" "$@"
}
run build-server shutdown >/dev/null
run --version
run restore --locked-mode
run build --no-restore -c Release -nologo -verbosity:minimal ${extra[@]+"${extra[@]}"}
run build-server shutdown >/dev/null
cp src/Cronos/bin/Release/net6.0/Cronos.dll "$work/out/"
