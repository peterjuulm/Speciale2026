#!/bin/bash
# reprotest on Phoenix's frontend (layer 3): the release's frontend build,
# `npm ci` from the filled cache without network and `next build`, then a
# hash list and a mode list of the static export out/.
#
# The protocol follows experiments/phoenix-rt/run.sh, without the .NET parts:
# - reprotest starts under env -i with HOME, USER, LOGNAME, SHELL and PATH
#   only (reprotest-probe R4);
# - the build sets only what pilot.sh sets beyond that: Node first on PATH,
#   CI, the npm cache, no update check, no telemetry, APP_VERSION. LANG, TZ
#   and HOME are left to reprotest, which fixes or varies them;
# - experiments/sample-dotnet.py follows Node's processes instead of dotnet's,
#   so we can check that the variation reached them;
# - the control build gets MIN_CPUS CPUs (reprotest's default is one);
# - any Node process still alive after the run is listed in
#   leftover-LABEL.txt and counted in summary.tsv.
#
# Usage: run.sh AXIS [LABEL]
#   AXIS   one reprotest variation: build_path, time, locales, umask,
#          exec_path, timezone, environment, home, kernel, aslr, num_cpus,
#          user_group. Or "none": two builds, nothing varied. Or "all": every
#          variation that runs unprivileged here, at once. user_group runs
#          the experiment build as rb1b (setup-user-group.sh in phoenix-rt);
#          both builds then use a copy of the npm cache that rb1b can write
#          its logs next to, and a second sampler runs as rb1b.
#   LABEL  names the output files; default L3-<AXIS>
# Environment:
#   OUT          required: a private folder for logs, stores, samples, mode lists
#   MIN_CPUS     CPUs for the control build, default 2
#   APP_VERSION  the version Next takes as build ID, default v0.0.0-thesis
#   FIXENV       VAR=VALUE added to the build's environment
#   LAB          the lab, default /private/tmp/rb1-fe: an export of the whole
#                commit (the frontend imports code from mcp/, W39), with no
#                node_modules, .next or out
#
# Written 12 October 2026.
set -u
AXIS=${1:?AXIS}
LABEL=${2:-L3-$AXIS}
OUT=${OUT:?set OUT to a private data folder}
MIN_CPUS=${MIN_CPUS:-2} FIXENV=${FIXENV:-} LAB=${LAB:-/private/tmp/rb1-fe}
APP_VERSION=${APP_VERSION:-v0.0.0-thesis}
EXP=$(cd "$(dirname "$0")/.." && pwd)

NODE=/opt/rb1-node/bin/node CACHE=/private/tmp/rb1-npm
MODES=$OUT/modes SHARED=/private/tmp/rb1-shared
case $AXIS in
  none) VARY=(--vary=-all) ;;
  all)  VARY=(--vary=+all,-user_group,-fileordering,-domain_host) ;;
  user_group)
        VARY=(--vary=-all,+user_group --vary=user_group.available+=rb1b:rb1b)
        CACHE=$SHARED/npm-cache MODES=$SHARED/modes ;;
  *)    VARY=("--vary=-all,+$AXIS") ;;
esac

LAUNCH=(env -i HOME="$HOME" USER="$USER" LOGNAME="$LOGNAME" SHELL=/bin/bash
        PATH=/home/leos/.local/bin:/usr/local/bin:/usr/bin)
ENV="env PATH=${NODE%/node}:\$PATH CI=true npm_config_cache=$CACHE npm_config_update_notifier=false NEXT_TELEMETRY_DISABLED=1 APP_VERSION=$APP_VERSION"
if [ -n "$FIXENV" ]; then ENV="$ENV $FIXENV"; fi
APP=src/WebAPI/ClientApp HASHFILE=out.sha256
ART="$HASHFILE $APP/out"

mkdir -p "$OUT/modes" "$MODES"
for d in "$APP/node_modules" "$APP/.next" "$APP/out" "$HASHFILE"; do
  if [ -e "$LAB/$d" ]; then echo "the lab holds build output ($d); export it again" >&2; exit 2; fi
done
if [ -e "$OUT/store-$LABEL" ]; then echo "$OUT/store-$LABEL exists" >&2; exit 2; fi

