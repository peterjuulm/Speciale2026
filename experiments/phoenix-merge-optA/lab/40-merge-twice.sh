# D5: the whole release of the merge (thesis-merge, 30b5c745d) twice on arch,
# with a copy of rebuild.sh (d991fc5) changed in two places for the merge:
# the SQL job uses main's migrations project as the release's step now does
# (-p/-s src/Infrastructure.Migrations), and the npm cache is NPM_CACHE, so
# the merge's packages stay out of the cache of the v0.0.0-thesis.6
# rebuild. The tag v0.0.0-merge-optA.1 exists only in the lab clone. Node
# 22.23.3 with npm 11.21.2, the pin. Each run under the guard (cap 12 GB;
# Infrastructure.Migrations near 8.4 GB). Then run 1 against run 2.
set -uo pipefail
R=/private/tmp/rb1-dre E=$R/1-ws-pems/scripts/5-release/local-vs-github-comparison
src=/private/tmp/rb1-merge-src T=v0.0.0-merge-optA.1 X=/private/tmp/rb1-merge-twice
export DOCKER_CONFIG=/private/tmp/rb1-docker
git -C "$src" tag -f -a $T thesis-merge -m "lab only: the merge, for D5" > /dev/null && git -C "$src" rev-parse $T^{commit}
mkdir -p "$X"; cp "$E/rebuild.sh" "$X/rebuild-merge.sh"
sed -i -e 's#-p src/Infrastructure/Infrastructure.csproj -s src/WebAPI/WebAPI.csproj#-p src/Infrastructure.Migrations/Infrastructure.Migrations.csproj -s src/Infrastructure.Migrations/Infrastructure.Migrations.csproj#' \
       -e 's#npm_config_cache=/private/tmp/rb1-npm #npm_config_cache=${NPM_CACHE:-/private/tmp/rb1-npm} #' "$X/rebuild-merge.sh"
diff "$E/rebuild.sh" "$X/rebuild-merge.sh"
echo "-- the merge's npm cache, filled online by npm 11.21.2 from its lock"
f=/private/tmp/rb1-merge-fill; rm -rf "$f" /private/tmp/rb1-npm-merge; mkdir -p "$f"
git -C "$src" archive thesis-merge src/WebAPI/ClientApp | tar -x -C "$f"
(cd "$f/src/WebAPI/ClientApp" && env -i HOME=/tmp/dch PATH=/private/tmp/rb1-npmpin-node/bin:/usr/bin:/bin npm_config_cache=/private/tmp/rb1-npm-merge npm_config_update_notifier=false npm ci --ignore-scripts --no-audit --no-fund 2>&1 | tail -1)
for run in 1 2; do
  echo; echo "== run $run $(date +%H:%M:%S)"
  rm -rf "$X/run$run"; mkdir -p "$X/run$run"
  OUT=$X/run$run DOTNET_DIR=$HOME/rb1-dotnet-10.0.401 NODE_DIR=/private/tmp/rb1-npmpin-node NPM_CACHE=/private/tmp/rb1-npm-merge REPO=$src \
    /tmp/claude-1000/ws-mem-run.sh 12 bash "$X/rebuild-merge.sh" $T 2>&1 | tee "$X/run$run/rebuild.log"
  echo "run $run exit ${PIPESTATUS[0]}  $(date +%H:%M:%S)"
done
echo; echo "== run 1 against run 2"
for run in 1 2; do (cd "$X/run$run/local" && find . -type f ! -name '*.log' ! -name '*.oci.tar' -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) > "$X/run$run.sha256"; done
cmp -s "$X/run1.sha256" "$X/run2.sha256" && echo "files: identical ($(wc -l < "$X/run1.sha256"))" || { echo "files differ:"; diff "$X/run1.sha256" "$X/run2.sha256" | head -20; }
for n in ws-pems ws-pems-job-worker wspems-mcp-server wspems-chat-server wspems-mcp-auth-broker; do
  printf '%s: ' $n; python3 "$R/1-ws-pems/scripts/6-images/oci-diff.py" "$X/run1/local/images/$n.oci.tar" "$X/run2/local/images/$n.oci.tar" 2>&1 | head -1
done
echo "== done $(date +%H:%M:%S)"
