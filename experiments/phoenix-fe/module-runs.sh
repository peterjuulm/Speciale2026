#!/bin/bash
# The module-order experiment's builds (W51), on the lab from module-lab.sh.
# Plain builds, one after another at the same path, not under reprotest:
# each removes node_modules, .next and out, installs from the filled npm
# cache without network and runs the release's build command, under env -i.
#
#   B0      no jitter, no sort: the commit as it builds
#   J1-J6   MODULE_JITTER_SEED 1-6: does the module order change with the
#           timing, and does the export follow it?
#   S1-S4   MODULE_JITTER_SEED 1-4 and MODULE_SORT=1: one export whatever
#           the timing?
#   Dn...   seed n, the sort and MODULE_CHUNK_LOG=1, and a copy of the
#           export kept as out-LABEL, e.g. D2 and D2r for seed 2 twice
#   Rn...   as Dn with MODULE_ROOT_LOG=1, without the copy
#   Cn, In  fix candidates with the module sort: C sorts the connections
#           too (MODULE_SORT_CONNECTIONS), I numbers unnamed chunks by
#           content (CHUNK_IDS_BY_CONTENT); seed n, 0 for no jitter
#   On      as Cn, the outgoing connections only
#
# Usage: OUT=<private folder> module-runs.sh [LABEL...]   (default: all)
# OUT gets per build LABEL.sha256 (the export's hash list), LABEL.log, and
# module-log/ with one module-order line per compilation.
# Written 12 October 2026.
set -u
OUT=${OUT:?set OUT to a private data folder}
lab=${LAB:-/private/tmp/rb1-fe-module}
app=$lab/src/WebAPI/ClientApp
mkdir -p "$OUT/module-log"
labels=("$@")
[ ${#labels[@]} -eq 0 ] && labels=(B0 J1 J2 J3 J4 J5 J6 S1 S2 S3 S4)
for label in "${labels[@]}"; do
  seed=$(printf '%s' "$label" | sed -E 's/^[A-Z]([0-9]+).*$/\1/') keep=0
  case $label in
    B0) extra=() ;;
    J*) extra=("MODULE_JITTER_SEED=$seed") ;;
    S*) extra=("MODULE_JITTER_SEED=$seed" MODULE_SORT=1) ;;
    D*) extra=("MODULE_JITTER_SEED=$seed" MODULE_SORT=1 MODULE_CHUNK_LOG=1) keep=1 ;;
    R*) extra=("MODULE_JITTER_SEED=$seed" MODULE_SORT=1 MODULE_CHUNK_LOG=1 MODULE_ROOT_LOG=1) ;;
    C*) extra=(MODULE_SORT=1 MODULE_SORT_CONNECTIONS=1 MODULE_CHUNK_LOG=1) ;;
    O*) extra=(MODULE_SORT=1 MODULE_SORT_CONNECTIONS=out MODULE_CHUNK_LOG=1) ;;
    I*) extra=(MODULE_SORT=1 CHUNK_IDS_BY_CONTENT=1 MODULE_CHUNK_LOG=1) ;;
    *) echo "unknown label $label" >&2; exit 2 ;;
  esac
  # C and I: seed 0 means no jitter
  case $label in C*|I*|O*) [ "$seed" != 0 ] && extra+=("MODULE_JITTER_SEED=$seed") ;; esac
  [ -e "$OUT/$label.sha256" ] && { echo "$OUT/$label.sha256 exists" >&2; exit 2; }
  start=$(date +%H:%M:%S)
  ( cd "$app" && rm -rf node_modules .next out && env -i HOME="$HOME" PATH=/opt/rb1-node/bin:/usr/bin CI=true \
      npm_config_cache=/private/tmp/rb1-npm npm_config_update_notifier=false NEXT_TELEMETRY_DISABLED=1 \
      APP_VERSION=v0.0.0-thesis MODULE_LOG_DIR="$OUT/module-log" MODULE_LOG_TAG="$label" "${extra[@]}" \
      bash -c 'npm ci --offline --no-audit --no-fund && npm run build' ) > "$OUT/$label.log" 2>&1
  rc=$?
  if [ $rc -eq 0 ]; then
    ( cd "$app" && find out -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum ) > "$OUT/$label.sha256"
    [ $keep -eq 1 ] && cp -a "$app/out" "$OUT/out-$label"
  fi
  echo "$label $start-$(date +%H:%M:%S) exit $rc list $( [ $rc -eq 0 ] && sha256sum < "$OUT/$label.sha256" | cut -c1-16 || echo -)"
done
( cd "$app" && rm -rf node_modules .next )
echo "module runs done $(date -Is)"
