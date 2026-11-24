# The release's assets against its SHA256SUMS (which names the migrators and
# the SQL script under db/, the layout before 28371c9e), then laid out as
# compare.sh reads a run's artifacts.
set -euo pipefail
N=/private/tmp/rb1-rebuild6 t=v0.0.0-thesis.6
a=$N/assets c=$N/ci
mkdir -p $a/db
for f in ws-pems-db-migrator-linux-x64-$t ws-pems-db-migrator-win-x64-$t.exe bootstrap-postgresql-$t.sql; do ln -f $a/$f $a/db/$f; done
(cd $a && sha256sum -c --strict SHA256SUMS)
sha256sum $a/SHA256SUMS $a/upgrade.sh
rm -rf $c; mkdir -p $c/release-zips-linux $c/release-zips-windows $c/db-migration-bundles-linux $c/db-migration-bundles-windows $c/sha256sums
ln $a/ws-pems-linux-x64-$t.zip $a/ws-pems-job-worker-linux-x64-$t.zip $c/release-zips-linux/
ln $a/ws-pems-win-x64-$t.zip $a/ws-pems-job-worker-win-x64-$t.zip $c/release-zips-windows/
ln $a/ws-pems-db-migrator-linux-x64-$t $a/bootstrap-postgresql-$t.sql $c/db-migration-bundles-linux/
ln $a/ws-pems-db-migrator-win-x64-$t.exe $c/db-migration-bundles-windows/
ln $a/SHA256SUMS $c/sha256sums/
find $c -type f | sort
