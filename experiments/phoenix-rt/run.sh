#!/bin/bash
# reprotest on Phoenix, with the protocol settled on 24 September 2026:
# - every build starts and ends with `dotnet build-server shutdown`, so no
#   compiler server crosses from one build into the next;
# - MSBuild's node reuse is off (MSBUILDDISABLENODEREUSE=1): its worker nodes
#   survive the shutdown (added 5 October 2026);
# - experiments/sample-dotnet.py samples the build processes, so we can check
#   that the variation reached them;
# - each build writes a mode list of its output;
# - the control build gets MIN_CPUS CPUs (reprotest's default is one);
# - after the run, any compiler server or MSBuild node still alive is listed
#   in leftover-LABEL.txt and counted in summary.tsv;
# - reprotest starts under env -i with HOME, USER, LOGNAME, SHELL and PATH
#   only: the builds inherit whatever environment it starts with
#   (reprotest-probe R4). Added 5 October 2026, after the full rerun.
#
# Usage: run.sh LAYER AXIS [LABEL]
#   LAYER  1  dotnet build of the two programs
#          2  the release job's sequence: locked restore, both publishes,
#             a hash list of release/
#          R  the whole release in one build: the frontend as in
#             phoenix-fe/run.sh, then node_modules and .next removed, as
#             CI's publish job gets only out/, then layer 2's sequence,
#             which copies out/ into wwwroot/. user_group is not set up
#             for it
#          Z  layer R, a hash list of release/, then the release zips twice:
#             as CI makes them (zip -r) in release/zip-ci, and packed
#             normalised in release/zip-norm: modes 755 or 644 by the owner's
#             x bit, every mtime set to ZEPOCH, names sorted, no extra fields
#             (zip -X), TZ=UTC. Hashes the zips
#          W  the Windows release as the reusable Windows job builds it, on
#             Linux: the frontend as in R, the locked restore, the three
#             win-x64 publishes, the migrator copied as the job copies it,
#             and both zips packed with the commit's own
#             scripts/pack-release-zip.sh. No Linux publish. Unsigned.
#             Hashes release/
#   AXIS   one reprotest variation: build_path, time, locales, umask,
#          exec_path, timezone, environment, home, kernel, aslr, num_cpus,
#          domain_host, user_group. Or "none": two builds, nothing varied. Or
#          "all": every variation that runs unprivileged here, at once.
#          user_group runs the experiment build as rb1b and needs the setup
#          of setup-user-group.sh. rb1b cannot reach /home/leos, so both
#          builds then use the SDK copy in /opt/rb1-dotnet, and a second
#          sampler runs as rb1b.
#   LABEL  names the output files; default L<LAYER>-<AXIS>
# Environment:
#   OUT       required: a private folder for logs, stores, samples, mode lists
#   MIN_CPUS  CPUs for the control build, default 2
#   FIXENV    VAR=VALUE added to every dotnet command, e.g. LC_ALL=C.UTF-8
#   LAB       the lab, default /private/tmp/rb1-phoenix; must hold no build output
#   ZEPOCH    layers Z and W: the time for the zips, e.g. the commit's
#             time (git log -1 --format=%ct)
#   DOTNET_DIR  the SDK folder, default /home/leos/.dotnet (SDK 9.0.120);
#             for .NET 10, Microsoft's SDK 10.0.401 in /private/tmp/rb1-dotnet10/sdk.
#             Not used by user_group, which always takes /opt/rb1-dotnet
#   NODE_DIR  layers R and Z: the Node folder, default /opt/rb1-node (20.20.2);
#             from the merge of main (13/10) Node 22.23.3 in /private/tmp/rb1-node22.
#   VER       layer 2's version flags, default the release's two /p: flags
#             for v0.0.0-thesis. From 5031c5af on, the release sets
#             APP_VERSION instead: run with VER= and APP_VERSION in FIXENV.
#
# Written 24 September 2026. Replaces the run-axis.sh used that morning.
# 5 October 2026: node reuse off, user_group, the leftover check.
# 7 October 2026: VER can be overridden.
# 12 October 2026: layers R and Z, DOTNET_DIR.
# 13 October 2026: NODE_DIR. Evening: layer W.
# 14 October 2026: layer W without the Linux publishes. It cut "&& \$L2"
#   off RB, which holds L2 already expanded, so nothing was cut and every
#   W build published the Linux release before the Windows one; the
#   frontend step is FRONT now. summary.tsv's experiment column says
#   "link" where reprotest found no differences and replaced experiment-1
#   with a link to control (R6); until now it hashed the control's list
#   again.
set -u
LAYER=${1:?LAYER} AXIS=${2:?AXIS}
LABEL=${3:-L$LAYER-$AXIS}
OUT=${OUT:?set OUT to a private data folder}
MIN_CPUS=${MIN_CPUS:-2} FIXENV=${FIXENV:-} LAB=${LAB:-/private/tmp/rb1-phoenix}
EXP=$(cd "$(dirname "$0")/.." && pwd)

