#!/bin/bash
# The developers' everyday commands on the WS branch (written 13 October 2026).
#
# Clones the branch head COMMIT into a fresh folder, as a developer's
# checkout, and runs the Makefile's targets there with the pinned SDK and
# Node, an empty home folder (no .NET user secrets) and no network: every
# step runs in its own user, network and PID namespace (unshare -rnp), so
# nothing it starts outlives it. The database steps reach a scratch
# PostgreSQL 17 container that has no network either, through its Unix
# socket: inside the namespace socat forwards 127.0.0.1:5432 to that socket,
# so even the developers' default connection string (localhost:5432) can
# only reach the scratch database.
#
#   OUT=<private folder> dev-workflows.sh COMMIT
#
# Each step's output goes to OUT/<step>.log, its exit code to OUT/steps.tsv,
# git status after it to OUT/<step>.status, and the checks to
# OUT/results.txt.
#   D1   make install-tools
#   D0s  add_migration.sh and remove_migration.sh run directly on the fresh
#        clone, before anything has restored
#   D0   make db-migrate on the fresh clone, as make setup runs it
#   D1   make build (Debug); D1-sln dotnet build WS.Phoenix.sln, which is
#        what make build means (the root also holds docker-compose.dcproj)
#   D2   make db-migrate into the empty database devflow; the migrations
#        applied. D2r the same with a remote host in the environment, which
#        main's design-time guard must refuse
#   D3   make db-migration-add name=ThesisProbe; the new migration's
#        operations; make db-migration-remove. add_migration.sh and
#        remove_migration.sh exit 0 also when dotnet ef fails, so dotnet
#        ef's own "Done." is checked
#   D6   a package ApplicationCore gets transitively, referenced directly:
#        the locked restore CI runs (GITHUB_ACTIONS=true) before and after a
#        developer's restore; then the change is undone
#   D3f  the two migration targets made to fail: a second add with the
#        same name, a second remove when the last migration left is
#        applied; the exit code and the targets' success messages
#   D4   make install-frontend (npm install, from the npm cache only)
#   D5   make dev-frontend; the start page over HTTP; the server stopped
#   D7   make clean; D8 make format-check, which must get past choosing
#        the solution (MSB1011); its own verdict is not checked
#
# 13 October 2026, after the first run: D0 and D1-sln added, D3 checks
# dotnet ef's "Done.". In the evening, for the branch's fixes: D0 counts
# the migrations it applied; D3f, D7 and D8 added. Later, for the scripts
# that restore for themselves: D0s.
#
# DOTNET_DIR and NODE_DIR select the SDK and Node (defaults Microsoft's
# 10.0.401 in /private/tmp/rb1-dotnet10/sdk and 22.23.3 in
# /private/tmp/rb1-node22). npm runs offline from /private/tmp/rb1-npm,
# without its audit and fund requests.
set -u
COMMIT=${1:?usage: OUT=<private folder> dev-workflows.sh COMMIT}
OUT=${OUT:?set OUT to a private data folder}
REPO=/home/leos/Dev/Weel-Sandvig/WS.Phoenix-repro
DN=${DOTNET_DIR:-/private/tmp/rb1-dotnet10/sdk}
NODE=${NODE_DIR:-/private/tmp/rb1-node22}
BASE=/private/tmp/rb1-devflow
LAB=$BASE/x SH=$BASE/home SOCK=$BASE/pgsock PG=rb1-devflow-pg
DB="Host=localhost;Port=5432;Database=devflow;Username=postgres"
ENV=(env -i HOME=$SH USER=$(id -un) PATH=$DN:$NODE/bin:/usr/bin DOTNET_ROOT=$DN
  DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1
  MSBUILDDISABLENODEREUSE=1 LC_ALL=C.UTF-8 npm_config_cache=/private/tmp/rb1-npm
  npm_config_offline=true npm_config_audit=false npm_config_fund=false
  npm_config_update_notifier=false NEXT_TELEMETRY_DISABLED=1)
R=$OUT/results.txt

