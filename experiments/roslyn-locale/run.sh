#!/bin/bash
# Build the repro once per environment, in a fresh copy outside git, with the
# build servers shut down first, and print the DLL hash and the order of the
# two generated types. Usage: run.sh NAME [VAR=VALUE ...]
# Written 24 September 2026 for roslyn-locale-repro.
set -u
NAME=$1; shift
SRC=$(cd "$(dirname "$0")" && pwd)
LAB=/private/tmp/rb1-locale
OUT=/home/leos/Dev/Speciale2026/data/2026-09-24-roslyn-locale-repro/arch
DOTNET="env DOTNET_ROOT=/home/leos/.dotnet PATH=/home/leos/.dotnet:/usr/bin DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1"
mkdir -p $OUT
rm -rf $LAB && mkdir -p $LAB && cp $SRC/LocaleRepro.csproj $SRC/Repro.cs $LAB/ && cd $LAB
$DOTNET dotnet build-server shutdown > /dev/null 2>&1
$DOTNET "$@" dotnet build -c Release -p:Features=debug-determinism > $OUT/build-$NAME.log 2>&1
echo "exit $?" >> $OUT/build-$NAME.log
DLL=bin/Release/net9.0/LocaleRepro.dll
KEY=$(find obj -name '*.key' | head -1)
cp $KEY $OUT/key-$NAME.txt 2>/dev/null
ORDER=$(/home/leos/.local/bin/ildasm -CLASSLIST -NOIL $DLL 2>/dev/null | grep -o '<>[yz]__[A-Za-z]*[0-9]*`1' | tr '\n' ' ')
printf '%-22s %s  %s  key=%s\n' "$NAME" "$(sha256sum < $DLL | cut -c1-16)" "$ORDER" "$(sha256sum < $KEY | cut -c1-16)" | tee -a $OUT/results.txt
$DOTNET dotnet build-server shutdown > /dev/null 2>&1
