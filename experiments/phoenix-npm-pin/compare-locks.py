"""compare-locks.py OLD NEW

Compares two package-lock.json files (v3) entry by entry: entries added or
removed, versions, resolved URLs and integrity hashes changed, and for
every other field the entries that gained, lost or changed it. Exits 1 if
an entry was added or removed, or a version, URL or hash changed.

Written 23 November 2026 for the npm pin (E1-S3-08).
"""
import json
import sys
from collections import Counter

old = json.load(open(sys.argv[1]))["packages"]
new = json.load(open(sys.argv[2]))["packages"]
added = sorted(set(new) - set(old))
removed = sorted(set(old) - set(new))
core = Counter()
fields = Counter()
for k in sorted(set(old) & set(new)):
    a, b = old[k], new[k]
    for f in ("version", "resolved", "integrity"):
        if a.get(f) != b.get(f):
            core[f] += 1
            print(f"  {f} changed: {k}: {a.get(f)} -> {b.get(f)}")
    for f in sorted((set(a) | set(b)) - {"version", "resolved", "integrity"}):
        if f not in a:
            fields[f"+{f}"] += 1
        elif f not in b:
            fields[f"-{f}"] += 1
        elif a[f] != b[f]:
            fields[f"~{f}"] += 1
print(f"entries: old {len(old)}, new {len(new)}, added {len(added)}, removed {len(removed)}")
for k in added:
    print(f"  added: {k} {new[k].get('version')}")
for k in removed:
    print(f"  removed: {k} {old[k].get('version')}")
print("version/resolved/integrity changed:", dict(core) or "none")
print("other fields (+gained -lost ~changed):", dict(fields) or "none")
sys.exit(1 if added or removed or core else 0)
