#!/usr/bin/env python3
"""Compare two OCI image tarballs (buildx --output type=oci), 13 October 2026.

    oci-diff.py A.oci.tar B.oci.tar

The first three lines say whether the image manifests, the image configs
and the layers are the same. Then, per difference: the config fields that
differ, and for each layer that differs, what differs among its entries
(content, mode, owner, time, order) with up to ten examples. An index that
holds several manifests is followed to its linux/amd64 image; attestation
manifests are skipped. Layers are read as gzip or plain tar.
"""
import gzip
import hashlib
import json
import sys
import tarfile

IMAGE = ("application/vnd.oci.image.manifest.v1+json",
         "application/vnd.docker.distribution.manifest.v2+json")
INDEX = ("application/vnd.oci.image.index.v1+json",
         "application/vnd.docker.distribution.manifest.list.v2+json")


class Layout:
    def __init__(self, path):
        self.tar = tarfile.open(path)
        self.names = set(self.tar.getnames())

    def blob(self, digest):
        algo, hexd = digest.split(":", 1)
        return self.tar.extractfile(f"blobs/{algo}/{hexd}")

    def json(self, digest):
        return json.load(self.blob(digest))

    def image(self):
        """The index.json digest, the image manifest's descriptor and the manifest."""
        raw = self.tar.extractfile("index.json").read()
        desc = pick(json.loads(raw)["manifests"])
        while desc["mediaType"] in INDEX:
            desc = pick(self.json(desc["digest"])["manifests"])
        if desc["mediaType"] not in IMAGE:
            sys.exit(f"unexpected media type {desc['mediaType']}")
        return "sha256:" + hashlib.sha256(raw).hexdigest(), desc, self.json(desc["digest"])


def pick(manifests):
    images = [m for m in manifests
              if m.get("annotations", {}).get("vnd.docker.reference.type") != "attestation-manifest"]
    amd64 = [m for m in images if m.get("platform", {}).get("architecture") in (None, "amd64")]
    if len(amd64) != 1:
        sys.exit(f"expected one linux/amd64 image, found {len(amd64)}")
    return amd64[0]


def entries(layout, desc):
    """name -> fields, and the names in archive order, for one layer blob."""
    f = layout.blob(desc["digest"])
    if desc["mediaType"].endswith("gzip"):
        f = gzip.GzipFile(fileobj=f)
    elif not desc["mediaType"].endswith("tar"):
        sys.exit(f"cannot read layer type {desc['mediaType']}")
    out, order = {}, []
    with tarfile.open(fileobj=f, mode="r|") as t:
        for m in t:
            h = ""
            if m.isreg():
                h = hashlib.sha256(t.extractfile(m).read()).hexdigest()[:16]
            out[m.name] = {"type": m.type.decode(), "mode": oct(m.mode), "owner": f"{m.uid}:{m.gid}",
                           "mtime": m.mtime, "size": m.size, "link": m.linkname, "content": h,
                           "pax": {k: v for k, v in sorted(m.pax_headers.items()) if k != "path"}}
            order.append(m.name)
    return out, order


def config_diff(a, b, prefix=""):
    if isinstance(a, dict) and isinstance(b, dict):
        out = []
        for k in sorted(set(a) | set(b)):
            out += config_diff(a.get(k), b.get(k), f"{prefix}.{k}" if prefix else k)
        return out
    if isinstance(a, list) and isinstance(b, list) and len(a) == len(b):
        out = []
        for i, (x, y) in enumerate(zip(a, b)):
            out += config_diff(x, y, f"{prefix}[{i}]")
        return out
    return [] if a == b else [(prefix, a, b)]


def main(pa, pb):
    A, B = Layout(pa), Layout(pb)
    ia, da, ma = A.image()
    ib, db, mb = B.image()
    same = da["digest"] == db["digest"]
    print(f"manifest {'same' if same else 'differ'}: {da['digest']}"
          + ("" if same else f" / {db['digest']}"))
    ca, cb = A.json(ma["config"]["digest"]), B.json(mb["config"]["digest"])
    cdiff = config_diff(ca, cb)
    print("config same" if not cdiff else
          "config differ: " + ", ".join(p for p, _, _ in cdiff[:12]) + (" ..." if len(cdiff) > 12 else ""))
    la, lb = ma["layers"], mb["layers"]
    if len(la) != len(lb):
        print(f"layers differ in number: {len(la)} / {len(lb)}")
        return
    diff = [i for i, (x, y) in enumerate(zip(la, lb)) if x["digest"] != y["digest"]]
    print(f"layers {len(la)}: same {[i for i in range(len(la)) if i not in diff]}, differ {diff}")
    if ia == ib:
        print("index.json same")
    else:
        print("index.json differs")
        for p, x, y in config_diff(json.load(A.tar.extractfile("index.json")),
                                   json.load(B.tar.extractfile("index.json"))):
            print(f"  index {p}: {x} / {y}")
    for p, x, y in cdiff:
        print(f"  config {p}: {x} / {y}")
    for i in diff:
        dida, didb = ca["rootfs"]["diff_ids"][i], cb["rootfs"]["diff_ids"][i]
        print(f"layer {i}: {la[i]['digest']} / {lb[i]['digest']}, "
              f"uncompressed {'same' if dida == didb else 'differs'}, size {la[i]['size']} / {lb[i]['size']}")
        if dida == didb:
            continue
        ea, oa = entries(A, la[i])
        eb, ob = entries(B, lb[i])
        only_a, only_b = sorted(set(ea) - set(eb)), sorted(set(eb) - set(ea))
        kinds, examples = {}, {}
        for n in sorted(set(ea) & set(eb)):
            fields = tuple(k for k in ea[n] if ea[n][k] != eb[n][k])
            if fields:
                kinds[fields] = kinds.get(fields, 0) + 1
                examples.setdefault(fields, []).append(n)
        print(f"  {len(ea)} / {len(eb)} entries, only in A {len(only_a)}, only in B {len(only_b)}, "
              f"order {'same' if [n for n in oa if n in eb] == [n for n in ob if n in ea] else 'differs'}")
        for n in only_a[:10]:
            print(f"    only in A: {n}")
        for n in only_b[:10]:
            print(f"    only in B: {n}")
        for fields, count in sorted(kinds.items(), key=lambda kv: -kv[1]):
            print(f"  {count} entries differ in {', '.join(fields)}")
            for n in examples[fields][:10]:
                print(f"    {n}: " + "; ".join(f"{k} {ea[n][k]} / {eb[n][k]}" for k in fields))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
