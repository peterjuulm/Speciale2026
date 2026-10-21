#!/usr/bin/env bash
# verify-nuget-downloads.py (21 October 2026) on a restored clone, and on a
# copy of its assets files whose package folder holds copies of the
# packages, so the real NuGet cache is never changed: it passes as
# restored, and fails on a pack with another hash, a pack the lock does not
# name, and a tool with another hash.
#   W=<WS checkout> C=<restored clone, tools restored> SDK=<SDK folder>
#   HOME_USED=<CLI home of its restores> LOG=<file> nuget-check-tests.sh
set -uo pipefail
W=${W:?the WS checkout} C=${C:?a restored clone} LOG=${LOG:?a log file}
SDK=${SDK:?the SDK folder} HOME_USED=${HOME_USED:?the CLI home of the restores}
X=/private/tmp/rb1-nuget-tests
: > "$LOG"
say() { echo "$*" | tee -a "$LOG"; }
check() { local r=$1; shift; python3 "$W/scripts/verify-nuget-downloads.py" --root "$r" "$@" 2>&1; }
say "$(date +%T) check at $(git -C "$W" rev-parse --short HEAD), clone at $(git -C "$C" rev-parse --short HEAD)"

say "== N1 the clone as restored"
check "$C" | tee -a "$LOG"; say "exit ${PIPESTATUS[0]}"

# The copy: each assets file with its packagesPath moved to X/pkgs, the
# tools manifest, the lock, and each locked package's .nupkg copied.
python3 - "$W" "$C" "$X" <<'EOF'
import glob, json, os, shutil, sys
W, C, X = sys.argv[1:4]
shutil.rmtree(X, ignore_errors=True)
src = None
for a in glob.glob(f"{C}/src/*/obj/project.assets.json") + glob.glob(f"{C}/tests/*/obj/project.assets.json"):
    d = json.load(open(a, encoding="utf-8-sig"))
    src = d["project"]["restore"]["packagesPath"]
    d["project"]["restore"]["packagesPath"] = f"{X}/pkgs/"
    out = f"{X}/root/{os.path.relpath(a, C)}"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    json.dump(d, open(out, "w"))
os.makedirs(f"{X}/root/.config")
shutil.copy(f"{C}/.config/dotnet-tools.json", f"{X}/root/.config/")
shutil.copy(f"{W}/nuget-downloads.lock.json", f"{X}/root/")
for name, versions in json.load(open(f"{W}/nuget-downloads.lock.json")).items():
    for v in versions:
        n, v = name.lower(), v.lower()
        f = f"{src}/{n}/{v}/{n}.{v}.nupkg"
        if os.path.exists(f):
            os.makedirs(f"{X}/pkgs/{n}/{v}")
            shutil.copy(f, f"{X}/pkgs/{n}/{v}/")
print("copied from", src)
EOF
flip() { python3 -c "p = '$1'; d = bytearray(open(p, 'rb').read()); d[len(d) // 2] ^= 1; open(p, 'wb').write(d)"; }

say "== N2 the copy as is"
check "$X/root" | tail -1 | tee -a "$LOG"; say "exit ${PIPESTATUS[0]}"

say "== N3 a runtime pack with another hash"
p=$X/pkgs/microsoft.netcore.app.runtime.linux-x64/10.0.12/microsoft.netcore.app.runtime.linux-x64.10.0.12.nupkg
cp "$p" "$X/keep" && flip "$p"
check "$X/root" | grep -v '^ok' | tee -a "$LOG"; say "exit ${PIPESTATUS[0]}"
mv "$X/keep" "$p"

say "== N4 a pack the lock does not name"
cp "$X/root/nuget-downloads.lock.json" "$X/keep"
python3 -c "import json, sys; p = sys.argv[1]; d = json.load(open(p)); del d['Microsoft.NETCore.App.Host.win-x64']; json.dump(d, open(p, 'w'))" "$X/root/nuget-downloads.lock.json"
check "$X/root" | grep -v '^ok' | tee -a "$LOG"; say "exit ${PIPESTATUS[0]}"
mv "$X/keep" "$X/root/nuget-downloads.lock.json"

say "== N5 a tool with another hash"
p=$X/pkgs/dotnet-ef/10.0.12/dotnet-ef.10.0.12.nupkg
cp "$p" "$X/keep" && flip "$p"
check "$X/root" | grep -v '^ok' | tee -a "$LOG"; say "exit ${PIPESTATUS[0]}"
mv "$X/keep" "$p"

say "== N6 a tool not restored"
rm -rf "$X/pkgs/csharpier"
check "$X/root" | grep -v '^ok' | tee -a "$LOG"; say "exit ${PIPESTATUS[0]}"

say "== N7 --tools with a tool not restored"
check "$X/root" --tools | grep -v '^ok' | tee -a "$LOG"; say "exit ${PIPESTATUS[0]}"

say "== N8 a lock but no restore"
mkdir -p "$X/empty" && cp "$W/nuget-downloads.lock.json" "$X/empty/"
check "$X/empty" | tee -a "$LOG"; say "exit ${PIPESTATUS[0]}"

# Tool restore and the CLI's resolver cache: the tools manifest alone,
# restored into an empty package folder with the home of the earlier
# restores (whose cache points into their package folder), then with a new
# home. Where the package folder ends up, and where dotnet runs dotnet-ef.
say "== N9 tool restore with a used CLI home, then with a new one"
mkdir -p "$X/t/.config" && cp "$C/.config/dotnet-tools.json" "$X/t/.config/" && cp "$C/global.json" "$X/t/"
for h in used:$HOME_USED new:$X/home; do
  name=${h%%:*} home=${h#*:}
  rm -rf "$X/pk-$name" && mkdir -p "$X/pk-$name"
  (cd "$X/t" && env -i HOME=/tmp/dch PATH=$SDK:/usr/bin DOTNET_NOLOGO=1 DOTNET_CLI_HOME=$home NUGET_PACKAGES=$X/pk-$name \
     "$SDK/dotnet" tool restore > /dev/null 2>&1)
  say "$name home: restore exit $?, package folder: $(ls "$X/pk-$name" | tr '\n' ' ')"
  say "  dotnet-ef runs $(grep -o '"PathToExecutable":"[^"]*' "$home/.dotnet/toolResolverCache/1/dotnet-ef" | tail -1 | cut -d'"' -f4)"
done
rm -rf "$X"
say "$(date +%T) done"
