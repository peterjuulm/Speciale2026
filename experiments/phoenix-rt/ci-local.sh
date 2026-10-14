#!/bin/bash
# The release workflow's jobs rebuilt here, to compare with a CI run
# (written 13 October 2026).
#
#   OUT=<private folder> [REPO=<repository>] ci-local.sh TAG [JOBS]
#
# TAG is a tag in REPO (default: the WS worktree); each job gets its own
# shallow clone of it
# in /private/tmp/rb1-ci/<job>, with origin set to the URL actions/checkout
# gives the jobs, so Source Link and the SDK see what they see in CI: the
# commit (SourceRevisionId) and the repository's URL. Then, as the jobs do:
#
#   frontend   npm ci and npm run build with APP_VERSION=TAG (no lint, no
#              locale), from the offline npm cache, Node 22.23.3
#   linux      publish-linux: the export copied in, the locked restore, both
#              publishes, both zips with the commit's pack-release-zip.sh;
#              LC_ALL=C.UTF-8 as the job sets it
#   windows    the reusable Windows job without signing: the export, the
#              locked restore, three win-x64 publishes, the migrator copy,
#              both zips; no locale, as the job sets none
#   migrator   migration-bundles: the locked restore and the linux-x64
#              migrator; LC_ALL=C.UTF-8. Not the smoke test
#   sql        migration-bundles' idempotent SQL script: the locked restore,
#              dotnet tool restore, dotnet ef migrations script (added
#              14 October)
#   images     the images from a clone plus the export, with
#              SOURCE_DATE_EPOCH in buildx's environment and
#              rewrite-timestamp=true on the OCI exporter, as in the dry run's
#              docker-images job; no provenance or SBOM. The two .NET images,
#              and since 14 October the three MCP images, each from its own
#              context as the job builds them
#
# JOBS defaults to all six, in that order; frontend runs first because the
# others take its export. Every .NET job gets GITHUB_ACTIONS=true (the locked
# restore in Directory.Build.props) and APP_VERSION=TAG, the SDK in
# DOTNET_DIR, the NuGet cache in /tmp/dch, HOME there too, so no user
# secrets. The images job needs DOCKER_CONFIG with buildx and the builder
# rb1. Outputs land in $OUT/local/.
#
# Changed 14 October, evening: the script exits 1 when any job fails, and
# a failed image build now fails the images job (the loop's break used to
# report exit 0). The frontend job removes the previous export before it
# builds, so a failed build cannot leave an older export for the jobs after
# it; jobs run without frontend still reuse the export that is there.
set -u
OUT=${OUT:?set OUT to a private data folder}
TAG=${1:?TAG} JOBS=${2:-frontend linux windows migrator sql images}
repo=${REPO:-/home/leos/Dev/Weel-Sandvig/WS.Phoenix-repro}
url=https://github.com/Weel-Sandvig/WS.Phoenix
ci=/private/tmp/rb1-ci
DN=${DOTNET_DIR:-/private/tmp/rb1-dotnet10/sdk} NODE=${NODE_DIR:-/private/tmp/rb1-node22}
L=$OUT/local; mkdir -p "$L" "$ci"
base=(env -i HOME=/tmp/dch USER="$USER" LOGNAME="$LOGNAME" SHELL=/bin/bash PATH=/usr/local/bin:/usr/bin)
net=("${base[@]}" DOTNET_ROOT="$DN" PATH="$DN:/usr/local/bin:/usr/bin" DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1
     MSBUILDDISABLENODEREUSE=1 GITHUB_ACTIONS=true APP_VERSION="$TAG")

clone() {  # a fresh shallow clone of TAG for one job, as actions/checkout makes it
  rm -rf "${ci:?}/$1"
  git clone -q --depth 1 --branch "$TAG" "file://$repo" "$ci/$1" 2> /dev/null && git -C "$ci/$1" remote set-url origin "$url"
}
export_in() { rm -rf "$ci/$1/src/WebAPI/ClientApp/out" && cp -r "$L/frontend-out" "$ci/$1/src/WebAPI/ClientApp/out"; }
epoch() { git -C "$ci/$1" log -1 --format=%ct; }
build_images() {  # the images job's builds, one per image; stops at the first failure
  local img ctx file name extra version
  for img in ${IMAGES:-webapi worker mcp chat broker}; do
    ctx=$ci/images version=(--build-arg "APP_VERSION=$TAG")
    case $img in
      webapi) file=src/WebAPI/Dockerfile; extra=("${version[@]}" --build-arg SKIP_SPA_BUILD=true); name=ws-pems ;;
      worker) file=src/BackgroundJobExecutor/Dockerfile; extra=("${version[@]}"); name=ws-pems-job-worker ;;
      mcp) file=mcp/Dockerfile; ctx=$ci/images/mcp; extra=(); name=wspems-mcp-server ;;
      chat) file=mcp/chat-server/Dockerfile; ctx=$ci/images/mcp; extra=(); name=wspems-chat-server ;;
      broker) file=mcp/auth-broker/Dockerfile; ctx=$ci/images/mcp/auth-broker; extra=(); name=wspems-mcp-auth-broker ;;
      *) echo "unknown image $img"; return 2 ;;
    esac
    env SOURCE_DATE_EPOCH="$(epoch images)" docker buildx build --builder rb1 --no-cache --provenance=false \
      -f "$ci/images/$file" "${extra[@]}" \
      --output "type=oci,dest=$L/images/$name.oci.tar,rewrite-timestamp=true" "$ctx" > "$L/images/$name.log" 2>&1 \
      || { echo "image $name failed, see $L/images/$name.log"; return 1; }
  done
}
pack() {  # job folder, release dir, zip suffix dirs...: the job's packing step
  local j=$1 dir=$2; shift 2
  ( cd "$ci/$j/$dir" && for d in "$@"; do
      env PATH=/private/tmp/rb1-tools:/usr/bin SOURCE_DATE_EPOCH="$(epoch "$j")" "$ci/$j/scripts/pack-release-zip.sh" "$d" "$ci/$j/release/$d-$TAG.zip" || exit 1
    done )
}

