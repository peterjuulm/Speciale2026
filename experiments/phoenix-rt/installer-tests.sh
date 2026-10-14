#!/usr/bin/env bash
# install-dotnet-sdk.py and the setup-dotnet-sdk action after the cache
# changes (14 Oct): the cache only on a self-hosted runner, pruned after 30
# days, downloads in the job's temporary folder.
set -uo pipefail
W=/home/leos/Dev/Weel-Sandvig/WS.Phoenix-repro
X=/private/tmp/rb1-sdk-tests-2
LOG=/home/leos/Dev/speciale-2026/data/phoenix-fixes/2026-10-14/installer-tests-2.txt
rm -rf "$X" && mkdir -p "$X/tmp" "$X/cache"
: > "$LOG"
say() { echo "$*" | tee -a "$LOG"; }
install() { TMPDIR=$X/tmp python3 "$W/scripts/install-dotnet-sdk.py" --global-json "$W/global.json" "$@"; }
entries() { (cd "$X/cache" && ls -1 | sed 's/^\(.\{16\}\)[^.]*/\1../' | tr '\n' ' '); }
runtimes() { "$1/dotnet" --list-runtimes | awk '{ print $1, $2 }' | tr '\n' ' '; }

say "$(date +%T) installer at $(git -C "$W" rev-parse --short HEAD) + worktree changes, sha256 $(sha256sum "$W/scripts/install-dotnet-sdk.py" | cut -c1-16)"

say "== I1 no cache"
install "$X/i1" | sed -n 2p | tee -a "$LOG"
say "exit ${PIPESTATUS[0]}; runtimes: $(runtimes "$X/i1"); left in TMPDIR: $(ls -A "$X/tmp" | wc -l)"
rm -rf "$X/i1"

say "== I2 empty cache: downloaded, then kept"
install --cache "$X/cache" "$X/i2" | sed -n 2p | tee -a "$LOG"
say "exit ${PIPESTATUS[0]}; cache: $(entries)"
entry=$(ls "$X/cache"/*.tar.gz)
rm -rf "$X/i2"

say "== I3 cache hit; the entry's time refreshed"
touch -d '10 days ago' "$entry"
install --cache "$X/cache" "$X/i3" | sed -n 2p | tee -a "$LOG"
say "exit ${PIPESTATUS[0]}; entry age now $(( $(date +%s) - $(stat -c %Y "$entry") )) s; runtimes: $(runtimes "$X/i3")"
rm -rf "$X/i3"

say "== I4 a corrupt entry is downloaded again and replaced"
python3 -c "p='$entry'; d=bytearray(open(p,'rb').read()); d[len(d)//2]^=1; open(p,'wb').write(d)"
install --cache "$X/cache" "$X/i4" | sed -n 2p | tee -a "$LOG"
say "exit ${PIPESTATUS[0]}; entry sha512 now $(sha512sum "$entry" | cut -c1-16), name $(basename "$entry" | cut -c1-16)"
rm -rf "$X/i4"

say "== I5 pruning"
fake=$(printf 'a%.0s' $(seq 128))
older=$(printf 'b%.0s' $(seq 128))
touch -d '40 days ago' "$X/cache/$fake.tar.gz"
touch -d '20 days ago' "$X/cache/$older.zip"
touch -d '2 days ago' "$X/cache/$fake.tar.gz.4242.partial"
touch -d '1 hour ago' "$X/cache/$older.zip.4343.partial"
touch -d '40 days ago' "$X/cache/notes.txt"
say "before: $(entries)"
install --cache "$X/cache" "$X/i5" | sed -n 2p | tee -a "$LOG"
say "exit ${PIPESTATUS[0]}; after: $(entries)"
rm -rf "$X/i5"

# The action's install step, as the runner runs it: bash -e -o pipefail.
python3 - "$W/.github/actions/setup-dotnet-sdk/action.yml" > "$X/step.sh" <<'EOF'
import sys
lines = open(sys.argv[1]).read().split("\n")
i = lines.index("      run: |") + 1
out = []
while i < len(lines) and (lines[i].startswith("        ") or not lines[i].strip()):
    out.append(lines[i][8:])
    i += 1
print("\n".join(out).rstrip())
EOF
for kind in github-hosted self-hosted; do
  say "== I6 the action's step on a $kind runner"
  R=$X/runner-$kind && mkdir -p "$R/temp" "$R/tool"
  env RUNNER_ENVIRONMENT=$kind RUNNER_TEMP=$R/temp RUNNER_TOOL_CACHE=$R/tool GITHUB_WORKSPACE=$W \
    GITHUB_STEP_SUMMARY=$R/summary GITHUB_ENV=$R/env GITHUB_PATH=$R/path \
    bash --noprofile --norc -e -o pipefail "$X/step.sh" > "$R/out" 2>&1
  say "exit $?; $(sed -n 2p "$R/out")"
  say "in RUNNER_TEMP: $(ls -A "$R/temp" | tr '\n' ' '); tool cache: $(ls -A "$R/tool" 2>/dev/null | tr '\n' ' ')$(ls "$R/tool"/dotnet-sdk-archives 2>/dev/null | cut -c1-16 | sed 's/^/ -> /' | tr '\n' ' ')"
  say "GITHUB_ENV: $(cat "$R/env")"
  rm -rf "$R/temp/dotnet-sdk"
done
say "$(date +%T) done"
