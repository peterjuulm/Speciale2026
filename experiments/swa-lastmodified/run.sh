#!/bin/bash
# run.sh DOTNET TF LABEL [extra msbuild args]: publish twice, 3 s apart, from a clean obj each time
set -u; DN=$1 TF=$2 LABEL=$3; shift 3; R=$(dirname "$0"); cd "$R/src"
export DOTNET_CLI_HOME=$R/home NUGET_PACKAGES=$R/packages DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1 MSBUILDDISABLENODEREUSE=1
for i in 1 2; do
  rm -rf bin obj
  $DN publish -c Release -p:TF=$TF --disable-build-servers -o "$R/out/$LABEL-$i" "$@" > "$R/out/$LABEL-$i.log" 2>&1 || { echo "$LABEL-$i failed"; tail -5 "$R/out/$LABEL-$i.log"; exit 1; }
  sleep 3
done
