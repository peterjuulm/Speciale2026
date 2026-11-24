# D4 (again, lowercase tag): the migrations image (deployment/migrations/Dockerfile) of thesis-merge,
# built by Docker's default builder under the shared lock (BuildKit runs
# outside any user scope), then run against a throwaway PostgreSQL 17 on a
# network of its own, with the release smoke test's count check.
set -uo pipefail
src=/private/tmp/rb1-merge-src lab=/private/tmp/rb1-optA-image
rm -rf "$lab"; mkdir -p "$lab"; git -C "$src" archive thesis-merge -- . ':(exclude).claude' | tar -x -C "$lab"
echo "MemAvailable before: $(awk '/MemAvailable/ {printf "%d GB", $2/1048576}' /proc/meminfo)"
flock /tmp/claude-1000/phoenix-dotnet.lock docker build -f "$lab/deployment/migrations/Dockerfile" --build-arg APP_VERSION=v0.0.0-thesis -t rb1-opta-migrations:test "$lab" 2>&1 | tail -6
echo "build exit ${PIPESTATUS[0]}"
docker image inspect rb1-opta-migrations:test --format 'image {{.Id}} {{.Size}}'
docker rm -f rb1-optA-pg > /dev/null 2>&1; docker network rm rb1-optA-net > /dev/null 2>&1
docker network create rb1-optA-net > /dev/null
docker run -d --name rb1-optA-pg --network rb1-optA-net -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17-alpine > /dev/null
for i in $(seq 1 60); do docker exec rb1-optA-pg pg_isready -U postgres -h 127.0.0.1 > /dev/null 2>&1 && break; sleep 1; done
docker run --rm --network rb1-optA-net -e ConnectionStrings__CatalogConnection="Host=rb1-optA-pg;Username=postgres;Database=image_env" rb1-opta-migrations:test 2>&1 | grep -E 'Applying|Done|error|Error' | tail -3; echo "image run exit ${PIPESTATUS[0]}"
ids=$(git -C "$src" ls-tree --name-only thesis-merge src/Infrastructure.Migrations/Data/Migrations/ | sed 's#.*/##' | grep -E '^2.*\.cs$' | grep -v Designer | sed 's/\.cs$//' | LC_ALL=C sort)
echo "expected: $(printf '%s\n' "$ids" | grep -c .) $(printf '%s\n' "$ids" | tail -n 1)"
echo "image_env: $(docker exec rb1-optA-pg psql -U postgres -d image_env -tA -F ' ' -c 'SELECT count(*), max("MigrationId" COLLATE "C") FROM "__EFMigrationsHistory"')"
docker rm -f rb1-optA-pg > /dev/null; docker network rm rb1-optA-net > /dev/null; echo "rb1-optA-pg and rb1-optA-net removed"
