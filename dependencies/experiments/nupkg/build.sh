#!/usr/bin/env bash
# One build of one package for the nupkg test.
#
# Usage: build.sh RECIPE DIR
#   RECIPE  a file that sets REPO, COMMIT, SDK_DIR, BUILD (the build commands,
#           run by bash in the clone), and optionally VARS (extra environment
#           as NAME=VALUE words), GIT_CONFIG (NAME=VALUE words written into the
#           clone's config before checkout, such as core.autocrlf=true) and
#           DEPTH (fetch only the commit, with this depth, as actions/checkout
#           does; without it the whole repository is cloned).
#   DIR     a new directory. The build gets DIR/src (the clone), DIR/home (a
#           throwaway HOME), DIR/nuget (an empty package cache) and DIR/logs.
#
# Everything runs under env -i with only HOME, PATH, LANG, NUGET_PACKAGES,
# DOTNET_CLI_TELEMETRY_OPTOUT, DOTNET_NOLOGO and the recipe's VARS. PATH holds
# the SDK directory first and /usr/bin. Build servers are shut down before and
# after, so a second build cannot reuse the first one's compiler server.
#
# Written 21 October 2026 for the nupkg pilot.
set -euo pipefail
recipe=$(realpath "$1"); dir=$2
[ ! -e "$dir" ] || { echo "$dir exists" >&2; exit 1; }
# shellcheck source=/dev/null
. "$recipe"
VARS=${VARS:-}; GIT_CONFIG=${GIT_CONFIG:-}
mkdir -p "$dir"/{home,nuget,logs}
dir=$(realpath "$dir")

run() {   # run CMD... in the build's environment
  # shellcheck disable=SC2086
  env -i HOME="$dir/home" PATH="$SDK_DIR:/usr/bin" LANG=C.UTF-8 \
    NUGET_PACKAGES="$dir/nuget" DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 \
    $VARS "$@"
}
stamp() { date -Is; }

{
  echo "start $(stamp)"
  echo "recipe: $1"; cat "$recipe"
  echo "--- environment"; run env | sort
  echo "--- git config"; run git config --list --show-origin || true
} > "$dir/logs/build.log" 2>&1

{
  echo "--- toolchain"
  run dotnet --info
  csc=$(ls "$SDK_DIR"/sdk/*/Roslyn/bincore/csc.dll)
  echo "csc.dll sha256 $(sha256sum "$csc" | cut -c1-64) ($csc)"
  echo "--- clone $(stamp)"
  if [ -n "${DEPTH:-}" ]; then
    run git init -q "$dir/src"
    run git -C "$dir/src" remote add origin "$REPO"
    run git -C "$dir/src" fetch -q --depth "$DEPTH" origin "$COMMIT"
    ref=FETCH_HEAD
  else
    run git clone -q --no-checkout "$REPO" "$dir/src"
    ref=$COMMIT
  fi
  for c in $GIT_CONFIG; do run git -C "$dir/src" config "${c%%=*}" "${c#*=}"; done
  run git -C "$dir/src" -c advice.detachedHead=false checkout -q "$ref"
  echo "HEAD: $(run git -C "$dir/src" rev-parse HEAD)"
  echo "tags at HEAD: $(run git -C "$dir/src" tag --points-at HEAD | tr '\n' ' ')"
  echo "short hash: $(run git -C "$dir/src" rev-parse --short HEAD)"
  echo "--- build $(stamp)"
  (cd "$dir/src" && run dotnet build-server shutdown >/dev/null 2>&1 || true)
  (cd "$dir/src" && run bash -c "$BUILD")
  (cd "$dir/src" && run dotnet build-server shutdown >/dev/null 2>&1 || true)
  echo "end $(stamp)"
} >> "$dir/logs/build.log" 2>&1 || { echo "FAILED, see $dir/logs/build.log"; tail -20 "$dir/logs/build.log"; exit 1; }
echo "ok: $dir ($(head -1 "$dir/logs/build.log") -> $(tail -1 "$dir/logs/build.log"))"