DN=${DOTNET_DIR:-/home/leos/.dotnet} MODES=$OUT/modes SHARED=/private/tmp/rb1-shared
case $AXIS in
  none) VARY=(--vary=-all) ;;
  all)  VARY=(--vary=+all,-user_group,-fileordering,-domain_host) ;;
  user_group)
        VARY=(--vary=-all,+user_group --vary=user_group.available+=rb1b:rb1b)
        DN=/opt/rb1-dotnet MODES=$SHARED/modes ;;
  *)    VARY=("--vary=-all,+$AXIS") ;;
esac

LAUNCH=(env -i HOME="$HOME" USER="$USER" LOGNAME="$LOGNAME" SHELL=/bin/bash
        PATH=/home/leos/.local/bin:/usr/local/bin:/usr/bin)
ENV="env DOTNET_ROOT=$DN PATH=$DN:\$PATH DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 MSBUILDDISABLENODEREUSE=1"
if [ -n "$FIXENV" ]; then ENV="$ENV $FIXENV"; fi
STOP="$ENV dotnet build-server shutdown > /dev/null"
VER=${VER-'/p:Version=0.0.0-thesis /p:InformationalVersion=v0.0.0-thesis'}
L2="$ENV dotnet restore ./WS.Phoenix.sln --locked-mode $VER && $ENV dotnet publish ./src/WebAPI/WebAPI.csproj -c Release -o ./release/ws-pems-linux-x64 -r linux-x64 --self-contained true --no-restore /p:SkipSpaBuild=true $VER && $ENV dotnet publish ./src/BackgroundJobExecutor/BackgroundJobExecutor.csproj -c Release -o ./release/ws-pems-job-worker-linux-x64 -r linux-x64 --self-contained true --no-restore $VER"
NODEENV="env PATH=${NODE_DIR:-/opt/rb1-node}/bin:\$PATH CI=true npm_config_cache=/private/tmp/rb1-npm npm_config_update_notifier=false NEXT_TELEMETRY_DISABLED=1"
if [ -n "$FIXENV" ]; then NODEENV="$NODEENV $FIXENV"; fi
FRONT="( cd src/WebAPI/ClientApp && $NODEENV npm ci --offline --no-audit --no-fund && $NODEENV npm run build && rm -rf node_modules .next )"
RB="$FRONT && $L2"
ZIP=/private/tmp/rb1-tools/zip TAG=v0.0.0-thesis DIRS='ws-pems-linux-x64 ws-pems-job-worker-linux-x64'
WINPUB="$ENV dotnet restore ./WS.Phoenix.sln --locked-mode $VER && $ENV dotnet publish ./src/WebAPI/WebAPI.csproj -c Release -o ./release/win/ws-pems-win-x64 -r win-x64 --self-contained true --no-restore /p:SkipSpaBuild=true $VER && $ENV dotnet publish ./src/BackgroundJobExecutor/BackgroundJobExecutor.csproj -c Release -o ./release/win/ws-pems-job-worker-win-x64 -r win-x64 --self-contained true --no-restore $VER && $ENV dotnet publish ./src/DbMigrator/DbMigrator.csproj -c Release -o ./publish/migrator-win -r win-x64 --self-contained true --no-restore $VER && cp publish/migrator-win/ws-pems-db-migrator.exe release/win/ws-pems-db-migrator-win-x64-$TAG.exe"
case $LAYER in
  1) BUILD="$ENV dotnet build src/WebAPI/WebAPI.csproj -c Release -p:SkipSpaBuild=true && $ENV dotnet build src/BackgroundJobExecutor/BackgroundJobExecutor.csproj -c Release"
     HASHED='src/*/bin' HASHFILE=bin.sha256
     ART='bin.sha256 src/WebAPI/bin/Release/net9.0/*.dll src/WebAPI/bin/Release/net9.0/*.pdb src/WebAPI/bin/Release/net9.0/*.json src/BackgroundJobExecutor/bin/Release/net9.0/BackgroundJobExecutor.*' ;;
  2) BUILD="$L2"
     HASHED=release HASHFILE=release.sha256
     ART='release.sha256 release/*/ApplicationCore.* release/*/Infrastructure.* release/*/WebAPI.* release/*/BackgroundJobExecutor.* release/*/WebAPI release/*/BackgroundJobExecutor' ;;
  R) BUILD="$RB"
     HASHED=release HASHFILE=release.sha256
     ART='release.sha256 release/*/ApplicationCore.* release/*/Infrastructure.* release/*/WebAPI.* release/*/BackgroundJobExecutor.* release/*/WebAPI release/*/BackgroundJobExecutor release/ws-pems-linux-x64/wwwroot' ;;
  Z) ZEPOCH=${ZEPOCH:?layer Z needs ZEPOCH}
     BUILD="$RB && find release -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > release.sha256 && cd release && mkdir zip-ci zip-norm && for d in $DIRS; do $ZIP -q -r zip-ci/\$d-$TAG.zip \$d/; done && for d in $DIRS; do find \$d -type d -exec chmod 755 {} + && find \$d -type f -perm -u+x -exec chmod 755 {} + && find \$d -type f ! -perm -u+x -exec chmod 644 {} + && find \$d -exec touch -h -d @$ZEPOCH {} + && find \$d | LC_ALL=C sort | TZ=UTC $ZIP -q -X -@ zip-norm/\$d-$TAG.zip; done && cd .."
     HASHED='release/zip-ci release/zip-norm' HASHFILE=zips.sha256
     ART='zips.sha256 release.sha256 release/zip-ci release/zip-norm' ;;
  W) ZEPOCH=${ZEPOCH:?layer W needs ZEPOCH}
     BUILD="$FRONT && $WINPUB && cd release/win && for d in ws-pems-win-x64 ws-pems-job-worker-win-x64; do env PATH=/private/tmp/rb1-tools:\$PATH SOURCE_DATE_EPOCH=$ZEPOCH ../../scripts/pack-release-zip.sh \$d ../\$d-$TAG.zip; done && cd ../.."
     HASHED=release HASHFILE=release.sha256
     ART="release.sha256 release/*.zip release/win/ws-pems-db-migrator-win-x64-$TAG.exe" ;;
  *) echo "LAYER must be 1, 2, R, Z or W" >&2; exit 2 ;;
