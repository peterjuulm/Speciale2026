#!/bin/bash
# One reprotest run the way Benedetti et al.'s wrapper calls it, with the
# process sampler around it. Usage: run.sh ECO AXIS   (AXIS: umask or time)
# Written 24 September 2026 for toolchain-servers.
set -u
ECO=$1 AXIS=$2
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=/home/leos/Dev/Speciale2026/data/2026-09-24-toolchain-servers/arch
STORE=/home/leos/Dev/speciale-2026/data/toolchain-servers/arch
SDE='SOURCE_DATE_EPOCH=1709311372 '
[ "$AXIS" = time ] && SDE=''
case $ECO in
  npm)    CMD="mkdir dest && HOME=/home/leos npm pack --pack-destination='./dest'"; ART='dest/*.tgz' ;;
  pip)    CMD="${SDE}pip3 wheel -w dist --no-deps ."; ART='dist/*.whl' ;;
  gem)    CMD="${SDE}gem build *.gemspec"; ART='*.gem' ;;
  maven)  CMD="mvn clean install"; ART='target/*' ;;
  go)     CMD="GOTOOLCHAIN=local go build -o out/rb1min ."; ART='out/*' ;;
  dotnet) CMD="env DOTNET_ROOT=/home/leos/.dotnet PATH=/home/leos/.dotnet:\$PATH DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release"; ART='bin/Release/net9.0/*' ;;
  *) echo "unknown $ECO"; exit 2 ;;
esac
export PATH=/usr/local/bin:/usr/bin:/home/leos/.local/bin:/home/leos/.local/opt/apache-maven-3.9.16/bin
mkdir -p $OUT $STORE
cd $HERE/$ECO || exit 1
printf '%s\n%s\n' "$CMD" "$ART" > $OUT/rt-$ECO-$AXIS.cmd
python3 /home/leos/Dev/Speciale2026/experiments/sample-tree.py $OUT/samples-$ECO-$AXIS.txt $$ &
SAMPLER=$!
echo "start $(date -Is)" > $OUT/rt-$ECO-$AXIS.time
timeout 900 reprotest -v --store-dir $STORE/rt-$ECO-$AXIS-store --variations=$AXIS "$CMD" "$ART" > $OUT/rt-$ECO-$AXIS.log 2>&1
RC=$?
echo "end $(date -Is) exit $RC" >> $OUT/rt-$ECO-$AXIS.time
sleep 3
kill $SAMPLER
echo "$ECO $AXIS exit $RC"
