# Why does the verifier's Windows web.config lack the "<!--ProjectGuid: ...-->"
# line the release has? The WebAPI's win-x64 publish, as publish-windows.sh
# does it, in two fresh clones of the dry run's commit, with the verifier's
# SDK and package folder: once with GITHUB_ACTIONS=true (as CI and the
# experiment repo's rebuild.sh), once without (as rebuild.sh's env -i).
set -uo pipefail
V=/private/tmp/rb1-verify W=$V/guid; rm -rf "$W"; mkdir -p "$W"
c=$(git -C "$V/work1/jobs/windows" rev-parse HEAD)
for mode in ci plain; do
  d=$W/$mode; git clone -q --no-checkout "$V/work1/jobs/windows" "$d" && git -C "$d" checkout -q --detach "$c"
  cp -a "$V/work1/jobs/frontend/src/WebAPI/ClientApp/out" "$d/src/WebAPI/ClientApp/out"
  extra=(); [ $mode = ci ] && extra=(GITHUB_ACTIONS=true)
  (cd "$d" && /tmp/claude-1000/ws-mem-run.sh 12 env -i HOME="$W/home-$mode" PATH="$V/work1/dotnet:/usr/bin:/bin" DOTNET_ROOT="$V/work1/dotnet" DOTNET_CLI_HOME="$W/home-$mode" \
     NUGET_PACKAGES="$V/work1/nuget/packages" DOTNET_NOLOGO=1 MSBUILDDISABLENODEREUSE=1 LC_ALL=C.UTF-8 APP_VERSION=v0.0.0-dryrun.4 "${extra[@]}" \
     bash -c 'dotnet restore ./WS.Phoenix.sln --locked-mode > restore.log 2>&1 && dotnet publish src/WebAPI/WebAPI.csproj --configuration Release --output out-win --runtime win-x64 --self-contained true --no-restore -p:SkipSpaBuild=true > publish.log 2>&1; echo "exit $?"')
  printf '%s: ' $mode; tail -c 80 "$d/out-win/web.config" | tr '\n' ' '; echo
  grep -l -i "10FDF702" "$d"/src/WebAPI/obj/* 2>/dev/null | head -3
done
