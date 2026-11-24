# v0.0.0-thesis.6 (be5fc56e) rebuilt on arch on 24 November, about six weeks
# after GitHub published it (14 October), from an empty NuGet folder and an
# npm cache filled that morning, with rebuild.sh, compare.sh and
# ghcr-manifests.py of dotnet-rebuild-experiments at d991fc5. The rebuild runs
# as one job under arch's memory guard (cap 14 GB; csc for the tag's
# Infrastructure peaks near 11 GB); its images run in BuildKit, under the guard's lock.
set -uo pipefail
N=/private/tmp/rb1-rebuild6 T=v0.0.0-thesis.6
R=/private/tmp/rb1-dre E=$R/1-ws-pems/scripts/5-release/local-vs-github-comparison
rm -rf "$R"; git clone -q https://github.com/leosakharoff/dotnet-rebuild-experiments.git "$R" && git -C "$R" checkout -q d991fc501e4e1bd241eeee801dd5b8903d37b2fd
git -C "$R" log -1 --format='scripts: dotnet-rebuild-experiments %H'; sha256sum "$E/rebuild.sh" "$E/compare.sh" "$E/ghcr-manifests.py"
export DOCKER_CONFIG=/private/tmp/rb1-docker
{
  echo "arch $(uname -n) $(uname -r), $(ldd --version | sed -n 1p)"; date -Is
  echo "sdk $($HOME/rb1-dotnet-10.0.401/dotnet --version), $($HOME/rb1-dotnet-10.0.401/dotnet --list-runtimes | grep NETCore.App)"
  echo "node $(/private/tmp/rb1-rebuild6-node/bin/node --version), npm $(PATH=/private/tmp/rb1-rebuild6-node/bin:/usr/bin:/bin npm --version)"
  echo "zip $(sha256sum /private/tmp/rb1-tools/zip | cut -d' ' -f1)"
  docker version --format 'docker {{.Server.Version}}'; docker buildx inspect rb1 | grep -E 'BuildKit version'
  docker inspect buildx_buildkit_rb10 --format 'buildkit image {{.Config.Image}} {{.Image}}'
  docker image inspect ws-signing:rb-ref6 --format 'signing image {{.Id}}'
  echo "NuGet folder /tmp/dch -> $(readlink /tmp/dch): $(find /tmp/dch/ -mindepth 1 | wc -l) entries"
  echo "npm cache /private/tmp/rb1-npm: $(du -sh /private/tmp/rb1-npm | cut -f1), filled this morning"
  echo "repo $(git -C /private/tmp/rb1-merge-src rev-parse $T^{commit}) ($T)"
  echo "guard $(sha256sum /tmp/claude-1000/ws-mem-run.sh | cut -d" " -f1), restored after the reboot"
  grep MemAvailable /proc/meminfo
} | tee "$N/environment.txt"

echo; echo "== rebuild $(date +%H:%M:%S)"
OUT=$N DOTNET_DIR=$HOME/rb1-dotnet-10.0.401 NODE_DIR=/private/tmp/rb1-rebuild6-node REPO=/private/tmp/rb1-merge-src \
  /tmp/claude-1000/ws-mem-run.sh 14 bash "$E/rebuild.sh" $T 2>&1 | tee "$N/rebuild.log"
echo "rebuild exit ${PIPESTATUS[0]}  $(date +%H:%M:%S)"

echo; echo "== compare with the published release $(date +%H:%M:%S)"
(cd /private/tmp && SIGNED=azure CLONE=/private/tmp/rb1-ci/windows SIGNING_IMAGE=ws-signing:rb-ref6 bash "$E/compare.sh" "$N" $T) 2>&1 | tee "$N/compare.txt"
echo "compare exit ${PIPESTATUS[0]}"

echo; echo "== upgrade.sh and the export against the published files"
cmp "$N/assets/upgrade.sh" /private/tmp/rb1-ci/windows/scripts/upgrade.sh && echo "same  upgrade.sh"
rm -rf "$N/pub-linux"; mkdir -p "$N/pub-linux"; unzip -q "$N/ci/release-zips-linux/ws-pems-linux-x64-$T.zip" -d "$N/pub-linux"
w=$(find "$N/pub-linux" -maxdepth 2 -type d -name wwwroot | head -1)
python3 - "$N/local/frontend-out" "$w" <<'PY'
import hashlib, os, sys
def tree(root):
    out = {}
    for d, _, fs in os.walk(root):
        for f in fs:
            p = os.path.join(d, f)
            out[os.path.relpath(p, root)] = hashlib.sha256(open(p, 'rb').read()).hexdigest()
    return out
local, pub = tree(sys.argv[1]), tree(sys.argv[2])
same = sum(1 for k, v in local.items() if pub.get(k) == v)
print(f"export: {len(local)} files rebuilt; {same} with the same path and SHA-256 in the published Linux zip's wwwroot; {len(local)-same} not; the zip's wwwroot has {len(pub)-len(local)} more (not from the export)")
PY

echo; echo "== images against GHCR (linux/amd64 manifest) $(date +%H:%M:%S)"
for n in ws-pems ws-pems-job-worker wspems-mcp-server wspems-chat-server wspems-mcp-auth-broker; do
  GH_TOKEN=$(gh auth token) timeout 120 python3 "$E/ghcr-manifests.py" weel-sandvig/$n $T "$N/local/images/$n.oci.tar"
done 2>&1 | tee "$N/images-ghcr.txt"
echo; echo "== done $(date +%H:%M:%S)"
