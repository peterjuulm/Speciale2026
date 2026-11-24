#!/usr/bin/env python3
"""List an OCI image tarball's layers, and the entries of the last few, 24 November 2026.

    oci-layers.py IMAGE.oci.tar [N]

Prints the linux/amd64 image manifest's digest, then one line per layer:
its index (1-based), digest and size. For the last N layers (default 1),
it also prints every tar entry: type, mode, uid:gid, mtime, size, name.
An index is followed to its linux/amd64 image; attestation manifests are
skipped. Layers are read as gzip or plain tar. Written for
rosetta-cache-layer, to see which folders a RUN step's layer holds.
"""
import gzip
import io
import json
import sys
import tarfile

IMAGE = ("application/vnd.oci.image.manifest.v1+json",
         "application/vnd.docker.distribution.manifest.v2+json")
INDEX = ("application/vnd.oci.image.index.v1+json",
         "application/vnd.docker.distribution.manifest.list.v2+json")


def main():
    path = sys.argv[1]
    last = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    t = tarfile.open(path)

    def blob(d):
        a, h = d.split(":", 1)
        return t.extractfile(f"blobs/{a}/{h}").read()

    desc = json.load(t.extractfile("index.json"))["manifests"][0]
    while desc["mediaType"] in INDEX:
        idx = json.loads(blob(desc["digest"]))
        cands = [m for m in idx["manifests"]
                 if m["mediaType"] in IMAGE + INDEX
                 and m.get("platform", {}).get("architecture") in ("amd64", None)
                 and m.get("annotations", {}).get("vnd.docker.reference.type") != "attestation-manifest"]
        desc = cands[0]
    man = json.loads(blob(desc["digest"]))
    print("manifest", desc["digest"])
    print("config  ", man["config"]["digest"])
    layers = man["layers"]
    for i, l in enumerate(layers, 1):
        print(f"layer {i:2} {l['digest']} {l['size']}")
    for i, l in enumerate(layers, 1):
        if i <= len(layers) - last:
            continue
        data = blob(l["digest"])
        if data[:2] == b"\x1f\x8b":
            data = gzip.decompress(data)
        print(f"-- entries of layer {i}")
        with tarfile.open(fileobj=io.BytesIO(data)) as lt:
            for m in lt.getmembers():
                kind = "d" if m.isdir() else "l" if m.issym() else "h" if m.islnk() else "f"
                print(f"   {kind} {m.mode:04o} {m.uid}:{m.gid} {m.mtime} {m.size:>8} {m.name}")


if __name__ == "__main__":
    main()
