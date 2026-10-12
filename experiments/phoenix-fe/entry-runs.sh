#!/bin/bash
# The entry-order experiment's six runs (W47), on the lab from entry-lab.sh.
#   T2  three runs of `none`, entries logged only: does Next's entry order
#       vary between builds, and does it decide which export comes out?
#   T4  `none`, `all` and `build_path` with the client's entries sorted: do
#       all builds then give one export?
# Usage: OUT=<private folder> entry-runs.sh
# Written 12 October 2026.
set -u
R=$(cd "$(dirname "$0")" && pwd)/run.sh
export OUT=${OUT:?set OUT to a private data folder} MIN_CPUS=2 LAB=/private/tmp/rb1-fe-entry
LOG=$OUT/entry-log
mkdir -p "$LOG"
for n in 1 2 3; do
  FIXENV="ENTRY_LOG_DIR=$LOG ENTRY_LOG_TAG=E-log-$n" "$R" none "E-log-$n"
done
for A in none all build_path; do
  FIXENV="ENTRY_LOG_DIR=$LOG ENTRY_LOG_TAG=E-sort-$A ENTRY_SORT=1" "$R" "$A" "E-sort-$A"
done
echo "entry runs done $(date -Is)"
