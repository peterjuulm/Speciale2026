# v0.0.0-thesis.7 on arch, 24 November evening: the published release (tag
# on 96e2990a6, release run 45442984125) rebuilt twice with the verifier the
# tag itself carries, scripts/release/rebuild.sh, each in a work folder of
# its own and in a fresh clone (never Leo's ~/Dev/Weel-Sandvig/WS.Phoenix).
# Each must end with SAME: the build-manifest.json it writes from the rebuilt
# files is the published one, byte for byte. Then the two rebuilds against
# each other, as in 64. The assets come from the GitHub Release itself; no
# SIGNING_CA or ALLOW_UNTAGGED, since the tag is real. The dry-run 5
# verification folders (64g, 65b) are removed first for the disk; their logs
# are in Speciale2026/data/2026-11-24-phoenix-build-manifest/arch.
set -uo pipefail
T=v0.0.0-thesis.7 V=/private/tmp/rb1-t7
export DOCKER_CONFIG=/private/tmp/rb1-docker
# Arch has no zip in /usr/bin: the experiments' zip (sha256 2958697a…) is in rb1-tools.
export PATH=/private/tmp/rb1-tools:$PATH
rm -rf /private/tmp/rb1-verify/work1 /private/tmp/rb1-verify/work2 /private/tmp/rb1-verify/tagtest /private/tmp/rb1-verify/pushed
rm -rf "$V"; mkdir -p "$V"
git clone -q --no-checkout /private/tmp/rb1-merge-src "$V/src"
git -C "$V/src" fetch -q https://github.com/Weel-Sandvig/WS.Phoenix "refs/tags/$T:refs/tags/$T"
git -C "$V/src" checkout -q --detach "$T" && echo "verifier source: $(git -C "$V/src" log -1 --format='%H %s')"
echo "the tag: $(git -C "$V/src" rev-parse "$T^{commit}")"
df -h /private/tmp | tail -1
echo "== the release's files $(date +%H:%M:%S)"
gh release download "$T" -R Weel-Sandvig/WS.Phoenix -D "$V/assets" > /dev/null 2>&1 || echo "FAILED release download"
ls "$V/assets"; echo "$(ls "$V/assets" | wc -l) files"
(cd "$V/assets" && sha256sum -c SHA256SUMS)
for w in 1 2; do
  echo; echo "== rebuild $w $(date +%H:%M:%S)"
  ASSETS=$V/assets /tmp/claude-1000/ws-mem-run.sh 14 bash "$V/src/scripts/release/rebuild.sh" $T "$V/work$w" > "$V/rebuild$w.log" 2>&1
  echo "rebuild $w exit $?  $(date +%H:%M:%S)"
  grep -E "^== |SAME|DIFFERENT|^  pkg|^  [a-z].*published" "$V/rebuild$w.log" | tail -14
done
echo; echo "== rebuild 1 against rebuild 2"
for w in 1 2; do (cd "$V/work$w/release" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) > "$V/release$w.sha256"; done
cmp -s "$V/release1.sha256" "$V/release2.sha256" && echo "release files: identical ($(wc -l < "$V/release1.sha256"))" || diff "$V/release1.sha256" "$V/release2.sha256"
for n in ws-pems ws-pems-job-worker wspems-mcp-server wspems-chat-server wspems-mcp-auth-broker; do
  printf '%s: ' $n; python3 -I /private/tmp/rb1-dre/1-ws-pems/scripts/6-images/oci-diff.py "$V/work1/images/$n.oci.tar" "$V/work2/images/$n.oci.tar" 2>&1 | head -1
done
cmp "$V/work1/build-manifest.json" "$V/work2/build-manifest.json" && echo "the two rebuilt manifests: identical"
echo "== the published SBOMs against rebuild 1 and 2"
for f in "$V/assets/"*.spdx.json; do n=$(basename "$f")
  for w in 1 2; do cmp -s "$f" "$V/work$w/images/$n" && r=same || r=DIFFERENT; printf '%s rebuild %s: %s\n' "$n" $w $r; done
done
echo "== done $(date +%H:%M:%S)"
