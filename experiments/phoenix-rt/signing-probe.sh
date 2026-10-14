#!/bin/bash
# The Windows release signed twice, stripped and pasted (written 14 October 2026).
#
#   OUT=<private folder> PACK=<pack-release-zip.sh> signing-probe.sh A B EPOCH TAG
#
# A and B are two unsigned builds' release folders as run.sh's layer W keeps
# them in a store (store-*/control/source-root/release: the two Windows zips
# and win/ws-pems-db-migrator-win-x64-TAG.exe). A stands in for the release,
# B for a rebuild. EPOCH is the commit's time, for the packing. The signing
# image is ws-signing:rb-test (docker build deployment/signing), run as the
# release job runs it, with its local path: SIGN_WITH_KEYSTORE and a test
# certificate in $OUT/keys (test.p12, its password in password.txt, and
# verify.pem: the test CA and the Microsoft root the timestamps chain to).
#
#   0  both builds unzipped into trees; A's trees packed again
#   1  two copies of A signed, A1 and A2
#   2  every file signed in A1 stripped (remove-signature), compared with A
#   3  every signature of A1 extracted and attached to B's file; compared
#      with A1, verified; the pasted tree packed and its zips compared
#   4  a negative control: one byte of B's ApplicationCore.dll changed
#      before pasting
#
# Trees go to /private/tmp/rb1-sign, lists and logs to $OUT.
set -u
A=${1:?A} B=${2:?B} EPOCH=${3:?EPOCH} TAG=${4:?TAG}
OUT=${OUT:?set OUT to a private data folder} PACK=${PACK:?set PACK to pack-release-zip.sh}
L=/private/tmp/rb1-sign IMG=ws-signing:rb-test K=$OUT/keys
ZIPS="ws-pems-win-x64 ws-pems-job-worker-win-x64" MIG=ws-pems-db-migrator-win-x64-$TAG.exe
CA="-CAfile /keys/verify.pem -TSA-CAfile /keys/verify.pem -ignore-crl"
run() { docker run --rm --user "$(id -u):$(id -g)" -v "$L:$L" -v "$K:/keys:ro" "$@"; }
inside() { run -w "$L" --entrypoint bash "$IMG" -c "$1"; }

tree() {  # release folder, tree
  mkdir -p "$2/win" && for z in $ZIPS; do unzip -q "$1/$z-$TAG.zip" -d "$2/win" || return 1; done
  cp "$1/win/$MIG" "$2/win/"
}
pack() {  # tree, folder for the zips
  mkdir -p "$2" && ( cd "$1/win" && for z in $ZIPS; do
    env PATH=/private/tmp/rb1-tools:/usr/bin SOURCE_DATE_EPOCH="$EPOCH" "$PACK" "$z" "$2/$z-$TAG.zip" || exit 1
  done )
}
same() { if cmp -s "$1" "$2"; then echo "same  $3"; else echo "DIFF  $3"; fi; }

rm -rf "$L" && mkdir -p "$L" "$OUT"
echo "== 0 $(date +%T)"
tree "$A" "$L/A" && tree "$B" "$L/B" || exit 1
pack "$L/A" "$L/zips-A"
for z in $ZIPS; do same "$A/$z-$TAG.zip" "$L/zips-A/$z-$TAG.zip" "0 $z zip packed again"; done
( cd "$L/A" && find win -type f \( -iname '*.exe' -o -iname '*.dll' \) | LC_ALL=C sort ) > "$OUT/pe-files.txt"
cp "$OUT/pe-files.txt" "$L/pe-files.txt"
inside "cd A && python3 /opt/signing/pe-signed.py < $L/pe-files.txt" > "$OUT/pe-before.txt" 2>&1 || true
awk '$1 == "unsigned" { sub(/^unsigned /, ""); print }' "$OUT/pe-before.txt" > "$OUT/to-sign.txt"
cp "$OUT/to-sign.txt" "$L/to-sign.txt"
echo "PE files $(wc -l < "$OUT/pe-files.txt"), unsigned $(wc -l < "$OUT/to-sign.txt")"

echo "== 1 $(date +%T)"
for c in A1 A2; do
  cp -a "$L/A" "$L/$c"
  run -w "$L/$c" -e SIGN_WITH_KEYSTORE=/keys/test.p12 -e SIGN_KEYSTORE_PASSWORD="$(cat "$K/password.txt")" \
    -e SIGN_KEYSTORE_ALIAS=test -e VERIFY_CAFILE=/keys/verify.pem "$IMG" win > "$OUT/sign-$c.log" 2>&1
  echo "sign $c exit $? $(tail -1 "$OUT/sign-$c.log")"
  pack "$L/$c" "$L/zips-$c"
done
for c in A1 A2; do
  ( cd "$L" && while read -r f; do cmp -s "A/$f" "$c/$f" && echo "same $f" || echo "differ $f"; done < "$OUT/pe-files.txt" ) > "$OUT/A-vs-$c.txt"
