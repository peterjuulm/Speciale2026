#!/bin/bash
# The new migrator against the old bundle, on scratch databases (written
# 13 October 2026).
#
# Runs the old migration bundle (OLD, made by dotnet ef migrations bundle) and
# the new migrator (NEW, src/DbMigrator) against copies of the same databases
# in a PostgreSQL container without a network, through its Unix socket, and
# compares what they leave: __EFMigrationsHistory and pg_dump of schema and
# data. Both run in a namespace without a network (unshare -rn), so no
# connection string from a settings file can reach a real database.
#
#   OUT=<private folder> OLD=<bundle> NEW=<migrator> OLDCWD=<dir> \
#     MIGRATION=<an older migration> migrator-parity.sh
#
# OLDCWD must have ../WebAPI/appsettings.Development.json: the old bundle's
# design-time factory reads that file and fails without it (see the note).
# The new migrator runs from an empty folder, as on a release machine. The
# container is rb1-mig-pg with its socket directory at /private/tmp/rb1-pgsock.
set -u
OUT=${OUT:?} OLD=${OLD:?} NEW=${NEW:?} OLDCWD=${OLDCWD:?} MIGRATION=${MIGRATION:?}
PG=rb1-mig-pg S=/private/tmp/rb1-pgsock
X=$OUT/extract EMPTY=$OUT/empty-cwd
mkdir -p "$OUT" "$X" "$EMPTY"
psql_() { docker exec "$PG" psql -U postgres -v ON_ERROR_STOP=1 -qtA "$@"; }
mkdb() { psql_ -c "CREATE DATABASE $1${2:+ TEMPLATE $2}"; }
conn() { printf 'Host=%s;Port=5432;Database=%s;Username=postgres' "$S" "$1"; }
base_env=(env -i HOME="$HOME" PATH=/usr/bin LC_ALL=C.UTF-8 DOTNET_BUNDLE_EXTRACT_BASE_DIR="$X" DOTNET_CLI_TELEMETRY_OPTOUT=1)
EXTRA_ENV=()
# run TAG DIR PROGRAM [ARGS...]: one run, with its log and exit code
run() {
  local tag=$1 dir=$2 start rc; shift 2
  start=$(date +%s)
  ( cd "$dir" && unshare -rn "${base_env[@]}" "${EXTRA_ENV[@]}" "$@" ) > "$OUT/$tag.log" 2>&1
  rc=$?
  echo "$tag exit $rc $(( $(date +%s) - start ))s"
}
dump() {
  docker exec "$PG" pg_dump -U postgres --no-owner --no-privileges --restrict-key=rb1 -d "$1" > "$OUT/$1.sql"
  psql_ -d "$1" -c 'SELECT "MigrationId", "ProductVersion" FROM "__EFMigrationsHistory" ORDER BY 1' > "$OUT/$1.history"
}
same() {
  if cmp -s "$OUT/$1.sql" "$OUT/$2.sql" && cmp -s "$OUT/$1.history" "$OUT/$2.history"; then
    echo "$1 vs $2: identical ($(wc -l < "$OUT/$1.history") migrations, $(wc -l < "$OUT/$1.sql") dump lines)"
  else
    echo "$1 vs $2: DIFFER ($(diff "$OUT/$1.sql" "$OUT/$2.sql" | grep -c '^[<>]') dump lines, history $(cmp -s "$OUT/$1.history" "$OUT/$2.history" && echo same || echo differs))"
  fi
}

echo "== P1: empty to the latest migration"
mkdb p1_old; mkdb p1_new
run p1-old "$OLDCWD" "$OLD" --connection "$(conn p1_old)"
run p1-new "$EMPTY" "$NEW" --connection "$(conn p1_new)"
dump p1_old; dump p1_new; same p1_old p1_new

echo "== P2: from an older migration to the latest"
mkdb p2_base
run p2-base "$OLDCWD" "$OLD" "$MIGRATION" --connection "$(conn p2_base)"
mkdb p2_old p2_base; mkdb p2_new p2_base
run p2-old "$OLDCWD" "$OLD" --connection "$(conn p2_old)"
run p2-new "$EMPTY" "$NEW" --connection "$(conn p2_new)"
dump p2_old; dump p2_new; same p2_old p2_new; same p1_new p2_new

echo "== P3: again, on an up-to-date database"
run p3-old "$OLDCWD" "$OLD" --connection "$(conn p2_old)"
run p3-new "$EMPTY" "$NEW" --connection "$(conn p2_new)"

echo "== P4: the connection from the environment alone, as the migrations image runs"
mkdb p4_new
EXTRA_ENV=(DatabaseOptions__Provider=postgres "ConnectionStrings__CatalogConnection=$(conn p4_new)")
run p4-new "$EMPTY" "$NEW"
echo "== P5: --connection over a wrong connection in the environment"
mkdb p5_new
EXTRA_ENV=("ConnectionStrings__CatalogConnection=$(conn no_such_db)")
run p5-new "$EMPTY" "$NEW" --connection "$(conn p5_new)"
EXTRA_ENV=()
dump p4_new; dump p5_new; same p1_new p4_new; same p1_new p5_new

echo "== P6: a database that does not exist"
run p6-old "$OLDCWD" "$OLD" --connection "$(conn no_such_db)"
run p6-new "$EMPTY" "$NEW" --connection "$(conn no_such_db)"

echo "== P7: --help"
run p7-old "$OLDCWD" "$OLD" --help
run p7-new "$EMPTY" "$NEW" --help
cmp -s "$OUT/p7-old.log" "$OUT/p7-new.log" && echo "help identical" || echo "help differs"

echo "== P8: from the latest back to the older migration"
mkdb p8_old p1_old; mkdb p8_new p1_new
run p8-old "$OLDCWD" "$OLD" "$MIGRATION" --connection "$(conn p8_old)"
run p8-new "$EMPTY" "$NEW" "$MIGRATION" --connection "$(conn p8_new)"
dump p8_old; dump p8_new; dump p2_base; same p8_old p8_new; same p2_base p8_new
