# v0.0.0-thesis.8 on arch, 25 November: the published release (tag on
# 1c90ad428, release run 45585787137) rebuilt once (Leo's choice, as for
# thesis.7 in 71) with the verifier the tag itself carries,
# scripts/release/rebuild.sh, in a fresh clone (never Leo's
# ~/Dev/Weel-Sandvig/WS.Phoenix). Must end with SAME: the build-manifest.json
# it writes from the rebuilt files is the published one, byte for byte, now
# with 15 subjects (the SBOM zip one of them). On x86_64 the tag's new
# platform code does not run. The assets come from the GitHub Release itself.
set -uo pipefail
T=v0.0.0-thesis.8 V=/private/tmp/rb1-t8
export DOCKER_CONFIG=/private/tmp/rb1-docker
# Arch has no zip in /usr/bin: the experiments' zip (sha256 2958697a…) is in rb1-tools.
export PATH=/private/tmp/rb1-tools:$PATH
rm -rf "$V"; mkdir -p "$V"
git clone -q --no-checkout /private/tmp/rb1-merge-src "$V/src"
git -C "$V/src" fetch -q https://github.com/Weel-Sandvig/WS.Phoenix "refs/tags/$T:refs/tags/$T"
git -C "$V/src" checkout -q --detach "$T" && echo "verifier source: $(git -C "$V/src" log -1 --format='%H %s')"
echo "the tag: $(git -C "$V/src" rev-parse "$T^{commit}")"
df -h /private/tmp | tail -1; powerprofilesctl get; cat /sys/class/power_supply/AC*/online
echo "== the release's files $(date +%H:%M:%S)"
gh release download "$T" -R Weel-Sandvig/WS.Phoenix -D "$V/assets" > /dev/null 2>&1 || echo "FAILED release download"
ls "$V/assets"; echo "$(ls "$V/assets" | wc -l) files"
(cd "$V/assets" && sha256sum -c SHA256SUMS)
echo; echo "== rebuild $(date +%H:%M:%S)"
ASSETS=$V/assets /tmp/claude-1000/ws-mem-run.sh 14 bash "$V/src/scripts/release/rebuild.sh" $T "$V/work" > "$V/rebuild.log" 2>&1
echo "rebuild exit $?  $(date +%H:%M:%S)"
grep -E "^== |SAME|DIFFERENT|^  pkg|^  [a-z].*published|Docker runs on" "$V/rebuild.log" | tail -16
(cd "$V/work/release" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) > "$V/release.sha256"
echo "== done $(date +%H:%M:%S)"
