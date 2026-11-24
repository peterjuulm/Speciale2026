# The linux job of the v0.0.0-thesis.6 rebuild again, alone, on 24 November:
# its first run (08:52-09:10) failed in restore, NU1301, nuget.org's service
# index timing out after 100 s for 17 minutes. The NuGet folder the windows,
# migrator and sql jobs filled after it is set aside, so this job too starts
# from an empty one. Then compare.sh and the GHCR check again, in full.
set -uo pipefail
N=/private/tmp/rb1-rebuild6 T=v0.0.0-thesis.6
R=/private/tmp/rb1-dre E=$R/1-ws-pems/scripts/5-release/local-vs-github-comparison
export DOCKER_CONFIG=/private/tmp/rb1-docker
echo "-- the network: nuget.org's service index"
for i in 1 2 3; do curl -sS -o /dev/null -w "  %{http_code} %{remote_ip} %{time_total}s\n" --max-time 30 https://api.nuget.org/v3/index.json; done
echo "-- the NuGet folder of the other jobs set aside, an empty one made"
du -sh /private/tmp/rb1-dch
mv /private/tmp/rb1-dch /private/tmp/rb1-dch-rebuild6-other-jobs
mkdir /private/tmp/rb1-dch && ln -sfn /private/tmp/rb1-dch /tmp/dch && echo "/tmp/dch -> $(readlink /tmp/dch): $(find /tmp/dch/ -mindepth 1 | wc -l) entries"
mv "$N/local/linux.log" "$N/local/linux-first-run-NU1301.log"
echo; echo "== linux job $(date +%H:%M:%S)"
OUT=$N DOTNET_DIR=$HOME/rb1-dotnet-10.0.401 NODE_DIR=/private/tmp/rb1-rebuild6-node REPO=/private/tmp/rb1-merge-src \
  /tmp/claude-1000/ws-mem-run.sh 14 bash "$E/rebuild.sh" $T linux 2>&1 | tee "$N/rebuild-linux.log"
echo "linux exit ${PIPESTATUS[0]}  $(date +%H:%M:%S)"
grep -c NU1301 "$N/local/linux.log" | sed 's/^/NU1301 lines: /'
echo; echo "== compare with the published release $(date +%H:%M:%S)"
(cd /private/tmp && SIGNED=azure CLONE=/private/tmp/rb1-ci/windows SIGNING_IMAGE=ws-signing:rb-ref6 bash "$E/compare.sh" "$N" $T) 2>&1 | tee "$N/compare.txt"
echo "compare exit ${PIPESTATUS[0]}"
echo; echo "== the images, again against GHCR $(date +%H:%M:%S)"
for n in ws-pems ws-pems-job-worker wspems-mcp-server wspems-chat-server wspems-mcp-auth-broker; do
  GH_TOKEN=$(gh auth token) timeout 120 python3 "$E/ghcr-manifests.py" weel-sandvig/$n $T "$N/local/images/$n.oci.tar"
done 2>&1 | tee "$N/images-ghcr.txt"
echo "== done $(date +%H:%M:%S)"
