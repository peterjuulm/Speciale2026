#!/bin/bash
# reprotest on Phoenix, with the protocol settled on 24 September 2026:
# - every build starts and ends with `dotnet build-server shutdown`, so no
#   compiler server or MSBuild node crosses from one build into the next;
# - experiments/sample-dotnet.py samples the build processes, so we can check
#   that the variation reached them;
# - each build writes a mode list of its output;
# - the control build gets MIN_CPUS CPUs (reprotest's default is one).
#
# Usage: run.sh LAYER AXIS [LABEL]
#   LAYER  1  dotnet build of the two programs
#          2  the release job's sequence: locked restore, both publishes,
#             a hash list of release/
#   AXIS   one reprotest variation: build_path, time, locales, umask,
#          exec_path, timezone, environment, home, kernel, aslr, num_cpus,
#          domain_host. Or "none": two builds, nothing varied. Or "all":
#          every variation that runs unprivileged here, at once.
#   LABEL  names the output files; default L<LAYER>-<AXIS>
# Environment:
#   OUT       required: a private folder for logs, stores, samples, mode lists
#   MIN_CPUS  CPUs for the control build, default 2
#   FIXENV    VAR=VALUE added to every dotnet command, e.g. LC_ALL=C.UTF-8
#   LAB       the lab, default /private/tmp/rb1-phoenix; must hold no build output
#
# Written 24 September 2026. Replaces the run-axis.sh used that morning.
set -u
LAYER=${1:?LAYER} AXIS=${2:?AXIS}
LABEL=${3:-L$LAYER-$AXIS}
OUT=${OUT:?set OUT to a private data folder}
MIN_CPUS=${MIN_CPUS:-2} FIXENV=${FIXENV:-} LAB=${LAB:-/private/tmp/rb1-phoenix}
EXP=$(cd "$(dirname "$0")/.." && pwd)

ENV='env DOTNET_ROOT=/home/leos/.dotnet PATH=/home/leos/.dotnet:$PATH DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1'
if [ -n "$FIXENV" ]; then ENV="$ENV $FIXENV"; fi
STOP="$ENV dotnet build-server shutdown > /dev/null"
VER='/p:Version=0.0.0-thesis /p:InformationalVersion=v0.0.0-thesis'
case $LAYER in
  1) BUILD="$ENV dotnet build src/WebAPI/WebAPI.csproj -c Release -p:SkipSpaBuild=true && $ENV dotnet build src/BackgroundJobExecutor/BackgroundJobExecutor.csproj -c Release"
     HASHED='src/*/bin' HASHFILE=bin.sha256
     ART='bin.sha256 src/WebAPI/bin/Release/net9.0/*.dll src/WebAPI/bin/Release/net9.0/*.pdb src/WebAPI/bin/Release/net9.0/*.json src/BackgroundJobExecutor/bin/Release/net9.0/BackgroundJobExecutor.*' ;;
  2) BUILD="$ENV dotnet restore ./WS.Phoenix.sln --locked-mode $VER && $ENV dotnet publish ./src/WebAPI/WebAPI.csproj -c Release -o ./release/ws-pems-linux-x64 -r linux-x64 --self-contained true --no-restore /p:SkipSpaBuild=true $VER && $ENV dotnet publish ./src/BackgroundJobExecutor/BackgroundJobExecutor.csproj -c Release -o ./release/ws-pems-job-worker-linux-x64 -r linux-x64 --self-contained true --no-restore $VER"
     HASHED=release HASHFILE=release.sha256
     ART='release.sha256 release/*/ApplicationCore.* release/*/Infrastructure.* release/*/WebAPI.* release/*/BackgroundJobExecutor.* release/*/WebAPI release/*/BackgroundJobExecutor' ;;
  *) echo "LAYER must be 1 or 2" >&2; exit 2 ;;
esac
case $AXIS in
  none) VARY='--vary=-all' ;;
  all)  VARY='--vary=+all,-user_group,-fileordering,-domain_host' ;;
  *)    VARY="--vary=-all,+$AXIS" ;;
esac

mkdir -p "$OUT/modes"
if ls -d $LAB/bin $LAB/obj $LAB/release $LAB/src/*/bin $LAB/src/*/obj $LAB/tests/bin $LAB/tests/obj > /dev/null 2>&1; then
  echo "the lab holds build output; clean it first" >&2; exit 2
fi
if [ -e "$OUT/store-$LABEL" ]; then echo "$OUT/store-$LABEL exists" >&2; exit 2; fi

# One build: shutdown, the build, the hash list, the mode list, shutdown again.
# reprotest runs this under sh -e; "|| rc=$?" keeps a failed build from
# skipping the last shutdown, and the build's exit code is kept.
CMD="$STOP; rc=0; ( $BUILD && find $HASHED -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > $HASHFILE && find $HASHED -type f -printf '%m %p\n' | LC_ALL=C sort > $OUT/modes/$LABEL-\$(umask)-\$\$.txt ) || rc=\$?; $STOP; exit \$rc"
printf '%s\n%s\n%s\n' "$VARY --min-cpus $MIN_CPUS" "$CMD" "$ART" > "$OUT/rt-$LABEL.cmd"

eval "$STOP"
python3 "$EXP/sample-dotnet.py" "$OUT/samples-$LABEL.txt" &
SAMPLER=$!
START=$(date -Is)
cd "$LAB" || exit 1
timeout 3600 /home/leos/.local/bin/reprotest -v --min-cpus "$MIN_CPUS" --store-dir "$OUT/store-$LABEL" \
  "$VARY" -c "$CMD" "$LAB" "$ART" > "$OUT/rt-$LABEL.log" 2>&1
RC=$?
sleep 2
kill $SAMPLER
eval "$STOP"

C="$OUT/store-$LABEL/control/source-root/$HASHFILE"
E="$OUT/store-$LABEL/experiment-1/source-root/$HASHFILE"
CM=$( [ -f "$C" ] && sha256sum < "$C" | cut -c1-16 || echo -)
EM=$( [ -f "$E" ] && sha256sum < "$E" | cut -c1-16 || echo -)
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$LABEL" "$LAYER" "$AXIS" "$START" "$(date -Is)" "$RC" "$CM" "$EM" >> "$OUT/summary.tsv"
echo "$LABEL exit $RC control $CM experiment $EM"
