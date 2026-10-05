#!/bin/bash
# reprotest checked against itself. probe.sh is a "build" of shell commands
# that writes down what it sees; this runs it under reprotest once per axis,
# with -vv, so the log holds the exact script reprotest executes.
#
# Usage: OUT=<private folder> run.sh
#   Two rounds:
#   inherited  reprotest started from the calling shell, as the Phoenix runs are
#   clean      reprotest started under env -i, with HOME, USER, LOGNAME, SHELL
#              and PATH only
#   The stores hold each build's whole environment, so OUT must be private.
#   summarize.py turns them into a summary without the values.
#
# Written 5 October 2026.
set -u
OUT=${OUT:?set OUT to a private folder}
HERE=$(cd "$(dirname "$0")" && pwd)
LAB=/private/tmp/rb1-probe
RT=/home/leos/.local/bin/reprotest
CLEAN=(env -i HOME="$HOME" USER="$USER" LOGNAME="$LOGNAME" SHELL=/bin/bash
       PATH=/home/leos/.local/bin:/usr/local/bin:/usr/bin)

rm -rf "$LAB" && mkdir -p "$LAB" && cp "$HERE/probe.sh" "$LAB/"
mkdir -p "$OUT"

one() {  # one ROUND AXIS
  local round=$1 axis=$2 label=$1-$2 vary pre=()
  case $axis in
    none) vary=(--vary=-all) ;;
    all)  vary=(--vary=+all,-user_group,-fileordering,-domain_host) ;;
    user_group) vary=(--vary=-all,+user_group --vary=user_group.available+=rb1b:rb1b) ;;
    *)    vary=("--vary=-all,+$axis") ;;
  esac
  if [ "$round" = clean ]; then pre=("${CLEAN[@]}"); fi
  (cd "$LAB" && "${pre[@]}" timeout 300 "$RT" -vv --min-cpus 2 --store-dir "$OUT/store-$label" \
     "${vary[@]}" -c 'sh probe.sh' . 'probe/*' > "$OUT/rt-$label.log" 2>&1)
  echo "$label exit $?"
}

for a in none build_path time locales umask exec_path timezone environment home \
         kernel aslr num_cpus user_group all domain_host fileordering; do
  one inherited $a
done
for a in none user_group all; do
  one clean $a
done
