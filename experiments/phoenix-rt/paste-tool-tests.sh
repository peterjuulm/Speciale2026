#!/usr/bin/env bash
# paste-signatures.sh after the rewrite (14 Oct, after the dry run's disk
# failure): with and without an output directory, and seven ways a rebuild
# can differ. Fixtures are hard-linked copies of B; a changed file is a
# fresh copy first, so B itself is never touched. Run again at 08:56 with
# two more cases, a read-only folder without and with an output directory,
# after the output copy's folders were made writable (LOG=... to keep the
# first run's log).
set -uo pipefail
W=/home/leos/Dev/Weel-Sandvig/WS.Phoenix-repro
L=/private/tmp/rb1-sign
O=/home/leos/Dev/speciale-2026/data/phoenix-signing/arch-2026-10-14
K=$O/keys
LOG=${LOG:-$O/paste-tool-tests-2.txt}
IMAGE=${IMAGE:-ws-signing:rb-test3}
: > "$LOG"
say() { echo "$*" | tee -a "$LOG"; }

say "$(date +%T) image from $W/deployment/signing at $(git -C "$W" rev-parse --short HEAD) + worktree changes"
say "paste-signatures.sh sha256 $(sha256sum "$W/deployment/signing/paste-signatures.sh" | cut -c1-16)"
DOCKER_CONFIG=/private/tmp/rb1-docker docker buildx build --builder default --load -q -t "$IMAGE" "$W/deployment/signing" > /dev/null || { say "image build failed"; exit 1; }

run() {
  docker run --rm --user "$(id -u):$(id -g)" -v "$L:$L" -v "$K:/keys:ro" -w "$L" \
    -e VERIFY_CAFILE=/keys/verify.pem --entrypoint /opt/signing/paste-signatures.sh "$IMAGE" "$@"
}
case_() {
  local name=$1 expect=$2; shift 2
  say "== $name (expect exit $expect)"
  local start=$SECONDS
  run "$@" > "$L/case.out" 2>&1
  local rc=$?
  grep -v '^Number of verified signatures\|^Failed$\|^Succeeded$' "$L/case.out" | tail -n 8 | tee -a "$LOG" > /dev/null
  say "exit $rc in $((SECONDS - start)) s: $([ "$rc" = "$expect" ] && echo AS EXPECTED || echo UNEXPECTED)"
}
fixture() {  # a hard-linked copy of B, for one test
  rm -rf "$L/$1" && cp -al "$L/B" "$L/$1"
}
fresh() {  # a file of the fixture as a fresh copy, so B is not changed
  cp --remove-destination "$L/B/$2" "$L/$1/$2"
}

case_ "positive, no output directory" 0 A1/win B/win
rm -rf "$L/T3" && mkdir "$L/T3"
case_ "positive, output directory" 0 A1/win B/win T3/win
mkdir -p "$L/zips-T3"
( cd "$L/T3/win" && for z in ws-pems-win-x64 ws-pems-job-worker-win-x64; do
    env PATH=/private/tmp/rb1-tools:/usr/bin SOURCE_DATE_EPOCH=1791919869 /private/tmp/rb1-phoenix/scripts/pack-release-zip.sh "$z" "$L/zips-T3/$z-v0.0.0-thesis.zip" || exit 1
  done )
for z in ws-pems-win-x64 ws-pems-job-worker-win-x64; do
  cmp -s "$L/zips-A1/$z-v0.0.0-thesis.zip" "$L/zips-T3/$z-v0.0.0-thesis.zip" && say "same  $z zip, the output packed, against A1" || say "DIFF  $z zip"
done
cmp -s "$L/A1/win/ws-pems-db-migrator-win-x64-v0.0.0-thesis.exe" "$L/T3/win/ws-pems-db-migrator-win-x64-v0.0.0-thesis.exe" && say "same  the migrator" || say "DIFF  the migrator"
case_ "self-check: A1's signatures onto A, the build A1 was signed from" 0 A1/win A/win

case_ "one byte changed in a signed DLL (Tbad-src, from 06:45)" 1 A1/win Tbad-src/win
case_ "an extra file (Textra-src, from 06:46)" 1 A1/win Textra-src/win

fixture Tfolder && mkdir "$L/Tfolder/win/ws-pems-win-x64/empty"
case_ "an extra empty folder" 1 A1/win Tfolder/win

plain=win/ws-pems-win-x64/appsettings.json
fixture Tmode && fresh Tmode "$plain" && chmod 755 "$L/Tmode/$plain"
case_ "mode 755 on a file that is not pasted ($plain)" 1 A1/win Tmode/win

pe=win/ws-pems-job-worker-win-x64/ApplicationCore.dll
fixture Tmodepe && fresh Tmodepe "$pe" && chmod 755 "$L/Tmodepe/$pe"
case_ "mode 755 on a file that is pasted ($pe)" 1 A1/win Tmodepe/win

fixture Tjson && fresh Tjson "$plain" && python3 -c "p='$L/Tjson/$plain'; d=bytearray(open(p,'rb').read()); d[len(d)//2]^=1; open(p,'wb').write(d)"
case_ "one byte changed in a file that is not signed ($plain)" 1 A1/win Tjson/win

fixture Tmissing && rm "$L/Tmissing/$plain"
case_ "a file missing ($plain)" 1 A1/win Tmissing/win

sub=$(cd "$L/B" && find win/ws-pems-win-x64 -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort | head -n 1)
fixture Tunread && chmod 000 "$L/Tunread/$sub"
case_ "a folder that cannot be read ($sub)" 1 A1/win Tunread/win
chmod 755 "$L/Tunread/$sub"

fixture Tnl && touch "$L/Tnl/win/ws-pems-win-x64/a"$'\n'"b"
case_ "a name with a newline" 1 A1/win Tnl/win

ro=win/ws-pems-job-worker-win-x64
fixture Tro && chmod 555 "$L/Tro/$ro"
case_ "a read-only folder that holds pasted files ($ro), no output directory" 0 A1/win Tro/win
rm -rf "$L/T4" && mkdir "$L/T4"
case_ "the same, output directory" 0 A1/win Tro/win T4/win
chmod 755 "$L/Tro/$ro"

rm -f "$L/case.out"
say "$(date +%T) done"
