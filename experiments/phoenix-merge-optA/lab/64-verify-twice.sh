# Stages 0-2 on arch, 24 November: scripts/release/rebuild.sh, the new
# one-command verifier, run twice against the outputs of dry run 5 (GitHub
# run RUN, commit 8491a0d63, v0.0.0-dryrun.5), each in a work folder of its
# own. Each must end with the rebuilt build-manifest.json equal to the run's.
# Then the two rebuilds' release folders and images against each other: the
# whole release built twice. The run's files are laid out flat, as a GitHub
# Release holds them. SIGNING_CA is the run's throwaway CA, and
# ALLOW_UNTAGGED=1 since the dry run had no tag. Each rebuild runs under the
# memory guard (its .NET builds; its images in BuildKit).
set -uo pipefail
RUN=${RUN:-45403522195} T=v0.0.0-dryrun.5 V=/private/tmp/rb1-verify
export DOCKER_CONFIG=/private/tmp/rb1-docker
# Arch has no zip in /usr/bin: the experiments' zip (sha256 2958697a…) is in rb1-tools.
export PATH=/private/tmp/rb1-tools:$PATH
rm -rf "$V"; mkdir -p "$V"
git -C /private/tmp/rb1-merge-src fetch -q /private/tmp/rb1-lab/rb1-stages.bundle refs/heads/thesis-stages-local:refs/heads/thesis-stages
git clone -q --no-checkout /private/tmp/rb1-merge-src "$V/src"
# The verifier from the branch's tip (rebuild.sh's fix after dry run 4);
# what it builds is the manifest's commit, the run's.
git -C "$V/src" checkout -q --detach origin/thesis-stages && echo "verifier source: $(git -C "$V/src" log -1 --format='%H %s')"
echo "the run's commit: $(gh run view "$RUN" -R Weel-Sandvig/WS.Phoenix --json headSha --jq .headSha)"
echo "== the run's files $(date +%H:%M:%S)"
rm -rf "$V/run" "$V/assets"
for a in dry-run-release thesis-test-ca; do gh run download "$RUN" -R Weel-Sandvig/WS.Phoenix -n "$a" -D "$V/run/$a" > /dev/null 2>&1 || echo "FAILED $a"; done
mkdir -p "$V/assets"; find "$V/run/dry-run-release/release" -type f -exec cp {} "$V/assets/" \;
ls "$V/assets"; echo "$(ls "$V/assets" | wc -l) files"
echo "== the run's provenance files: GitHub context, e-mail addresses, names?"
for f in "$V/assets/"*.provenance.json; do
  python3 -I - "$f" <<'PY2'
import json, re, sys
t = open(sys.argv[1]).read(); d = json.loads(t)
keys = sorted(set(re.findall(r'"(github_[A-Za-z_]+)"', t)))
mails = sorted(set(re.findall(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}", t)))
names = sorted(set(re.findall(r'"(?:actor|triggering_actor|name|login|author|committer|pusher|sender)"\s*:\s*"([^"]*)"', t)))
print(f"{sys.argv[1].rsplit('/', 1)[1]}: {len(t)} bytes; top {sorted(d)}; github_ keys {keys}; e-mail {mails}; name fields {names[:8]}")
PY2
done
for w in 1 2; do
  echo; echo "== rebuild $w $(date +%H:%M:%S)"
  ASSETS=$V/assets SIGNING_CA=$V/run/thesis-test-ca/ca.pem ALLOW_UNTAGGED=1 \
    /tmp/claude-1000/ws-mem-run.sh 14 bash "$V/src/scripts/release/rebuild.sh" $T "$V/work$w" > "$V/rebuild$w.log" 2>&1
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
echo "== the SBOMs: the run's against rebuild 1 and 2"
for f in "$V/assets/"*.spdx.json; do n=$(basename "$f")
  for w in 1 2; do cmp -s "$f" "$V/work$w/images/$n" && r=same || r=DIFFERENT; printf '%s rebuild %s: %s\n' "$n" $w $r; done
done
echo "== done $(date +%H:%M:%S)"
