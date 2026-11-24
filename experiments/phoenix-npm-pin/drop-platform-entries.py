"""drop-platform-entries.py LOCK

Removes from a package-lock.json (v3) every entry whose package names an
os or cpu, the platform packages, so that the next `npm install
--package-lock-only` resolves them again from the registry and writes them
as that npm writes a fresh entry, libc included. Their parents name them
with exact versions, so the versions cannot move; compare-locks.py checks
that afterwards. Prints the removed entries.

Written 23 November 2026 for the npm pin (E1-S3-08).
"""
import json
import sys

path = sys.argv[1]
with open(path) as f:
    lock = json.load(f)
packages = lock["packages"]
drop = [k for k, v in packages.items() if k and ("os" in v or "cpu" in v)]
for k in drop:
    print(k, packages[k]["version"])
    del packages[k]
with open(path, "w") as f:
    json.dump(lock, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"removed {len(drop)} entries", file=sys.stderr)
