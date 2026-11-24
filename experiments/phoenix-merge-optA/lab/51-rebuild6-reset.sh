# Before the v0.0.0-thesis.6 rebuild on 24 November, after arch's reboot:
# restore the shared memory guard, set aside the interrupted run of 23/11,
# and start again from an empty NuGet folder and a newly filled npm cache.
set -euo pipefail
N=/private/tmp/rb1-rebuild6 t=v0.0.0-thesis.6
echo "-- 1. the guard /tmp/claude-1000/ws-mem-run.sh (tmpfs, gone after the reboot), restored from the last"
echo "      version the Arch setup session wrote (its transcript 3b788f37, 20/11; two writes, equal, no edits)"
echo "db14855a86ef98d149e9026e334621646b6b1e08705fdfaacdde130e53ccc480  /private/tmp/rb1-lab/ws-mem-run.sh.restored" | sha256sum -c --strict -
install -m 755 /private/tmp/rb1-lab/ws-mem-run.sh.restored /tmp/claude-1000/ws-mem-run.sh
ls -l /tmp/claude-1000/ws-mem-run.sh; sha256sum /tmp/claude-1000/ws-mem-run.sh
echo "-- 2. the interrupted run of 23/11 set aside"
I=/private/tmp/rb1-rebuild6-interrupted-2026-11-23
if [ ! -e "$I" ]; then mkdir "$I"; mv "$N/local" "$N/rebuild.log" "$N/environment.txt" "$I/"; fi
ls "$N" "$I"; tail -n 5 "$I/rebuild.log"
echo "-- 3. NuGet: /private/tmp/rb1-dch, which the interrupted linux job had partly filled, emptied; /tmp/dch points to it"
du -sh /private/tmp/rb1-dch
rm -rf /private/tmp/rb1-dch && mkdir /private/tmp/rb1-dch && ln -sfn /private/tmp/rb1-dch /tmp/dch && ls -la /tmp/dch
echo "-- 4. npm: the cache filled on 23/11 set aside, and filled again online from the tag's lock with the tag's npm (10.9.9)"
[ -e /private/tmp/rb1-npm-filled-2026-11-23 ] || mv /private/tmp/rb1-npm /private/tmp/rb1-npm-filled-2026-11-23
rm -rf /private/tmp/rb1-npm
fill=/private/tmp/rb1-rebuild6-fill; rm -rf "$fill"; mkdir -p "$fill"
git -C /private/tmp/rb1-merge-src archive $t src/WebAPI/ClientApp | tar -x -C "$fill"
(cd "$fill/src/WebAPI/ClientApp" && env -i HOME=/tmp/dch PATH=/private/tmp/rb1-rebuild6-node/bin:/usr/bin:/bin \
  npm_config_cache=/private/tmp/rb1-npm npm_config_update_notifier=false npm ci --ignore-scripts --no-audit --no-fund 2>&1 | grep -v deprecated | tail -2)
echo "npm $(PATH=/private/tmp/rb1-rebuild6-node/bin:/usr/bin:/bin npm --version); cache $(du -sh /private/tmp/rb1-npm | cut -f1)"
echo "what the fill left in /tmp/dch: $(find /tmp/dch/ -mindepth 1 | head -5 | tr '\n' ' ')($(find /tmp/dch/ -mindepth 1 | wc -l) entries)"
echo "-- 5. the published assets, again against SHA256SUMS"
(cd "$N/assets" && sha256sum -c --strict --quiet SHA256SUMS && echo "all 7 named files ok"); sha256sum "$N/assets/SHA256SUMS" "$N/assets/upgrade.sh"
find "$N/ci" -type f | sort
grep MemAvailable /proc/meminfo
