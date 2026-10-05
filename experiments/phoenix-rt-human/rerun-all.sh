#!/bin/bash
#
# Run every reprotest axis on the Phoenix lab, layer 2 first, then layer 1.
# The lab must already be the export of the commit you are measuring.
#
#   OUT=<private folder> rerun-all.sh
#
# Each run adds a line to $OUT/summary.tsv. run.sh refuses a label whose
# store already exists, so calling this again only runs what's missing.

set -u

run=$(cd "$(dirname "$0")" && pwd)/run.sh

if [ -z "${OUT:-}" ]; then
    echo "rerun-all.sh: set OUT to a private data folder" >&2
    exit 1
fi
export OUT
export MIN_CPUS=2

axes=(none build_path time locales umask exec_path timezone environment home kernel aslr num_cpus)
fix=LC_ALL=C.UTF-8

for layer in 2 1; do
    for axis in "${axes[@]}"; do
        FIXENV= "$run" $layer $axis
    done

    # Then locales with the locale fix, all without and with it, and
    # user_group last (it needs setup-user-group.sh).
    FIXENV=$fix "$run" $layer locales L$layer-locales-fixed
    FIXENV= "$run" $layer all
    FIXENV=$fix "$run" $layer all L$layer-all-fixed
    FIXENV= "$run" $layer user_group
done

echo "rerun done $(date -Is)"
