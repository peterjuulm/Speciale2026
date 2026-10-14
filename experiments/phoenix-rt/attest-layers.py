#!/usr/bin/env python3
"""Which provenance fields differ between two OCI image files, grouped,
and whether the layers the provenance names are the image's.

BuildKit's SLSA provenance records the layers each build step made. This
prints how many of the layer digests it names are in the image manifest,
and how many of those that differ between the two builds are. Field paths
and counts only, no values.

    attest-layers.py A.oci.tar B.oci.tar
"""
import collections
import json
import re
import sys
import tarfile


def load(path):
    tar = tarfile.open(path)

    def blob(digest):
        return tar.extractfile("blobs/sha256/" + digest.split(":")[1]).read()

    top = json.loads(tar.extractfile("index.json").read())["manifests"][0]
    entries = json.loads(blob(top["digest"]))["manifests"]
    kind = lambda m: m.get("annotations", {}).get("vnd.docker.reference.type")
    image = json.loads(blob([m for m in entries if kind(m) != "attestation-manifest"][0]["digest"]))
    attestation = [m for m in entries if kind(m) == "attestation-manifest"][0]
    for layer in json.loads(blob(attestation["digest"]))["layers"]:
        statement = json.loads(blob(layer["digest"]))
        if "slsa.dev/provenance" in statement["predicateType"]:
            return image, statement
    sys.exit(f"{path}: no provenance")


def fields(value, path=""):
    if isinstance(value, dict):
        for key, item in value.items():
            yield from fields(item, f"{path}.{key}")
    elif isinstance(value, list):
        for number, item in enumerate(value):
            yield from fields(item, f"{path}[{number}]")
    else:
        yield path, value


(image_a, prov_a), (_, prov_b) = load(sys.argv[1]), load(sys.argv[2])
fa, fb = dict(fields(prov_a)), dict(fields(prov_b))
differ = sorted(path for path in set(fa) | set(fb) if fa.get(path) != fb.get(path))
shape = lambda path: re.sub(r"sha256:[0-9a-f]{64}", "<digest>",
                            re.sub(r"step\d+:\d+(\[\d+\])+", "<step layer>", path))
print(f"{len(differ)} of {len(set(fa) | set(fb))} provenance fields differ:")
for group, count in collections.Counter(map(shape, differ)).most_common():
    print(f"  {count:4}  {group}")
in_image = {layer["digest"] for layer in image_a["layers"]}
named = {v for k, v in fa.items() if ".buildkit_metadata.layers." in k and k.endswith(".digest")}
named_differ = {fa[k] for k in differ if k in fa and ".buildkit_metadata.layers." in k and k.endswith(".digest")}
print(f"layers in the image manifest: {len(in_image)}")
print(f"layer digests the provenance names: {len(named)}, in the image: {len(named & in_image)}")
print(f"of those that differ between the two: {len(named_differ)}, in the image: {len(named_differ & in_image)}")
