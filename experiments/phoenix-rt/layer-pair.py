#!/usr/bin/env python3
"""Every entry that differs between two image layer blobs, gzip or plain tar
(written 24 November 2026, for phoenix-arch-rebuild: arch's apt layers of
the MCP images against macstudio's of 23/11).

    layer-pair.py A.layer B.layer

Compares type, mode, owner, mtime, size and content (or link target) per
entry name, and whether the entries both have come in the same order.
"""
import gzip, hashlib, io, sys, tarfile
def entries(p):
    raw = open(p, 'rb').read()
    if raw[:2] == b'\x1f\x8b': raw = gzip.decompress(raw)
    t = tarfile.open(fileobj=io.BytesIO(raw)); out = {}; order = []
    for m in t:
        h = hashlib.sha256(t.extractfile(m).read()).hexdigest() if m.isfile() else m.linkname
        out[m.name] = (m.type, oct(m.mode), m.uid, m.gid, m.mtime, m.size, h); order.append(m.name)
    return out, order
a, oa = entries(sys.argv[1]); b, ob = entries(sys.argv[2])
print(f"entries: A {len(a)}, B {len(b)}")
for k in sorted(set(a) | set(b)):
    if a.get(k) != b.get(k): print(f"  {k}: {a.get(k)} -> {b.get(k)}")
common = [x for x in oa if x in b]; print("order of common entries the same:", common == [x for x in ob if x in a])
