#!/bin/bash
#
# arch-migrator.sh
#
# The merge's database migrator against PostgreSQL 17 on Leo's Arch laptop,
# driven from the Mac over SSH. Two linux-x64 builds of ws-pems-db-migrator,
# published on the Mac from 81b0e8450 as the release publishes it:
#   merged     81b0e8450 as committed (option A)
#   as-merged  81b0e8450 with src/DbMigrator as it was before option A
#              (765ea6aa2's four files): the state git's merge left
# A throwaway container rb1-smoke-pg (postgres:17-alpine, trust auth, a
# port Docker picks on 127.0.0.1) holds the databases; it is removed at the
# end. The release's own smoke-test script (03-release.yml at 81b0e8450)
# runs in a stand-in workspace: the migrator under bundles/, and empty files
# with the names of src/Infrastructure.Migrations/Data/Migrations.
#   M1  the release's smoke test, merged migrator: exit 0 expected
#   M2  merged migrator again on smoke_cli: nothing to apply, exit 0
#   M3  as-merged migrator on a new database: its exit code, and the
#       history table it leaves
#   M4  the release's smoke test with the as-merged migrator: the count
#       check must fail it
#   M5  merged migrator on a new database under a Danish culture
#       (LANG=da_DK.UTF-8, no LC_ALL): the autovacuum migration of
#       20261120161834 renders 0.01 by the culture (0,01 in the SQL on the
#       Mac's Danish region)
# M1-M4 run with LC_ALL=C.UTF-8, as the release's migration job sets it.
# Every log also goes to /private/tmp/rb1-npmpin-logs/ on Arch, so it can be
# followed there with tail -f. Results on the Mac in OUT (default
# /private/tmp/rb1-arch-migrator).
#
# Written 23 November 2026 for the merge of main (option A).

set -uo pipefail
arch=leos@192.168.9.124
stage=/private/tmp/rb1-migrator-stage
out=${OUT:-/private/tmp/rb1-arch-migrator}
r=/private/tmp/rb1-npmpin-migrator
mkdir -p "$out"

# The stand-in workspace and the two migrators.
mkdir -p "$stage/ws/bundles" "$stage/ws/src/Infrastructure.Migrations/Data/Migrations" "$stage/merged" "$stage/as-merged"
(cd "$stage/ws/src/Infrastructure.Migrations/Data/Migrations" && xargs touch < "$stage/migration-files.txt")
cp /private/tmp/rb1-pub-a/publish/migrator/ws-pems-db-migrator "$stage/merged/"
cp /private/tmp/rb1-pub-neg/publish/migrator/ws-pems-db-migrator "$stage/as-merged/"
shasum -a 256 "$stage"/*/ws-pems-db-migrator | tee "$out/migrators.sha256"

ssh -o BatchMode=yes "$arch" "rm -rf $r && mkdir -p $r /private/tmp/rb1-npmpin-logs"
scp -q -r "$stage/ws" "$stage/merged" "$stage/as-merged" "$stage/smoke-step.sh" "$arch:$r/"

ssh -o BatchMode=yes "$arch" 'bash -s' > "$out/run.log" 2>&1 <<'EOF'
set -uo pipefail
r=/private/tmp/rb1-npmpin-migrator
logs=/private/tmp/rb1-npmpin-logs
exec > >(tee "$logs/migrator.log") 2>&1
export LC_ALL=C.UTF-8
echo "== $(date -Is) on $(uname -n)"
sha256sum "$r"/merged/ws-pems-db-migrator "$r"/as-merged/ws-pems-db-migrator
chmod +x "$r"/merged/ws-pems-db-migrator "$r"/as-merged/ws-pems-db-migrator
docker rm -f rb1-smoke-pg > /dev/null 2>&1 || true
docker run -d --name rb1-smoke-pg -e POSTGRES_HOST_AUTH_METHOD=trust -p 127.0.0.1::5432 postgres:17-alpine > /dev/null
for i in $(seq 1 60); do docker exec rb1-smoke-pg pg_isready -U postgres -h 127.0.0.1 > /dev/null 2>&1 && break; sleep 1; done
port=$(docker port rb1-smoke-pg 5432/tcp | head -n 1 | sed 's/.*://')
pg=$(docker inspect -f '{{.Id}}' rb1-smoke-pg)
echo "postgres $(docker exec rb1-smoke-pg postgres --version), 127.0.0.1:$port"
db="Host=127.0.0.1;Port=$port;Username=postgres"
history() { docker exec rb1-smoke-pg psql -U postgres -d "$1" -tA -F ' ' -c 'SELECT count(*), max("MigrationId" COLLATE "C") FROM "__EFMigrationsHistory"' 2>&1; }

smoke() {  # smoke VARIANT: the release's step, in the stand-in workspace
    rm -rf "$r/work-$1" "$r/temp-$1"
    cp -r "$r/ws" "$r/work-$1"
    mkdir -p "$r/temp-$1"
    cp "$r/$1/ws-pems-db-migrator" "$r/work-$1/bundles/ws-pems-db-migrator-linux-x64-v0.0.0-thesis"
    docker exec rb1-smoke-pg psql -U postgres -qc 'DROP DATABASE IF EXISTS smoke_cli' -c 'DROP DATABASE IF EXISTS smoke_env'
    (cd "$r/work-$1" && env REF_NAME=v0.0.0-thesis SMOKE_DB="$db" SMOKE_PG="$pg" RUNNER_TEMP="$r/temp-$1" \
        PATH=/usr/bin:/bin bash -e "$r/smoke-step.sh")
}

echo; echo "== M1 the release's smoke test, merged migrator"
smoke merged; echo "M1 exit $?"

echo; echo "== M2 merged migrator again on smoke_cli"
(cd /tmp && "$r/merged/ws-pems-db-migrator" --connection "$db;Database=smoke_cli"); echo "M2 exit $?"
echo "smoke_cli history: $(history smoke_cli)"

echo; echo "== M3 as-merged migrator on a new database"
(cd /tmp && "$r/as-merged/ws-pems-db-migrator" --connection "$db;Database=smoke_neg"); echo "M3 exit $?"
echo "smoke_neg history: $(history smoke_neg)"
echo "smoke_neg tables: $(docker exec rb1-smoke-pg psql -U postgres -d smoke_neg -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'" 2>&1)"

echo; echo "== M4 the release's smoke test, as-merged migrator"
smoke as-merged; echo "M4 exit $?"

echo; echo "== M5 merged migrator on a new database, LANG=da_DK.UTF-8 and no LC_ALL"
(cd /tmp && env -u LC_ALL LANG=da_DK.UTF-8 "$r/merged/ws-pems-db-migrator" --connection "$db;Database=smoke_da" > "$logs/m5.log" 2>&1); echo "M5 exit $?"
grep -E 'Applying migration|scale_factor|ERROR|42601|syntax|Npgsql' "$logs/m5.log" | tail -6
echo "smoke_da history: $(history smoke_da)"

docker rm -f rb1-smoke-pg > /dev/null
echo; echo "== done $(date -Is); rb1-smoke-pg removed"
EOF
grep -E '^(==|M[1-5] exit|smoke_|postgres|::error|.*expected|.*scale_factor|.*42601)' "$out/run.log" | tee "$out/summary.txt"
