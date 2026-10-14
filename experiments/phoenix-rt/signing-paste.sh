#!/bin/bash
# Step 3b of signing-probe.sh (written 14 October 2026): the paste again,
# with the trust file given to attach-signature and each pasted file given
# its rebuilt twin's mode, and two more negative controls.
#
#   OUT=<the probe's private folder> PACK=<pack-release-zip.sh> signing-paste.sh EPOCH TAG
#
# Works on the probe's trees in /private/tmp/rb1-sign: A1 signed, B
# unsigned, sig/ the signatures step 3 extracted from A1.
set -u
EPOCH=${1:?EPOCH} TAG=${2:?TAG}
OUT=${OUT:?set OUT to the probe folder} PACK=${PACK:?set PACK to pack-release-zip.sh}
L=/private/tmp/rb1-sign IMG=ws-signing:rb-test K=$OUT/keys
ZIPS="ws-pems-win-x64 ws-pems-job-worker-win-x64" MIG=win/ws-pems-db-migrator-win-x64-$TAG.exe
CA="-CAfile /keys/verify.pem -TSA-CAfile /keys/verify.pem"
run() { docker run --rm --user "$(id -u):$(id -g)" -v "$L:$L" -v "$K:/keys:ro" "$@"; }
inside() { run -w "$L" --entrypoint bash "$IMG" -c "$1"; }
same() { if cmp -s "$1" "$2"; then echo "same  $3"; else echo "DIFF  $3"; fi; }

echo "== 3b $(date +%T)"
rm -rf "$L/P2" "$L/zips-P2" "$L/N2" && cp -a "$L/B" "$L/P2" && mkdir -p "$L/N2"
inside "while read -r f; do if osslsigncode attach-signature $CA -sigin sig/\$f.p7 -in B/\$f -out P2/\$f.tmp > /tmp/a.log 2>&1; then chmod --reference=B/\$f P2/\$f.tmp && mv P2/\$f.tmp P2/\$f; else echo \"ATTACH FAILED \$f\"; tail -3 /tmp/a.log; fi; done < $L/to-sign.txt" > "$OUT/paste2.log" 2>&1
echo "attach failures: $(grep -c 'ATTACH FAILED' "$OUT/paste2.log")"
( cd "$L" && while read -r f; do cmp -s "A1/$f" "P2/$f" && echo "same $f" || echo "differ $f"; done < "$OUT/pe-files.txt" ) > "$OUT/paste2.txt"
echo "pasted against A1: $(grep -c '^same' "$OUT/paste2.txt") same, $(grep -c '^differ' "$OUT/paste2.txt") differ"
( cd "$L/A1" && find win -type f -printf '%m %p\n' | LC_ALL=C sort ) > "$OUT/modes-A1.txt"
( cd "$L/P2" && find win -type f -printf '%m %p\n' | LC_ALL=C sort ) > "$OUT/modes-P2.txt"
same "$OUT/modes-A1.txt" "$OUT/modes-P2.txt" "3b every file's mode and path, pasted against A1 ($(wc -l < "$OUT/modes-A1.txt") files)"
inside "while read -r f; do if osslsigncode verify $CA -ignore-crl -in P2/\$f > /tmp/v.log 2>&1 && grep -q 'Timestamp Server Signature verification: ok' /tmp/v.log; then echo \"ok \$f\"; else echo \"FAILED \$f\"; fi; done < $L/to-sign.txt" > "$OUT/paste2-verify.txt"
echo "pasted signatures verified: $(grep -c '^ok' "$OUT/paste2-verify.txt") ok, $(grep -c '^FAILED' "$OUT/paste2-verify.txt") failed"
mkdir -p "$L/zips-P2" && ( cd "$L/P2/win" && for z in $ZIPS; do env PATH=/private/tmp/rb1-tools:/usr/bin SOURCE_DATE_EPOCH="$EPOCH" "$PACK" "$z" "$L/zips-P2/$z-$TAG.zip" || exit 1; done )
for z in $ZIPS; do same "$L/zips-A1/$z-$TAG.zip" "$L/zips-P2/$z-$TAG.zip" "3b $z zip, pasted against A1"; done
same "$L/A1/$MIG" "$L/P2/$MIG" "3b the migrator, pasted against A1"

echo "== negative controls $(date +%T)"
inside "osslsigncode attach-signature $CA -sigin sig/win/ws-pems-win-x64/Infrastructure.dll.p7 -in B/win/ws-pems-win-x64/ApplicationCore.dll -out N2/wrong.dll > N2/wrong.log 2>&1; echo \"another file's signature: attach exit \$?\"; grep -E 'MISMATCH|Signature verification' N2/wrong.log | head -2"
cp "$L/B/$MIG" "$L/N2/migrator.exe"
python3 - "$L/N2/migrator.exe" <<'PY'
import sys
p = sys.argv[1]
with open(p, "r+b") as f:
    f.seek(0, 2)
    i = f.tell() - 4096
    f.seek(i)
    b = f.read(1)
    f.seek(i)
    f.write(bytes([b[0] ^ 0x01]))
print(f"flipped bit 0 of byte {i}, 4096 before the end of the bundle")
PY
inside "osslsigncode attach-signature $CA -sigin sig/$MIG.p7 -in N2/migrator.exe -out N2/migrator-signed.exe > N2/migrator.log 2>&1; echo \"changed bundle: attach exit \$?\"; grep -E 'MISMATCH|Signature verification' N2/migrator.log | head -2"
echo "== end $(date +%T)"