# step NAME COMMAND...: COMMAND in the lab, in fresh namespaces without a network
step() {
  local name=$1; shift
  ( cd "$LAB" && unshare -rnp --fork sh -c 'ip link set lo up || exit 97; "$@"' sh "${ENV[@]}" "$@" ) > "$OUT/$name.log" 2>&1
  finish "$name" $?
}
# dbstep NAME COMMAND...: as step, with 127.0.0.1:5432 forwarded to the scratch database
dbstep() {
  local name=$1; shift
  ( cd "$LAB" && unshare -rnp --fork sh -c 'ip link set lo up || exit 97
      socat TCP-LISTEN:5432,bind=127.0.0.1,reuseaddr,fork "UNIX-CONNECT:$0" & sleep 0.5; "$@"' \
      "$SOCK/.s.PGSQL.5432" "${ENV[@]}" "$@" ) > "$OUT/$name.log" 2>&1
  finish "$name" $?
}
finish() {
  printf '%s\t%s\t%s\n' "$1" "$2" "$(date +%T)" >> "$OUT/steps.tsv"
  git -C "$LAB" status --porcelain > "$OUT/$1.status"
  echo "$1: exit $2, $(wc -l < "$OUT/$1.status") paths changed in git status" | tee -a "$R"
}

mkdir -p "$OUT"; : > "$OUT/steps.tsv"; : > "$R"
rm -rf "$BASE" && mkdir -p "$SH" "$SOCK" && chmod 1777 "$SOCK"
git clone -q --depth 1 --branch thesis/reproducible-builds "file://$REPO" "$LAB"
echo "lab at $(git -C "$LAB" rev-parse --short HEAD), asked for $COMMIT" | tee -a "$R"
[[ $(git -C "$LAB" rev-parse HEAD) == $(git -C "$REPO" rev-parse "$COMMIT") ]] || { echo "the branch head is not $COMMIT" | tee -a "$R"; exit 1; }

step D1-tools make install-tools

docker rm -f $PG > /dev/null 2>&1
docker run -d --name $PG --network none -e POSTGRES_HOST_AUTH_METHOD=trust -v "$SOCK:/var/run/postgresql" postgres:17-alpine > /dev/null
for i in $(seq 1 60); do docker exec $PG createdb -U postgres devflow 2> /dev/null && break; sleep 1; done
dbstep D0s-add env ConnectionStrings__CatalogConnection="$DB" sh -c 'cd src/WebAPI && ./add_migration.sh ThesisFresh'
echo "D0s-add: dotnet ef Done.: $(grep -c '^Done\.' "$OUT/D0s-add.log"); NETSDK1004: $(grep -c NETSDK1004 "$OUT/D0s-add.log"); ThesisFresh files: $(grep -c ThesisFresh "$OUT/D0s-add.status")" | tee -a "$R"
dbstep D0s-remove env ConnectionStrings__CatalogConnection="$DB" sh -c 'cd src/WebAPI && ./remove_migration.sh'
echo "D0s-remove: dotnet ef Done.: $(grep -c '^Done\.' "$OUT/D0s-remove.log"); ThesisFresh files: $(grep -c ThesisFresh "$OUT/D0s-remove.status")" | tee -a "$R"
dbstep D0-migrate-fresh env ConnectionStrings__CatalogConnection="$DB" make db-migrate
echo "D0: NETSDK1004: $(grep -c NETSDK1004 "$OUT/D0-migrate-fresh.log"); migrations applied: $(docker exec $PG psql -U postgres -d devflow -tAc 'select count(*) from "__EFMigrationsHistory"' 2>&1 | head -1)" | tee -a "$R"
step D1-build make build
echo "D1-build: MSB1011: $(grep -c MSB1011 "$OUT/D1-build.log")" | tee -a "$R"
step D1-sln dotnet build WS.Phoenix.sln
dbstep D2 env ConnectionStrings__CatalogConnection="$DB" make db-migrate
echo "D2: migrations applied: $(docker exec $PG psql -U postgres -d devflow -tAc 'select count(*) from "__EFMigrationsHistory"')" | tee -a "$R"
step D2r env ConnectionStrings__CatalogConnection="Host=db.example.invalid;Port=5432;Database=x;Username=x" make db-migrate
echo "D2r: guard message: $(grep -c 'which is not a local host' "$OUT/D2r.log")" | tee -a "$R"

dbstep D3-add env ConnectionStrings__CatalogConnection="$DB" make db-migration-add name=ThesisProbe
echo "D3: dotnet ef Done.: $(grep -c '^Done\.' "$OUT/D3-add.log"); factory: $(grep -oE "Using DbContext factory '[A-Za-z]+'" "$OUT/D3-add.log" | sort -u | tr '\n' ' ')" | tee -a "$R"
for f in $(sed -n 's/^?? //p' "$OUT/D3-add.status"); do
  echo "D3: new $f, $(find "$LAB/$f" -type f | wc -l) files" | tee -a "$R"
  for m in $(find "$LAB/$f" -type f -name '*_ThesisProbe.cs'); do
    echo "D3: $(basename "$m"): $(grep -c 'migrationBuilder\.' "$m") operations" | tee -a "$R"
  done
done
dbstep D3f-add env ConnectionStrings__CatalogConnection="$DB" make db-migration-add name=ThesisProbe
echo "D3f-add: 'Migration created!': $(grep -c 'Migration created!' "$OUT/D3f-add.log"); name taken: $(grep -c 'is used by an existing migration' "$OUT/D3f-add.log")" | tee -a "$R"
dbstep D3-remove env ConnectionStrings__CatalogConnection="$DB" make db-migration-remove
echo "D3-remove: dotnet ef Done.: $(grep -c '^Done\.' "$OUT/D3-remove.log")" | tee -a "$R"
dbstep D3f-remove env ConnectionStrings__CatalogConnection="$DB" make db-migration-remove
echo "D3f-remove: 'Migration removed!': $(grep -c 'Migration removed!' "$OUT/D3f-remove.log"); already applied: $(grep -c 'has already been applied to the database' "$OUT/D3f-remove.log")" | tee -a "$R"

read -r PKG VER < <(python3 - "$LAB/src/ApplicationCore/packages.lock.json" <<'PY'
import json,sys
deps=json.load(open(sys.argv[1]))["dependencies"]
for tfm,d in deps.items():
    for name,e in sorted(d.items()):
        if e.get("type")=="Transitive" and name.startswith("Microsoft.Extensions."):
            print(name,e["resolved"]); sys.exit()
PY
)
python3 - "$LAB/src/ApplicationCore/ApplicationCore.csproj" "$PKG" "$VER" <<'PY'
import sys
p,name,ver=sys.argv[1:]
s=open(p,encoding='utf-8').read()
i=s.index('<PackageReference ')
s=s[:i]+'<PackageReference Include="%s" Version="%s" />\n    '%(name,ver)+s[i:]
open(p,'w',encoding='utf-8').write(s)
PY
echo "D6: referenced $PKG $VER directly in ApplicationCore" | tee -a "$R"
step D6-locked-before env GITHUB_ACTIONS=true dotnet restore WS.Phoenix.sln
echo "D6: NU1004 before: $(grep -c NU1004 "$OUT/D6-locked-before.log")" | tee -a "$R"
step D6-dev dotnet restore WS.Phoenix.sln
step D6-locked-after env GITHUB_ACTIONS=true dotnet restore WS.Phoenix.sln
git -C "$LAB" checkout -q -- . && echo "D6: undone, $(git -C "$LAB" status --porcelain | wc -l) paths changed" | tee -a "$R"

step D4 make install-frontend
L=src/WebAPI/ClientApp/package-lock.json
if git -C "$LAB" diff --quiet -- $L; then echo "D4: lock unchanged" | tee -a "$R"; else
  echo "D4: lock changed: $(git -C "$LAB" diff --numstat -- $L | cut -f1,2 | tr '\t' '/') lines added/removed;" \
    "libc +$(git -C "$LAB" diff -- $L | grep -c '^+.*"libc"') -$(git -C "$LAB" diff -- $L | grep -c '^-.*"libc"')," \
    "resolved +$(git -C "$LAB" diff -- $L | grep -c '^+.*"resolved"') -$(git -C "$LAB" diff -- $L | grep -c '^-.*"resolved"')," \
    "integrity +$(git -C "$LAB" diff -- $L | grep -c '^+.*"integrity"') -$(git -C "$LAB" diff -- $L | grep -c '^-.*"integrity"')" | tee -a "$R"
  git -C "$LAB" diff -- $L > "$OUT/D4-lock.diff"
fi

step D5 sh -c 'make dev-frontend > "$0/D5-server.log" 2>&1 &
  for i in $(seq 1 300); do curl -s -o /dev/null http://localhost:44456/ && break; sleep 1; done
  curl -s -o "$0/D5-page.html" -w "HTTP %{http_code}, %{size_download} bytes, %{time_total} s\n" http://localhost:44456/' "$OUT"
echo "D5: $(tail -1 "$OUT/D5.log"); server log: $(grep -ciE 'error|failed to compile' "$OUT/D5-server.log") lines with error, ready: $(grep -ciE 'ready|compiled' "$OUT/D5-server.log")" | tee -a "$R"

step D7 make clean
echo "D7: MSB1011: $(grep -c MSB1011 "$OUT/D7.log")" | tee -a "$R"
step D8 make format-check
echo "D8: MSB1011: $(grep -c MSB1011 "$OUT/D8.log"); 'Multiple' or 'Specify which': $(grep -cE 'Multiple MSBuild|Specify which' "$OUT/D8.log")" | tee -a "$R"

docker rm -f $PG > /dev/null
echo "done $(date +%T)" | tee -a "$R"