failed=
for job in $JOBS; do
  echo "$job start $(date +%T)"
  case $job in
    frontend)
      rm -rf "$L/frontend-out" && clone frontend && ( cd "$ci/frontend/src/WebAPI/ClientApp" && "${base[@]}" PATH="$NODE/bin:/usr/bin" CI=true \
          npm_config_cache=/private/tmp/rb1-npm npm_config_update_notifier=false NEXT_TELEMETRY_DISABLED=1 APP_VERSION="$TAG" \
          sh -c 'npm ci --offline --no-audit --no-fund && npm run build' ) > "$L/frontend.log" 2>&1 \
        && cp -r "$ci/frontend/src/WebAPI/ClientApp/out" "$L/frontend-out" ;;
    linux)
      clone linux && export_in linux && ( cd "$ci/linux" \
        && "${net[@]}" LC_ALL=C.UTF-8 dotnet restore ./WS.Phoenix.sln \
        && "${net[@]}" LC_ALL=C.UTF-8 dotnet publish ./src/WebAPI/WebAPI.csproj -c Release -o ./release/ws-pems-linux-x64 -r linux-x64 --self-contained true --no-restore /p:SkipSpaBuild=true \
        && "${net[@]}" LC_ALL=C.UTF-8 dotnet publish ./src/BackgroundJobExecutor/BackgroundJobExecutor.csproj -c Release -o ./release/ws-pems-job-worker-linux-x64 -r linux-x64 --self-contained true --no-restore ) > "$L/linux.log" 2>&1 \
        && pack linux release ws-pems-linux-x64 ws-pems-job-worker-linux-x64 >> "$L/linux.log" 2>&1 \
        && mkdir -p "$L/linux" && cp "$ci/linux/release/"*.zip "$L/linux/" ;;
    windows)
      clone windows && export_in windows && ( cd "$ci/windows" \
        && "${net[@]}" dotnet restore ./WS.Phoenix.sln \
        && "${net[@]}" dotnet publish src/WebAPI/WebAPI.csproj --configuration Release --output release/win/ws-pems-win-x64 --runtime win-x64 --self-contained true --no-restore -p:SkipSpaBuild=true \
        && "${net[@]}" dotnet publish src/BackgroundJobExecutor/BackgroundJobExecutor.csproj --configuration Release --output release/win/ws-pems-job-worker-win-x64 --runtime win-x64 --self-contained true --no-restore \
        && "${net[@]}" dotnet publish src/DbMigrator/DbMigrator.csproj --configuration Release --output publish/migrator-win --runtime win-x64 --self-contained true --no-restore \
        && cp publish/migrator-win/ws-pems-db-migrator.exe "release/win/ws-pems-db-migrator-win-x64-$TAG.exe" ) > "$L/windows.log" 2>&1 \
        && pack windows release/win ws-pems-win-x64 ws-pems-job-worker-win-x64 >> "$L/windows.log" 2>&1 \
        && mkdir -p "$L/windows" && cp "$ci/windows/release/"*.zip "$ci/windows/release/win/"*.exe "$L/windows/" ;;
    migrator)
      clone migrator && ( cd "$ci/migrator" \
        && "${net[@]}" LC_ALL=C.UTF-8 dotnet restore ./WS.Phoenix.sln \
        && "${net[@]}" LC_ALL=C.UTF-8 dotnet publish ./src/DbMigrator/DbMigrator.csproj -c Release -o ./publish/migrator -r linux-x64 --self-contained true --no-restore ) > "$L/migrator.log" 2>&1 \
        && mkdir -p "$L/migrator" && cp "$ci/migrator/publish/migrator/ws-pems-db-migrator" "$L/migrator/ws-pems-db-migrator-linux-x64-$TAG" ;;
    sql)
      clone sql && ( cd "$ci/sql" \
        && "${net[@]}" LC_ALL=C.UTF-8 dotnet restore ./WS.Phoenix.sln \
        && "${net[@]}" LC_ALL=C.UTF-8 dotnet tool restore \
        && "${net[@]}" LC_ALL=C.UTF-8 dotnet ef migrations script --idempotent --configuration Release --context DatabaseContext \
             -p src/Infrastructure/Infrastructure.csproj -s src/WebAPI/WebAPI.csproj -o "bundles/bootstrap-postgresql-$TAG.sql" ) > "$L/sql.log" 2>&1 \
        && mkdir -p "$L/migrator" && cp "$ci/sql/bundles/bootstrap-postgresql-$TAG.sql" "$L/migrator/" ;;
    images)
      clone images && export_in images && mkdir -p "$L/images" && build_images ;;
    *) echo "unknown job $job"; exit 2 ;;
  esac
  rc=$?
  echo "$job exit $rc $(date +%T)"
  [ "$rc" -eq 0 ] || failed="$failed $job"
done
if [ -n "$failed" ]; then
  echo "failed:$failed"
  exit 1
fi
