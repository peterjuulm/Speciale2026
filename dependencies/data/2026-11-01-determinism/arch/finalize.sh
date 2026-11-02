#!/bin/bash
# After worker 1 ends: recompare, classify, summary, then copy text only into Speciale2026/data/2026-11-01-determinism/arch/.
set -u
LAB=/private/tmp/nupkg-determinism
EXP=/home/leos/Dev/Speciale2026/dependencies/experiments/nupkg
DATA=/home/leos/Dev/Speciale2026/dependencies/data/2026-11-01-determinism/arch
cd $EXP || exit 1
if pgrep -f 'determinism.py batch' | while read p; do grep -q shell-snapshots /proc/$p/cmdline || echo $p; done | grep -q .; then echo "a batch is still running; not finalizing"; exit 2; fi
python3 -I determinism.py recompare $LAB > $LAB/recompare.log 2>&1; echo "recompare rc=$?"
mkdir -p $DATA/out
python3 -I determinism.py classify $LAB $DATA/results.tsv; echo "classify rc=$?"
python3 -I determinism-summary.py $LAB $DATA > /dev/null; echo "summary rc=$?"
cp $LAB/kommando.txt $LAB/environment.txt $LAB/run.log $LAB/full.log $LAB/pilot.log $LAB/nodatime-rerun.log $LAB/recompare.log $DATA/ 2>/dev/null
# per package: state, logs (whole up to 512 KB, else head and tail), comparison diffs and hash lists; never a .nupkg/.snupkg/.dll
n=0
for d in $LAB/out/*/; do id=$(basename $d); mkdir -p $DATA/out/$id
  for f in $d/state.json $d/*.log; do [ -f "$f" ] || continue
    if [ $(stat -c %s "$f") -le 524288 ]; then cp "$f" $DATA/out/$id/; else { head -200 "$f"; echo; echo "[... $(wc -l < "$f") lines, excerpt: first and last 200 ...]"; echo; tail -200 "$f"; } > $DATA/out/$id/$(basename "$f"); fi; n=$((n+1)); done
  for s in $d/*-store; do [ -d "$s" ] || continue; sn=$(basename $s); mkdir -p $DATA/out/$id/$sn
    for f in $s/experiment-1.diff $s/SHA256SUMS; do [ -f "$f" ] && cp "$f" $DATA/out/$id/$sn/ && n=$((n+1)); done
    for side in control experiment-1; do [ -d $s/$side ] && (cd $s/$side && find . -type f -printf '%s %p\n' | sort -k2) > $DATA/out/$id/$sn/$side.files.txt; done
  done
done
echo "copied $n files"; du -sh $DATA; find $DATA -type f \( -name '*.nupkg' -o -name '*.snupkg' -o -name '*.dll' \) | wc -l
echo "== FINALIZE DONE $(date -Iseconds)"
