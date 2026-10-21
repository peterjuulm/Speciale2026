#!/usr/bin/env bash
# install-dotnet-sdk.py with the archive lock (21 October 2026): it installs
# from dotnet-sdk.lock.json alone, offline from its cache, and stops on a
# lock that does not fit. Then the setup-dotnet-sdk action's step as a
# runner runs it, and the unpacking on a Python without tarfile's data
# filter (L7, added after the dev container's test failed on it).
#   W=<WS checkout> LOG=<file> installer-lock-tests.sh
set -uo pipefail
W=${W:?the WS checkout} LOG=${LOG:?a log file}
X=/private/tmp/rb1-sdk-tests-3
rm -rf "$X" && mkdir -p "$X/tmp" "$X/cache" "$X/gj"
: > "$LOG"
say() { echo "$*" | tee -a "$LOG"; }
install() { TMPDIR=$X/tmp python3 "$W/scripts/install-dotnet-sdk.py" "$@"; }
offline() { TMPDIR=$X/tmp unshare -rn python3 "$W/scripts/install-dotnet-sdk.py" "$@"; }
runtimes() { "$1/dotnet" --list-runtimes | awk '{ print $1, $2 }' | tr '\n' ' '; }
lock() {  # a copy of global.json beside a changed copy of the lock
  cp "$W/global.json" "$X/gj/global.json"
  python3 -c "import json, sys; d = json.load(open(sys.argv[1])); $1; json.dump(d, open(sys.argv[2], 'w'))" \
    "$W/dotnet-sdk.lock.json" "$X/gj/dotnet-sdk.lock.json"
}

say "$(date +%T) installer at $(git -C "$W" rev-parse --short HEAD), sha256 $(sha256sum "$W/scripts/install-dotnet-sdk.py" | cut -c1-16)"

say "== L1 --record writes the committed lock again"
cp "$W/global.json" "$X/gj/global.json"
install --record --global-json "$X/gj/global.json" | tee -a "$LOG"
say "exit ${PIPESTATUS[0]}; equal to the committed lock: $(cmp -s "$X/gj/dotnet-sdk.lock.json" "$W/dotnet-sdk.lock.json" && echo yes || echo NO)"

say "== L2 no cache: downloaded and checked"
install --global-json "$W/global.json" "$X/l2" | sed -n 2p | tee -a "$LOG"
say "exit ${PIPESTATUS[0]}; runtimes: $(runtimes "$X/l2")"
rm -rf "$X/l2"

say "== L3 an empty cache filled, then a cache hit without network"
install --global-json "$W/global.json" --cache "$X/cache" "$X/l3a" | sed -n 2p | tee -a "$LOG"
say "exit ${PIPESTATUS[0]}"
offline --global-json "$W/global.json" --cache "$X/cache" "$X/l3b" | sed -n 2p | tee -a "$LOG"
say "exit ${PIPESTATUS[0]}, offline; runtimes: $(runtimes "$X/l3b")"
offline --global-json "$W/global.json" "$X/l3c" 2>&1 | tail -1 | tee -a "$LOG"
say "exit ${PIPESTATUS[0]}, offline without the cache"
rm -rf "$X/l3a" "$X/l3b" "$X/l3c"

