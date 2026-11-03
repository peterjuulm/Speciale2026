#!/bin/bash
# After the reruns: results, summary, environment into the 2a results/ folder, then a text-only copy of the
# lab into Speciale2026/dependencies/data/2026-11-02-determinism/arch/. Never a .nupkg/.snupkg/.dll.
set -u
LAB=/private/tmp/nupkg-determinism
EXP=/home/leos/Dev/dotnet-rebuild-experiments/2-dependencies/2a-determinism
DATA=/home/leos/Dev/Speciale2026/dependencies/data/2026-11-02-determinism/arch
cd $EXP || exit 1
if pgrep -f "^python3 -I (scripts/)?build-and-compare.py batch" >/dev/null; then echo "a batch is still running"; exit 2; fi
python3 -I scripts/build-and-compare.py results $LAB results/runs.tsv; echo "results rc=$?"
python3 -I scripts/build-and-compare.py environment $LAB > /dev/null; echo "environment rc=$?"
python3 -I scripts/summary.py $LAB results > /dev/null; echo "summary rc=$?"
cp $LAB/environment.txt results/environment.txt
mkdir -p $DATA/out
cp results/runs.tsv $DATA/results.tsv; cp results/categories.tsv results/summary.md results/environment.txt $DATA/
cp $LAB/kommando.txt $LAB/run.log $DATA/
for f in $LAB/night-w?.log $LAB/rerun-w?.log $LAB/slice-?.tsv $LAB/roslyn-?.tsv $LAB/rerun-?.tsv $LAB/rerun2-w?.log $LAB/rerun2-?.tsv $LAB/rerun3-w1.log $LAB/rerun3.tsv; do cp $f $DATA/; done
cp $EXP/population.tsv $DATA/
n=0
for d in $LAB/out/*/; do id=$(basename $d); mkdir -p $DATA/out/$id
  for f in $d/state.json $d/*.log; do [ -f "$f" ] || continue
    if [ $(stat -c %s "$f") -le 524288 ]; then cp "$f" $DATA/out/$id/; else { head -200 "$f"; echo; echo "[... $(wc -l < "$f") lines, excerpt: first and last 200 ...]"; echo; tail -200 "$f"; } > $DATA/out/$id/$(basename "$f"); fi; n=$((n+1)); done
  for s in $d/*-store; do [ -d "$s" ] || continue; sn=$(basename $s); mkdir -p $DATA/out/$id/$sn
    for f in $s/experiment-1.diff $s/SHA256SUMS; do [ -f "$f" ] && cp "$f" $DATA/out/$id/$sn/ && n=$((n+1)); done
    for side in control experiment-1; do [ -d $s/$side ] && (cd $s/$side && find . -type f -printf '%s %p\n' | sort -k2) > $DATA/out/$id/$sn/$side.files.txt; done
  done
done
# the screens that failed on the full disk, kept for the record (state and screen log only)
mkdir -p $DATA/retired-nospace
for d in $LAB/retired/*-nospace/; do id=$(basename $d); mkdir -p $DATA/retired-nospace/$id; cp $d/state.json $d/screen.log $DATA/retired-nospace/$id/ 2>/dev/null; done
echo "copied $n files"; du -sh $DATA; find $DATA -type f \( -name '*.nupkg' -o -name '*.snupkg' -o -name '*.dll' \) | wc -l
echo "== EXPORT DONE $(date -Iseconds)"
