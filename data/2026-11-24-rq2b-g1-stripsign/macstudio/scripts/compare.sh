#!/bin/bash
# G1: the eight "identical without signatures" rows of RQ2b, compared as complete DLLs with stripsign.cs.
# For each package: extract the shipped DLL from the 27 Oct Windows build A (and A2), from the nuget.org
# package the runner downloaded, and from the nuget.org package downloaded here today; hash all; check the
# stored report hashes at Speciale2026 f127442; run stripsign.cs (unchanged, and the full-hash copy) on
# nuget.org (today) against A.
set -euo pipefail
LAB=/private/tmp/rb2-g1
REPO=/Users/leo/Dev/Speciale2026
cd "$LAB"
out=results; mkdir -p "$out" dll
: > $out/sha256.tsv; : > $out/stripsign.txt; : > $out/stripsign-full.txt; : > $out/stored-check.tsv
printf 'package\tfile\tsha256\tbytes\n' >> $out/sha256.tsv
printf 'package\tfile\tsha256_here\tsha256_stored\tstored_in\tmatch\n' >> $out/stored-check.tsv
while IFS=$'\t' read -r name run ships batch; do
  art=$(echo artifacts/$name/*/)
  d=dll/$name; mkdir -p $d
  unzip -p "$(ls $art/A/*.nupkg)"  "$ships" > $d/A.dll
  unzip -p "$(ls $art/A2/*.nupkg)" "$ships" > $d/A2.dll
  unzip -p "$(ls $art/nuget-org/*.nupkg)" "$ships" > $d/nugetorg-runner-2026-10-27.dll
  base=${name%-rerun-*}; id=${base%-*}; ver=${base##*-}; l=$(echo "$id" | tr A-Z a-z)
  unzip -p nugetorg/$l.$ver.nupkg "$ships" > $d/nugetorg.dll
  for f in A A2 nugetorg-runner-2026-10-27 nugetorg; do
    printf '%s\t%s\t%s\t%s\n' "$name" "$f.dll" "$(shasum -a 256 $d/$f.dll | cut -d' ' -f1)" "$(stat -f %z $d/$f.dll)" >> $out/sha256.tsv
  done
  # The stored reports exist for the 27 October run only.
  if [ "$name" = "$base" ]; then
    rep=dependencies/data/2026-10-27-nupkg-release-only-$batch/windows-2022/$name/level
    for pair in A:report-A nugetorg:report-nugetorg; do
      f=${pair%%:*}; r=${pair#*:}
      stored=$(git -C $REPO show f127442:$rep/$r.txt | sed -n 's/^sha256: //p' | head -1)
      here=$(shasum -a 256 $d/$f.dll | cut -d' ' -f1)
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$f.dll" "$here" "$stored" "f127442:$rep/$r.txt" "$([ "$here" = "$stored" ] && echo yes || echo NO)" >> $out/stored-check.tsv
    done
  fi
  printf '%s\t' "$name" >> $out/stripsign.txt
  scripts/denv dotnet ss/bin/Release/net10.0/ss.dll "$LAB/$d/nugetorg.dll" "$LAB/$d/A.dll" >> $out/stripsign.txt
  printf '%s\t' "$name" >> $out/stripsign-full.txt
  scripts/denv dotnet ss-full/bin/Release/net10.0/ss.dll "$LAB/$d/nugetorg.dll" "$LAB/$d/A.dll" >> $out/stripsign-full.txt
done < runs.tsv
column -t -s$'\t' $out/stored-check.tsv
echo; cat $out/stripsign.txt; echo; cat $out/stripsign-full.txt
