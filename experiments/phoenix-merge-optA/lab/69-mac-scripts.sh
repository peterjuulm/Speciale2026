# The Mac Studio (macOS arm64), 24 November evening: the stage-1 job scripts
# publish-linux.sh and migration-bundles.sh, natively, on dry run 5's commit
# (8491a0d63, v0.0.0-dryrun.5), against what GitHub built in that run. The
# frontend export is the run's own (a darwin Node is not pinned). SDK 10.0.401
# from the branch's installer in ~/rb1-dotnet-10.0.401, a fresh NuGet folder,
# env -i. Packing needs GNU realpath -m and touch -d: the two Python shims of
# the 23/11 Mac rebuild (data/2026-11-23-phoenix-macstudio-rebuild), in
# /private/tmp/rb1-mac-tools. rebuild.sh itself is Linux x64 only.
set -uo pipefail
M=/private/tmp/rb1-mac-dry5 RUN=45403522195 T=v0.0.0-dryrun.5 C=8491a0d63ca5e82877fae68262c5bafcd7fc18ef
rm -rf "$M"; mkdir -p "$M/ci"
for a in release-frontend-export release-zips-linux db-migration-bundles-linux release-checksums; do
  gh run download $RUN -R Weel-Sandvig/WS.Phoenix -n $a -D "$M/ci/$a" > /dev/null || echo "FAILED $a"
done
run() { local d=$1; shift
  (cd "$d" && env -i HOME="$M/home" USER="$USER" PATH="/private/tmp/rb1-mac-tools:$HOME/rb1-dotnet-10.0.401:/usr/bin:/bin:/usr/sbin:/sbin" \
    DOTNET_ROOT="$HOME/rb1-dotnet-10.0.401" DOTNET_CLI_HOME="$M/home" NUGET_PACKAGES="$M/nuget" DOTNET_NOLOGO=1 \
    MSBUILDDISABLENODEREUSE=1 APP_VERSION=$T "$@") }
for job in linux migrator; do
  git clone -q --no-checkout ~/rb1-phoenix-stages "$M/$job" && git -C "$M/$job" checkout -q --detach $C && git -C "$M/$job" remote set-url origin https://github.com/Weel-Sandvig/WS.Phoenix
done
cp -a "$M/ci/release-frontend-export" "$M/linux/src/WebAPI/ClientApp/out"
echo "== publish-linux.sh $(date +%H:%M:%S)"; run "$M/linux" scripts/release/publish-linux.sh > "$M/linux.log" 2>&1; echo "exit $?"
echo "== migration-bundles.sh $(date +%H:%M:%S)"; run "$M/migrator" scripts/release/migration-bundles.sh > "$M/migrator.log" 2>&1; echo "exit $?"
echo "== against dry run 5 $(date +%H:%M:%S)"
for f in ws-pems-linux-x64-$T.zip ws-pems-job-worker-linux-x64-$T.zip; do
  cmp -s "$M/ci/release-zips-linux/$f" "$M/linux/release/$f" && echo "same  $f" || echo "DIFF  $f"; done
for f in ws-pems-db-migrator-linux-x64-$T bootstrap-postgresql-$T.sql; do
  cmp -s "$M/ci/db-migration-bundles-linux/$f" "$M/migrator/bundles/$f" && echo "same  $f" || echo "DIFF  $f"; done
grep -h -E "  ws-pems-(job-worker-)?linux-x64|  ws-pems-db-migrator-linux|  bootstrap-postgresql" "$M/ci/release-checksums/SHA256SUMS" | cut -c1-16 | tr '\n' ' '; echo "(the run's SHA256SUMS)"
cat "$M/linux/sums/zips-linux.sha256" "$M/migrator/sums/db-linux.sha256" | cut -c1-16 | tr '\n' ' '; echo "(the Mac's)"
echo "== done $(date +%H:%M:%S)"
