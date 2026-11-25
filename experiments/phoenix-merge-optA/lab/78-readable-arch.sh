# arch, 25 November: the readable rebuild.sh (WS.Phoenix 378f113d9, one
# function per step, its Python inline in named functions; not pushed when
# this ran) against
# a published release, to show it behaves as before. REL is the release
# (v0.0.0-thesis.7 or v0.0.0-thesis.8). The verifier is a fresh clone at the
# thesis.8 tag (1c90ad428, whose history holds both releases' commits) with
# 378f113d9's rebuild.sh copied over its working tree; the jobs clone the
# manifest's commit from it, so the copied file does not reach them. Must end
# with SAME, as the tag's own rebuild.sh did (71, 77).
set -uo pipefail
REL=${REL:?v0.0.0-thesis.7 or v0.0.0-thesis.8} V=/private/tmp/rb1-rd
export DOCKER_CONFIG=/private/tmp/rb1-docker
export PATH=/private/tmp/rb1-tools:$PATH
rm -rf "$V/src" "$V/work"; mkdir -p "$V"
git clone -q --no-checkout /private/tmp/rb1-merge-src "$V/src"
for t in v0.0.0-thesis.7 v0.0.0-thesis.8; do git -C "$V/src" fetch -q https://github.com/Weel-Sandvig/WS.Phoenix "refs/tags/$t:refs/tags/$t"; done
git -C "$V/src" checkout -q --detach v0.0.0-thesis.8
cp /private/tmp/rb1-lab/readable/rebuild.sh "$V/src/scripts/release/"
echo "verifier: v0.0.0-thesis.8 plus"; sha256sum "$V/src/scripts/release/rebuild.sh"
git -C "$V/src" status --short
if [ ! -f "$V/assets-$REL/build-manifest.json" ]; then
  gh release download "$REL" -R Weel-Sandvig/WS.Phoenix -D "$V/assets-$REL" > /dev/null 2>&1 || echo "FAILED release download"
fi
(cd "$V/assets-$REL" && sha256sum -c --quiet SHA256SUMS && echo "SHA256SUMS OK")
echo; echo "== rebuild $REL $(date +%H:%M:%S)"
ASSETS=$V/assets-$REL /tmp/claude-1000/ws-mem-run.sh 14 bash "$V/src/scripts/release/rebuild.sh" "$REL" "$V/work" > "$V/rebuild-$REL.log" 2>&1
echo "rebuild exit $?  $(date +%H:%M:%S)"
grep -E "^== |SAME|DIFFERENT|^  pkg|^  [a-z].*published|Docker runs on|^SDK " "$V/rebuild-$REL.log" | tail -16
echo "== done $(date +%H:%M:%S)"
