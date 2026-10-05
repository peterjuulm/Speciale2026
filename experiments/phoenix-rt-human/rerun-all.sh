#!/bin/bash
#
# Rerun every axis on the Phoenix lab, layer 2 first, then layer 1.
# The lab must already be the export of the commit you are measuring.
# Each run adds a line to $OUT/summary.tsv.

set -u

run=$(cd "$(dirname "$0")" && pwd)/run.sh

export OUT=/home/leos/Dev/speciale-2026/data/phoenix-rerun/arch
export MIN_CPUS=2

axes=(none build_path time locales umask exec_path timezone environment home kernel aslr num_cpus)
fix=LC_ALL=C.UTF-8

for layer in 2 1; do
    for axis in "${axes[@]}"; do
        FIXENV= "$run" $layer $axis
    done

    # Then locales with the locale fix, and all without and with it.
    FIXENV=$fix "$run" $layer locales L$layer-locales-fixed
    FIXENV= "$run" $layer all
    FIXENV=$fix "$run" $layer all L$layer-all-fixed
done

echo "rerun done $(date -Is)"
