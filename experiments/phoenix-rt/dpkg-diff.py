#!/usr/bin/env python3
"""The Debian package versions in one layer of two OCI files (23 November 2026).

    dpkg-diff.py A.oci.tar A-LAYER-DIGEST B.oci.tar B-LAYER-DIGEST

Reads var/lib/dpkg/status from each layer and prints every package whose
version differs, or that only one side has.
"""
import gzip, io, sys, tarfile

def status(path, d):
    t = tarfile.open(path)
    lay = tarfile.open(fileobj=io.BytesIO(gzip.decompress(t.extractfile("blobs/sha256/" + d).read())))
    txt = lay.extractfile("var/lib/dpkg/status").read().decode()
    pk = {}
    for block in txt.strip().split("\n\n"):
        f = dict(l.split(": ", 1) for l in block.splitlines() if ": " in l and not l.startswith(" "))
        pk[f["Package"] + ":" + f.get("Architecture", "")] = f.get("Version")
    return pk

a, b = status(sys.argv[1], sys.argv[2]), status(sys.argv[3], sys.argv[4])
print(f"packages: A {len(a)}, B {len(b)}")
for k in sorted(set(a) | set(b)):
    if a.get(k) != b.get(k):
        print(f"  {k}: {a.get(k)} -> {b.get(k)}")