esac

mkdir -p "$OUT/modes" "$MODES"
if ls -d $LAB/bin $LAB/obj $LAB/release $LAB/src/*/bin $LAB/src/*/obj $LAB/tests/bin $LAB/tests/obj > /dev/null 2>&1; then
  echo "the lab holds build output; clean it first" >&2; exit 2
fi
if [ "$LAYER" = R ] || [ "$LAYER" = Z ] || [ "$LAYER" = W ]; then
  for d in node_modules .next out; do
    if [ -e "$LAB/src/WebAPI/ClientApp/$d" ]; then echo "the lab holds ClientApp/$d; export it again" >&2; exit 2; fi
  done
fi
if [ -e "$OUT/store-$LABEL" ]; then echo "$OUT/store-$LABEL exists" >&2; exit 2; fi

# One build: shutdown, the build, the hash list, the mode list, shutdown again.
# reprotest runs this under sh -e; "|| rc=$?" keeps a failed build from
# skipping the last shutdown, and the build's exit code is kept.
CMD="$STOP; rc=0; ( $BUILD && find $HASHED -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > $HASHFILE && find $HASHED -type f -printf '%m %p\n' | LC_ALL=C sort > $MODES/$LABEL-\$(umask)-\$\$.txt ) || rc=\$?; $STOP; exit \$rc"
printf '%s\n%s\n%s\n%s\n' "${LAUNCH[*]}" "${VARY[*]} --min-cpus $MIN_CPUS" "$CMD" "$ART" > "$OUT/rt-$LABEL.cmd"

eval "$STOP"
DOTNET_EXE=$DN/dotnet python3 "$EXP/sample-dotnet.py" "$OUT/samples-$LABEL.txt" &
SAMPLER=$!
if [ "$AXIS" = user_group ]; then
  # NuGet creates its user config with mode 0600, so rb1b could not read it.
  # It lists only nuget.org.
  chmod 644 /tmp/dch/.nuget/NuGet/NuGet.Config || exit 2
  cp "$EXP/sample-dotnet.py" "$SHARED/sample-dotnet.py"
  sudo -n -u rb1b env DOTNET_EXE=$DN/dotnet python3 "$SHARED/sample-dotnet.py" "$SHARED/samples-$LABEL-rb1b.txt" &
fi
START=$(date -Is)
cd "$LAB" || exit 1
timeout 3600 "${LAUNCH[@]}" /home/leos/.local/bin/reprotest -v --min-cpus "$MIN_CPUS" --store-dir "$OUT/store-$LABEL" \
  "${VARY[@]}" -c "$CMD" "$LAB" "$ART" > "$OUT/rt-$LABEL.log" 2>&1
RC=$?
sleep 2
kill $SAMPLER
eval "$STOP"
if [ "$AXIS" = user_group ]; then
  sudo -n -u rb1b pkill -u rb1b -f "[s]amples-$LABEL-rb1b"
  cp "$SHARED/samples-$LABEL-rb1b.txt" "$OUT/"
  cp "$MODES/$LABEL-"* "$OUT/modes/"
fi
pgrep -af -- 'nodemode:|VBCSCompiler' | grep -v JetBrains > "$OUT/leftover-$LABEL.txt"
LEFT=$(wc -l < "$OUT/leftover-$LABEL.txt")

C="$OUT/store-$LABEL/control/source-root/$HASHFILE"
E="$OUT/store-$LABEL/experiment-1/source-root/$HASHFILE"
CM=$( [ -f "$C" ] && sha256sum < "$C" | cut -c1-16 || echo -)
EM=$( [ -L "$OUT/store-$LABEL/experiment-1" ] && echo link || { [ -f "$E" ] && sha256sum < "$E" | cut -c1-16 || echo -; } )
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$LABEL" "$LAYER" "$AXIS" "$START" "$(date -Is)" "$RC" "$CM" "$EM" "$LEFT" >> "$OUT/summary.tsv"
echo "$LABEL exit $RC control $CM experiment $EM leftover $LEFT"
