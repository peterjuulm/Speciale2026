#!/bin/bash
# Every reprotest axis on layer 3, the frontend, after the timing run on
# `none`. aslr is left out: alone it changes nothing (reprotest-probe R1).
# Usage: OUT=<private folder> all-axes.sh
#   The lab must already be the export of the commit. Each run appends a line
#   to $OUT/summary.tsv; run.sh skips a label whose store already exists.
# Written 12 October 2026.
set -u
R=$(cd "$(dirname "$0")" && pwd)/run.sh
export OUT=${OUT:?set OUT to a private data folder} MIN_CPUS=2
for A in build_path time locales umask exec_path timezone environment home kernel num_cpus user_group all; do
  "$R" $A
done
echo "all axes done $(date -Is)"
