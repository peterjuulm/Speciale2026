#!/bin/bash
# Tests of ci-compare.sh's verdicts and exit status (written 14 October 2026).
#
#   ci-compare-tests.sh
#
# Builds a small fake run, a dozen files in a temporary folder, and runs
# ci-compare.sh on it three times. Each case checks the exit status and the
# summary line:
#
#   1  every output the same                    exit 0, 0 differ or failed
#   2  one Linux zip changed in the rebuild      exit 1, 2 differ (the zip and
#                                                SHA256SUMS, which hashes it)
#   3  CI's SHA256SUMS in the old db/ form       exit 0: rewritten in that form
#
# SIGNED=none, so no signing image is needed; the stand-in clone holds only
# scripts/upgrade.sh, the one file ci-compare.sh reads from it then. No image
# artifacts, so all five images are "not in this run". Exits 1 if a case fails.
set -u
here=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
mkdir -p "$T/clone/scripts" && printf '#!/bin/sh\necho upgrade\n' > "$T/clone/scripts/upgrade.sh"

python3 - "$T/run" "$T/clone/scripts/upgrade.sh" <<'PY'
import hashlib, os, sys, zipfile
P, upgrade = sys.argv[1], sys.argv[2]
tag = "vT"
def put(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "wb").write(data)
def pack(path, name):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with zipfile.ZipFile(path, "w") as z:
        z.writestr(zipfile.ZipInfo(f"{name}/a.txt", (2026, 10, 14, 0, 0, 0)), f"{name}\n")
put(f"{P}/ci/frontend-export/index.html", b"<html></html>\n")
put(f"{P}/local/frontend-out/index.html", b"<html></html>\n")
for os_, z in (("linux", "ws-pems-linux-x64"), ("linux", "ws-pems-job-worker-linux-x64"),
               ("windows", "ws-pems-win-x64"), ("windows", "ws-pems-job-worker-win-x64")):
    pack(f"{P}/ci/release-zips-{os_}/{z}-{tag}.zip", z)
    pack(f"{P}/local/{os_}/{z}-{tag}.zip", z)
win = f"ws-pems-db-migrator-win-x64-{tag}.exe"
put(f"{P}/ci/db-migration-bundles-windows/{win}", b"MZ\n")
put(f"{P}/local/windows/{win}", b"MZ\n")
for n, data in ((f"ws-pems-db-migrator-linux-x64-{tag}", b"ELF\n"), (f"bootstrap-postgresql-{tag}.sql", b"-- sql\n")):
    put(f"{P}/ci/db-migration-bundles-linux/{n}", data)
    put(f"{P}/local/migrator/{n}", data)
def line(path, name):
    return f"{hashlib.sha256(open(path, 'rb').read()).hexdigest()}  {name}\n"
zips = [f"{P}/ci/release-zips-linux/ws-pems-job-worker-linux-x64-{tag}.zip",
        f"{P}/ci/release-zips-windows/ws-pems-job-worker-win-x64-{tag}.zip",
        f"{P}/ci/release-zips-linux/ws-pems-linux-x64-{tag}.zip",
        f"{P}/ci/release-zips-windows/ws-pems-win-x64-{tag}.zip"]
db = [f"{P}/ci/db-migration-bundles-linux/bootstrap-postgresql-{tag}.sql",
      f"{P}/ci/db-migration-bundles-linux/ws-pems-db-migrator-linux-x64-{tag}",
      f"{P}/ci/db-migration-bundles-windows/{win}"]
new = [line(f, os.path.basename(f)) for f in zips] + [line(upgrade, "upgrade.sh")] + [line(f, os.path.basename(f)) for f in db]
old = [line(f, os.path.basename(f)) for f in zips] + [line(f, "db/" + os.path.basename(f)) for f in db] + [line(upgrade, "upgrade.sh")]
put(f"{P}/ci/sha256sums/SHA256SUMS", "".join(new).encode())
put(f"{P}/old-SHA256SUMS", "".join(old).encode())
PY

fail=0
check() {  # case, expected exit status, expected summary
  local rc
  SIGNED=none CLONE="$T/clone" bash "$here/ci-compare.sh" "$T/run" vT > "$T/out-$1.txt" 2>&1
  rc=$?
  if [ "$rc" -eq "$2" ] && grep -qx "summary: $3" "$T/out-$1.txt"; then
    echo "PASS  case $1: exit $rc, $3"
  else
    echo "FAIL  case $1: exit $rc (expected $2), $(grep '^summary' "$T/out-$1.txt")"; fail=1
  fi
}
check 1 0 "0 differ or failed, 5 not in this run"

cp "$T/run/local/linux/ws-pems-linux-x64-vT.zip" "$T/saved.zip"
python3 -c "import sys, zipfile; z = zipfile.ZipFile(sys.argv[1], 'a'); z.writestr('ws-pems-linux-x64/b.txt', 'extra'); z.close()" \
  "$T/run/local/linux/ws-pems-linux-x64-vT.zip"
check 2 1 "2 differ or failed, 5 not in this run"
cp "$T/saved.zip" "$T/run/local/linux/ws-pems-linux-x64-vT.zip"

cp "$T/run/old-SHA256SUMS" "$T/run/ci/sha256sums/SHA256SUMS"
check 3 0 "0 differ or failed, 5 not in this run"
exit $fail
