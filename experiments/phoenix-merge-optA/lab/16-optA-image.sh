# D4, run 24 November: the migrations image (deployment/migrations/Dockerfile)
# of thesis-merge (30b5c745d). The release workflow does not build this image.
#  a) Reproducible? Built twice by BuildKit v0.33.1 (builder rb1) as the
#     release's images are built (rebuild.sh's build_images: --no-cache,
#     no provenance, SOURCE_DATE_EPOCH = the commit's time, OCI output with
#     rewrite-timestamp), from two shallow clones at two different paths.
#     Then oci-diff.py, run 1 against run 2.
#  b) Does it migrate? Built by Docker's default builder and run against a
#     throwaway PostgreSQL 17, with the release smoke test's count check.
# BuildKit runs outside any user scope, so every build holds the guard's lock
# and runs alone.
set -uo pipefail
src=/private/tmp/rb1-merge-src out=/private/tmp/rb1-optA-image-oci
R=/private/tmp/rb1-dre url=https://github.com/Weel-Sandvig/WS.Phoenix
export DOCKER_CONFIG=/private/tmp/rb1-docker
echo "thesis-merge $(git -C "$src" rev-parse thesis-merge)"
echo "MemAvailable before: $(awk '/MemAvailable/ {printf "%d GB", $2/1048576}' /proc/meminfo)"
rm -rf "$out"; mkdir -p "$out"
for run in a b; do
  c=/private/tmp/rb1-mig-$run; [ $run = b ] && c=/private/tmp/rb1-mig-b-other-path
  rm -rf "$c"; git clone -q --depth 1 --branch thesis-merge "file://$src" "$c" && git -C "$c" remote set-url origin "$url"
  epoch=$(git -C "$c" log -1 --format=%ct)
  echo "== build $run from $c, SOURCE_DATE_EPOCH=$epoch  $(date +%H:%M:%S)"
  flock /tmp/claude-1000/phoenix-dotnet.lock env SOURCE_DATE_EPOCH="$epoch" docker buildx build --builder rb1 --no-cache --provenance=false \
    -f "$c/deployment/migrations/Dockerfile" --build-arg APP_VERSION=v0.0.0-merge-optA.1 \
    --output "type=oci,dest=$out/migrations-$run.oci.tar,rewrite-timestamp=true" "$c" > "$out/migrations-$run.log" 2>&1
  echo "build $run exit $?  $(date +%H:%M:%S)"; tail -n 2 "$out/migrations-$run.log"
  tar -xOf "$out/migrations-$run.oci.tar" index.json | python3 -c 'import json,sys; m=json.load(sys.stdin)["manifests"]; print("manifest", [x["digest"] for x in m])'
done
echo "== run a against run b"
python3 "$R/1-ws-pems/scripts/6-images/oci-diff.py" "$out/migrations-a.oci.tar" "$out/migrations-b.oci.tar" 2>&1 | head -20

echo; echo "== b) the image migrates a database  $(date +%H:%M:%S)"
unset DOCKER_CONFIG
lab=/private/tmp/rb1-optA-image
rm -rf "$lab"; mkdir -p "$lab"; git -C "$src" archive thesis-merge -- . ':(exclude).claude' | tar -x -C "$lab"
flock /tmp/claude-1000/phoenix-dotnet.lock docker build -f "$lab/deployment/migrations/Dockerfile" --build-arg APP_VERSION=v0.0.0-merge-optA.1 -t rb1-opta-migrations:test "$lab" 2>&1 | tail -4
echo "build exit ${PIPESTATUS[0]}"
docker image inspect rb1-opta-migrations:test --format 'image {{.Id}} {{.Size}}'
docker rm -f rb1-optA-pg > /dev/null 2>&1; docker network rm rb1-optA-net > /dev/null 2>&1
docker network create rb1-optA-net > /dev/null
docker run -d --name rb1-optA-pg --network rb1-optA-net -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17-alpine > /dev/null
for i in $(seq 1 60); do docker exec rb1-optA-pg pg_isready -U postgres -h 127.0.0.1 > /dev/null 2>&1 && break; sleep 1; done
docker run --rm --network rb1-optA-net -e ConnectionStrings__CatalogConnection="Host=rb1-optA-pg;Username=postgres;Database=image_env" rb1-opta-migrations:test > "$out/run.log" 2>&1; echo "image run exit $?"
grep -E 'Applying|Done|rror' "$out/run.log" | tail -3
ids=$(git -C "$src" ls-tree --name-only thesis-merge src/Infrastructure.Migrations/Data/Migrations/ | sed 's#.*/##' | grep -E '^2.*\.cs$' | grep -v Designer | sed 's/\.cs$//' | LC_ALL=C sort)
echo "expected: $(printf '%s\n' "$ids" | grep -c .) $(printf '%s\n' "$ids" | tail -n 1)"
echo "image_env: $(docker exec rb1-optA-pg psql -U postgres -d image_env -tA -F ' ' -c 'SELECT count(*), max("MigrationId" COLLATE "C") FROM "__EFMigrationsHistory"')"
docker run --rm --network rb1-optA-net -e ConnectionStrings__CatalogConnection="Host=rb1-optA-pg;Username=postgres;Database=image_env" rb1-opta-migrations:test > "$out/run2.log" 2>&1; echo "second run exit $?: $(grep -c Applying "$out/run2.log") Applying lines"
docker rm -f rb1-optA-pg > /dev/null; docker network rm rb1-optA-net > /dev/null; echo "rb1-optA-pg and rb1-optA-net removed"
echo "== done $(date +%H:%M:%S)"