done
( cd "$L" && while read -r f; do cmp -s "A1/$f" "A2/$f" && echo "same $f" || echo "differ $f"; done < "$OUT/pe-files.txt" ) > "$OUT/A1-vs-A2.txt"
for t in A-vs-A1 A-vs-A2 A1-vs-A2; do echo "$t: $(grep -c '^same' "$OUT/$t.txt") same, $(grep -c '^differ' "$OUT/$t.txt") differ"; done
grep '^differ' "$OUT/A-vs-A1.txt" | sed 's/^differ //' | cmp -s - "$OUT/to-sign.txt" && echo "the files A1 changed are exactly the unsigned ones"
( cd "$L/A" && find win -type f ! \( -iname '*.exe' -o -iname '*.dll' \) | LC_ALL=C sort | while read -r f; do cmp -s "$f" "../A1/$f" || echo "$f"; done ) > "$OUT/non-pe-changed.txt"
echo "non-PE files changed by signing: $(wc -l < "$OUT/non-pe-changed.txt")"
for z in $ZIPS; do same "$L/zips-A1/$z-$TAG.zip" "$L/zips-A2/$z-$TAG.zip" "1 $z zip, A1 against A2"; done

echo "== 2 $(date +%T)"
inside "set -u; while read -r f; do mkdir -p S/\$(dirname \"\$f\"); osslsigncode remove-signature -in A1/\$f -out S/\$f > /dev/null 2>&1 || echo \"FAILED \$f\"; done < $L/to-sign.txt"
( cd "$L" && while read -r f; do
    if cmp -s "A/$f" "S/$f"; then echo "same $f"
    else echo "differ $f $(stat -c %s "A/$f") $(stat -c %s "S/$f") $(cmp -l "A/$f" "S/$f" 2> /dev/null | wc -l) $(cmp -l "A/$f" "S/$f" 2> /dev/null | head -4 | awk '{printf "%d ", $1 - 1}')"; fi
  done < "$OUT/to-sign.txt" ) > "$OUT/strip.txt"
echo "stripped: $(grep -c '^same' "$OUT/strip.txt") same as A, $(grep -c '^differ' "$OUT/strip.txt") differ"
python3 - "$L" "$OUT/strip.txt" > "$OUT/strip-offsets.txt" <<'PY'
import struct, sys
root, listing = sys.argv[1:3]
kinds = {}
for line in open(listing):
    parts = line.split()
    if parts[0] != "differ":
        continue
    f = parts[1]
    data = open(f"{root}/A/{f}", "rb").read()
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    opt = pe + 24
    magic = struct.unpack_from("<H", data, opt)[0]
    checksum = opt + 64
    certdir = opt + (112 if magic == 0x20B else 96) + 4 * 8
    names = []
    for o in map(int, parts[5:]):
        if checksum <= o < checksum + 4: names.append("checksum")
        elif certdir <= o < certdir + 8: names.append("certificate-table entry")
        else: names.append(f"offset {o}")
    kind = ", ".join(sorted(set(names))) + (f"; size {parts[2]} -> {parts[3]}" if parts[2] != parts[3] else "")
    kinds.setdefault(kind, []).append(f)
for kind, files in sorted(kinds.items(), key=lambda kv: -len(kv[1])):
    print(f"{len(files)} files: {kind}; e.g. {files[0]}")
PY
cat "$OUT/strip-offsets.txt"

echo "== 3 $(date +%T)"
cp -a "$L/B" "$L/P"
inside "set -u; while read -r f; do mkdir -p sig/\$(dirname \"\$f\"); osslsigncode extract-signature -in A1/\$f -out sig/\$f.p7 > /dev/null 2>&1 || echo \"EXTRACT FAILED \$f\"; osslsigncode attach-signature -sigin sig/\$f.p7 -in B/\$f -out P/\$f.tmp > /dev/null 2>&1 && mv P/\$f.tmp P/\$f || echo \"ATTACH FAILED \$f\"; done < $L/to-sign.txt" > "$OUT/paste.log" 2>&1
echo "paste failures: $(grep -c FAILED "$OUT/paste.log")"
( cd "$L" && while read -r f; do cmp -s "A1/$f" "P/$f" && echo "same $f" || echo "differ $f"; done < "$OUT/pe-files.txt" ) > "$OUT/paste.txt"
echo "pasted against A1: $(grep -c '^same' "$OUT/paste.txt") same, $(grep -c '^differ' "$OUT/paste.txt") differ"
inside "while read -r f; do if osslsigncode verify $CA -in P/\$f > /tmp/v.log 2>&1 && grep -q 'Timestamp Server Signature verification: ok' /tmp/v.log; then echo \"ok \$f\"; else echo \"FAILED \$f\"; fi; done < $L/to-sign.txt" > "$OUT/paste-verify.txt"
echo "pasted signatures verified: $(grep -c '^ok' "$OUT/paste-verify.txt") ok, $(grep -c '^FAILED' "$OUT/paste-verify.txt") failed"
pack "$L/P" "$L/zips-P"
for z in $ZIPS; do same "$L/zips-A1/$z-$TAG.zip" "$L/zips-P/$z-$TAG.zip" "3 $z zip, pasted against A1"; done

echo "== 4 $(date +%T)"
f=win/ws-pems-win-x64/ApplicationCore.dll
mkdir -p "$L/N" && cp "$L/B/$f" "$L/N/ApplicationCore.dll"
python3 - "$L/N/ApplicationCore.dll" <<'PY'
import sys
p = sys.argv[1]
d = bytearray(open(p, "rb").read())
i = len(d) // 2
d[i] ^= 0x01
open(p, "wb").write(d)
print(f"flipped bit 0 of byte {i} of {len(d)}")
PY
inside "osslsigncode attach-signature -sigin sig/$f.p7 -in N/ApplicationCore.dll -out N/signed.dll; echo \"attach exit \$?\"; osslsigncode verify $CA -in N/signed.dll > N/verify.log 2>&1; echo \"verify exit \$?\"; grep -E 'Calculated|Current|Signature verification' N/verify.log" 2>&1
echo "== end $(date +%T)"
