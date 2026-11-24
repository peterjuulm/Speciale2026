# The release dry run of 24 November (WS branch 30a2d3264, the version fixed
# to v0.0.0-dryrun.1; GitHub run 45369603779) rebuilt on arch, alongside the
# run: the same commit, every job of rebuild.sh as adapted for the merge in
# D5 (rebuild-merge.sh: the SQL job's -p/-s src/Infrastructure.Migrations,
# NPM_CACHE). The lab tag v0.0.0-dryrun.1 exists only in the lab clone; the
# run itself had no tag. The signing image for the paste is built from the
# commit's deployment/signing. Caches as D5 left them (NuGet in /tmp/dch,
# the merge's npm cache): this rebuild tests equal outputs, not empty caches.
set -uo pipefail
src=/private/tmp/rb1-merge-src T=v0.0.0-dryrun.1 N=/private/tmp/rb1-dry1 X=/private/tmp/rb1-merge-twice
export DOCKER_CONFIG=/private/tmp/rb1-docker
git -C "$src" fetch -q /private/tmp/rb1-lab/rb1-dry.bundle refs/heads/thesis/reproducible-builds:refs/heads/thesis-dry
git -C "$src" tag -f $T thesis-dry > /dev/null
echo "$T -> $(git -C "$src" rev-parse $T^{commit}) ($(git -C "$src" log -1 --format=%s $T))"
rm -rf "$N"; mkdir -p "$N"
{ echo "arch $(uname -n) $(uname -r), $(ldd --version | sed -n 1p)"; date -Is
  echo "sdk $($HOME/rb1-dotnet-10.0.401/dotnet --version); node $(/private/tmp/rb1-npmpin-node/bin/node --version), npm $(PATH=/private/tmp/rb1-npmpin-node/bin:/usr/bin:/bin npm --version)"
  echo "rebuild-merge.sh $(sha256sum $X/rebuild-merge.sh | cut -d' ' -f1)"
  echo "NuGet folder /tmp/dch: $(find /tmp/dch/ -mindepth 1 | wc -l) entries; npm cache /private/tmp/rb1-npm-merge $(du -sh /private/tmp/rb1-npm-merge | cut -f1)"
  docker buildx inspect rb1 | grep -E 'BuildKit version'; grep MemAvailable /proc/meminfo; } | tee "$N/environment.txt"
echo; echo "== the signing image from the commit $(date +%H:%M:%S)"
s=/private/tmp/rb1-dry-signing; rm -rf "$s"; mkdir -p "$s"; git -C "$src" archive $T deployment/signing | tar -x -C "$s"
flock /tmp/claude-1000/phoenix-dotnet.lock docker buildx build --builder rb1 --load -q -t ws-signing:rb-dry1 "$s/deployment/signing" 2>&1 | tail -2
docker image inspect ws-signing:rb-dry1 --format 'signing image {{.Id}}'
echo; echo "== rebuild $(date +%H:%M:%S)"
OUT=$N DOTNET_DIR=$HOME/rb1-dotnet-10.0.401 NODE_DIR=/private/tmp/rb1-npmpin-node NPM_CACHE=/private/tmp/rb1-npm-merge REPO=$src \
  /tmp/claude-1000/ws-mem-run.sh 14 bash "$X/rebuild-merge.sh" $T 2>&1 | tee "$N/rebuild.log"
echo "rebuild exit ${PIPESTATUS[0]}  $(date +%H:%M:%S)"