# One build: install, build, the hash list, the mode list. reprotest runs it
# under sh -e from the copy of the lab, so the first failing step ends it.
CMD="cd $APP && $ENV npm ci --offline --no-audit --no-fund && $ENV npm run build && find out -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > ../../../$HASHFILE && find out -type f -printf '%m %p\n' | LC_ALL=C sort > $MODES/$LABEL-\$(umask)-\$\$.txt"
printf '%s\n%s\n%s\n%s\n' "${LAUNCH[*]}" "${VARY[*]} --min-cpus $MIN_CPUS" "$CMD" "$ART" > "$OUT/rt-$LABEL.cmd"

if [ ! -e "$OUT/environment.txt" ]; then
  {
    date -Is
    uname -srm
    echo "umask $(umask), $(nproc) CPUs"
    echo "node $("$NODE" --version), npm $(PATH="${NODE%/node}:/usr/bin" npm --version)"
    sha256sum "$NODE"
    echo "next $(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["packages"]["node_modules/next"]["version"])' "$LAB/$APP/package-lock.json")"
    echo "npm cache $CACHE, $(du -sh "$CACHE" | cut -f1)"
    echo "reprotest $(/home/leos/.local/share/pipx/venvs/reprotest/bin/python -c 'import importlib.metadata as m; print(m.version("reprotest"))' 2>/dev/null || echo unknown)"
    echo "$(diffoscope --version), libfaketime $(pacman -Q libfaketime 2>/dev/null | cut -d' ' -f2)"
    echo "APP_VERSION $APP_VERSION"
  } > "$OUT/environment.txt"
fi

if [ "$AXIS" = user_group ]; then
  # npm writes a debug log into its cache folder, and rb1b cannot write in
  # Leo's. The copy is made once and opened to both users.
  if [ ! -d "$CACHE" ]; then
    cp -a /private/tmp/rb1-npm "$CACHE" && chmod -R a+rwX "$CACHE" || exit 2
  fi
fi

DOTNET_EXE=$NODE python3 "$EXP/sample-dotnet.py" "$OUT/samples-$LABEL.txt" &
SAMPLER=$!
if [ "$AXIS" = user_group ]; then
  cp "$EXP/sample-dotnet.py" "$SHARED/sample-dotnet.py"
  sudo -n -u rb1b env DOTNET_EXE=$NODE python3 "$SHARED/sample-dotnet.py" "$SHARED/samples-$LABEL-rb1b.txt" &
fi
START=$(date -Is)
cd "$LAB" || exit 1
timeout 7200 "${LAUNCH[@]}" /home/leos/.local/bin/reprotest -v --min-cpus "$MIN_CPUS" --store-dir "$OUT/store-$LABEL" \
  "${VARY[@]}" -c "$CMD" "$LAB" "$ART" > "$OUT/rt-$LABEL.log" 2>&1
RC=$?
sleep 2
kill $SAMPLER
if [ "$AXIS" = user_group ]; then
  sudo -n -u rb1b pkill -u rb1b -f "[s]amples-$LABEL-rb1b"
  cp "$SHARED/samples-$LABEL-rb1b.txt" "$OUT/"
  cp "$MODES/$LABEL-"* "$OUT/modes/"
fi
# By executable, not command line: npm's own process is just "node". Only
# Leo's processes are visible here; rb1b's show in its sampler.
for p in /proc/[0-9]*; do
  if [ "$(readlink "$p/exe" 2>/dev/null)" = "$NODE" ]; then
    echo "${p#/proc/} $(tr '\0' ' ' < "$p/cmdline" | cut -c1-200)"
  fi
done > "$OUT/leftover-$LABEL.txt"
LEFT=$(wc -l < "$OUT/leftover-$LABEL.txt")

C="$OUT/store-$LABEL/control/source-root/$HASHFILE"
E="$OUT/store-$LABEL/experiment-1/source-root/$HASHFILE"
CM=$( [ -f "$C" ] && sha256sum < "$C" | cut -c1-16 || echo -)
EM=$( [ -f "$E" ] && sha256sum < "$E" | cut -c1-16 || echo -)
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$LABEL" 3 "$AXIS" "$START" "$(date -Is)" "$RC" "$CM" "$EM" "$LEFT" >> "$OUT/summary.tsv"
echo "$LABEL exit $RC control $CM experiment $EM leftover $LEFT"
