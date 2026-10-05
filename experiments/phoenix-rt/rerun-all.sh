#!/bin/bash
# Every reprotest axis on both layers, layer 2 first. Run on 24 September 2026
# (stopped after six runs) and in full on 5 October 2026.
# Usage: OUT=<private folder> rerun-all.sh
#   The lab must already be the export of the commit. Each run appends a line
#   to $OUT/summary.tsv; run.sh skips a label whose store already exists.
set -u
R=$(cd "$(dirname "$0")" && pwd)/run.sh
export OUT=${OUT:?set OUT to a private data folder} MIN_CPUS=2
for L in 2 1; do
  for A in none build_path time locales umask exec_path timezone environment home kernel aslr num_cpus; do
    FIXENV= "$R" $L $A
  done
  FIXENV=LC_ALL=C.UTF-8 "$R" $L locales L$L-locales-fixed
  FIXENV= "$R" $L all
  FIXENV=LC_ALL=C.UTF-8 "$R" $L all L$L-all-fixed
  FIXENV= "$R" $L user_group
done
echo "rerun done $(date -Is)"
