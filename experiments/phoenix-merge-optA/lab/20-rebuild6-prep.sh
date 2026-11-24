# Preparation for rebuilding v0.0.0-thesis.6 (be5fc56e) on arch: empty
# caches, a fresh Node, and what GitHub published. Nothing heavy.
set -euo pipefail
N=/private/tmp/rb1-rebuild6
echo "-- 1. NuGet: rebuild.sh's folder /tmp/dch (tmpfs) moved aside; /tmp/dch now points to an empty folder on disk"
if [ -d /tmp/dch ] && [ ! -L /tmp/dch ]; then du -sh /tmp/dch; mv /tmp/dch /private/tmp/rb1-dch-before-2026-11-23; fi
rm -rf /private/tmp/rb1-dch && mkdir /private/tmp/rb1-dch && ln -sfn /private/tmp/rb1-dch /tmp/dch && ls -la /tmp/dch
echo "-- 2. npm: the cache /private/tmp/rb1-npm moved aside"
if [ -d /private/tmp/rb1-npm ] && [ ! -e /private/tmp/rb1-npm-before-2026-11-23 ]; then mv /private/tmp/rb1-npm /private/tmp/rb1-npm-before-2026-11-23; fi
ls -d /private/tmp/rb1-npm 2>/dev/null || echo "no /private/tmp/rb1-npm: starts empty"
echo "-- 3. Node 22.23.3 from nodejs.org, checked against node.sha256's line"
d=/private/tmp/rb1-rebuild6-dl; rm -rf "$d" /private/tmp/rb1-rebuild6-node; mkdir -p "$d" /private/tmp/rb1-rebuild6-node
f=node-v22.23.3-linux-x64.tar.gz
curl -fsSL -o "$d/$f" "https://nodejs.org/dist/v22.23.3/$f"
(cd "$d" && echo "1084aa36196bba4c3a5e69a1ee388a6e4ff729dad09445fbcd434b28fe3c24af  $f" | sha256sum -c --strict -)
tar -xzf "$d/$f" -C /private/tmp/rb1-rebuild6-node --strip-components=1 --no-same-owner
echo "node $(/private/tmp/rb1-rebuild6-node/bin/node --version), npm $(PATH=/private/tmp/rb1-rebuild6-node/bin:/usr/bin:/bin npm --version)"
echo "-- 4. the npm cache filled online from the tag's lock, with the tag's npm"
fill=/private/tmp/rb1-rebuild6-fill; rm -rf "$fill"; mkdir -p "$fill"
git -C /private/tmp/rb1-merge-src archive v0.0.0-thesis.6 src/WebAPI/ClientApp | tar -x -C "$fill"
(cd "$fill/src/WebAPI/ClientApp" && env -i HOME=/tmp/dch PATH=/private/tmp/rb1-rebuild6-node/bin:/usr/bin:/bin \
  npm_config_cache=/private/tmp/rb1-npm npm_config_update_notifier=false npm ci --ignore-scripts --no-audit --no-fund 2>&1 | grep -v deprecated | tail -2)
du -sh /private/tmp/rb1-npm
echo "-- 5. what GitHub published: the release's assets, laid out as compare.sh reads a run's artifacts"
rm -rf "$N"; mkdir -p "$N/assets"
gh release download v0.0.0-thesis.6 -R Weel-Sandvig/WS.Phoenix -D "$N/assets"
ls -la "$N/assets"
(cd "$N/assets" && sha256sum -c SHA256SUMS 2>&1 | sed 's/^/  /'; sha256sum upgrade.sh SHA256SUMS)
c=$N/ci; mkdir -p $c/release-zips-linux $c/release-zips-windows $c/db-migration-bundles-linux $c/db-migration-bundles-windows $c/sha256sums
a=$N/assets t=v0.0.0-thesis.6
ln $a/ws-pems-linux-x64-$t.zip $a/ws-pems-job-worker-linux-x64-$t.zip $c/release-zips-linux/
ln $a/ws-pems-win-x64-$t.zip $a/ws-pems-job-worker-win-x64-$t.zip $c/release-zips-windows/
ln $a/ws-pems-db-migrator-linux-x64-$t $a/bootstrap-postgresql-$t.sql $c/db-migration-bundles-linux/
ln $a/ws-pems-db-migrator-win-x64-$t.exe $c/db-migration-bundles-windows/
ln $a/SHA256SUMS $c/sha256sums/
find $c -type f | sort
grep MemAvailable /proc/meminfo
