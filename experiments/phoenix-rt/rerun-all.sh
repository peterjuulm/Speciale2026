#!/bin/bash
# The rerun of 24 September 2026: every axis, layer 2 first, then layer 1.
# Usage: rerun-all.sh   (the lab must already be the export of the commit)
# Each run appends a line to $OUT/summary.tsv.
set -u
R=$(cd "$(dirname "$0")" && pwd)/run.sh
export OUT=/home/leos/Dev/speciale-2026/data/phoenix-rerun/arch MIN_CPUS=2
for L in 2 1; do
  for A in none build_path time locales umask exec_path timezone environment home kernel aslr num_cpus; do
    FIXENV= "$R" $L $A
  done
  FIXENV=LC_ALL=C.UTF-8 "$R" $L locales L$L-locales-fixed
  FIXENV= "$R" $L all
  FIXENV=LC_ALL=C.UTF-8 "$R" $L all L$L-all-fixed
done
echo "rerun done $(date -Is)"