say "== L4 a corrupt cache entry is downloaded again"
entry=$(ls "$X/cache"/*.tar.gz)
python3 -c "p = '$entry'; d = bytearray(open(p, 'rb').read()); d[len(d) // 2] ^= 1; open(p, 'wb').write(d)"
install --global-json "$W/global.json" --cache "$X/cache" "$X/l4" | sed -n 2p | tee -a "$LOG"
say "exit ${PIPESTATUS[0]}; the entry's sha512 now $(sha512sum "$entry" | cut -c1-16), its name $(basename "$entry" | cut -c1-16)"
rm -rf "$X/l4"

say "== L5 a lock that does not fit"
lock 'd["version"] = "10.0.400"'
install --global-json "$X/gj/global.json" "$X/l5" 2>&1 | tail -1 | tee -a "$LOG"; say "another version: exit ${PIPESTATUS[0]}"
lock 'del d["archives"]["linux-x64"]'
install --global-json "$X/gj/global.json" "$X/l5" 2>&1 | tail -1 | tee -a "$LOG"; say "no linux-x64 archive: exit ${PIPESTATUS[0]}"
lock 'd["archives"]["linux-x64"]["sha512"] = "abc"'
install --global-json "$X/gj/global.json" "$X/l5" 2>&1 | tail -1 | tee -a "$LOG"; say "a malformed hash: exit ${PIPESTATUS[0]}"
lock 'd["archives"]["linux-x64"]["sha512"] = "0" * 128'
install --global-json "$X/gj/global.json" "$X/l5" 2>&1 | tail -1 | tee -a "$LOG"; say "another hash: exit ${PIPESTATUS[0]}"
lock 'd["runtime"] = "10.0.11"'
install --global-json "$X/gj/global.json" --cache "$X/cache" "$X/l5b" 2>&1 | tail -1 | tee -a "$LOG"; say "another runtime: exit ${PIPESTATUS[0]}"
rm -f "$X/gj/dotnet-sdk.lock.json"
install --global-json "$X/gj/global.json" "$X/l5c" 2>&1 | tail -1 | tee -a "$LOG"; say "no lock: exit ${PIPESTATUS[0]}"
rm -rf "$X/l5" "$X/l5b" "$X/l5c"

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
  say "== L6 the action's step on a $kind runner"
  R=$X/runner-$kind && mkdir -p "$R/temp" "$R/tool"
  env RUNNER_ENVIRONMENT=$kind RUNNER_TEMP=$R/temp RUNNER_TOOL_CACHE=$R/tool GITHUB_WORKSPACE=$W \
    GITHUB_STEP_SUMMARY=$R/summary GITHUB_ENV=$R/env GITHUB_PATH=$R/path \
    bash --noprofile --norc -e -o pipefail "$X/step.sh" > "$R/out" 2>&1
  say "exit $?; $(sed -n 2p "$R/out")"
  say "tool cache: $(ls "$R/tool"/dotnet-sdk-archives 2>/dev/null | cut -c1-16 | tr '\n' ' ')"
  rm -rf "$R/temp/dotnet-sdk"
done
# The fallback for a Python without tarfile's data filter, such as Debian
# bookworm's 3.11.2 in the dev container: the host's Python, with the
# installer given a tarfile module without the filter (Python's own
# extractall needs it from 3.14). The SDK from the cache, then small
# archives built here: one that is fine, and five that each lead out of
# the target or hold a special file.
say "== L7 a Python without tarfile's data filter"
python3 -I - "$W/scripts/install-dotnet-sdk.py" "$W/global.json" "$X" <<'EOF' 2>&1 | tee -a "$LOG"
import importlib.util, io, os, sys, tarfile, types
installer, global_json, x = sys.argv[1:4]
spec = importlib.util.spec_from_file_location("installer", installer)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.tarfile = types.SimpleNamespace(**{k: getattr(tarfile, k) for k in dir(tarfile) if k != "data_filter"})
os.environ["TMPDIR"] = f"{x}/tmp"
sys.argv = ["install-dotnet-sdk.py", "--global-json", global_json, "--cache", f"{x}/cache", f"{x}/l7"]
try:
    m.main()
    print("the SDK from the cache: installed, runtimes", sorted(os.listdir(f"{x}/l7/shared/Microsoft.NETCore.App")))
except SystemExit as e:
    print("the SDK from the cache: exit", e.code)
def archive(name, members):
    path = f"{x}/{name}.tar"
    with tarfile.open(path, "w") as t:
        for member_name, kind, link in members:
            info = tarfile.TarInfo(member_name)
            info.type, info.linkname = kind, link
            data = b"x" if kind == tarfile.REGTYPE else b""
            info.size = len(data)
            t.addfile(info, io.BytesIO(data))
    return path
D, F, S, H, P = tarfile.DIRTYPE, tarfile.REGTYPE, tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.FIFOTYPE
cases = {
    "fine": [(".", D, ""), ("./a", D, ""), ("./a/f", F, ""), ("./l", S, "a/f"), ("./h", H, "./a/f")],
    "up": [(".", D, ""), ("./../f", F, "")],
    "absolute": [("/tmp/rb1-l7-f", F, "")],
    "link-up": [(".", D, ""), ("./l", S, "../f")],
    "hard-link-up": [(".", D, ""), ("./h", H, "../f")],
    "fifo": [(".", D, ""), ("./p", P, "")],
}
for name, members in cases.items():
    target = f"{x}/l7-{name}"
    try:
        m.unpack(archive(name, members), target, False)
        print(f"{name}: unpacked", sorted(os.listdir(target)))
    except SystemExit as e:
        print(f"{name}: {e.code}")
EOF
rm -rf "$X/l7"
say "$(date +%T) done"
