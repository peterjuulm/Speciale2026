#!/usr/bin/env python3
"""One file out of an OCI image tarball (buildx --output type=oci), 14 October 2026.

    oci-file.py IMAGE.oci.tar PATH OUT

Writes the file PATH (as named in the layers, e.g. app/ApplicationCore.pdb)
to OUT, from the topmost layer that holds it, and prints that layer's
digest. The image is found as oci-diff.py finds it: the linux/amd64 image
manifest, attestation manifests skipped. Whiteouts are not followed.
"""
import gzip
import importlib.util
import os
import sys
import tarfile

spec = importlib.util.spec_from_file_location(
    "oci_diff", os.path.join(os.path.dirname(os.path.abspath(__file__)), "oci-diff.py"))
oci_diff = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oci_diff)

tarball, path, out = sys.argv[1:4]
layout = oci_diff.Layout(tarball)
_, _, manifest = layout.image()
for desc in reversed(manifest["layers"]):
    f = layout.blob(desc["digest"])
    if desc["mediaType"].endswith("gzip"):
        f = gzip.open(f)
    layer = tarfile.open(fileobj=f, mode="r|")
    for entry in layer:
        if entry.name.lstrip("./") == path and entry.isfile():
            with open(out, "wb") as o:
                o.write(layer.extractfile(entry).read())
            print(desc["digest"])
            sys.exit(0)
sys.exit(f"{path} not in {tarball}")
