#!/usr/bin/env python3
"""A published image tag against a local image file (written 14 October 2026).

    GH_TOKEN=$(gh auth token) ghcr-manifests.py OWNER/IMAGE TAG [LOCAL.oci.tar]

Reads the index the tag points at from GHCR's registry API and prints its
digest, the linux/amd64 image manifest's digest and the attestation
manifest's, as W65 says a rebuild is compared: by the image manifest, not the
tag. With LOCAL, also the image manifest digest of that OCI file (ci-local.sh
writes one without attestations) and "same" or "DIFF". GH_TOKEN needs
read:packages; it is exchanged for a pull token and never printed.
"""
import base64
import hashlib
import json
import os
import sys
import tarfile
import urllib.request

INDEX = "application/vnd.oci.image.index.v1+json"
ACCEPT = ", ".join([INDEX, "application/vnd.oci.image.manifest.v1+json",
                    "application/vnd.docker.distribution.manifest.list.v2+json",
                    "application/vnd.docker.distribution.manifest.v2+json"])


def pull_token(repository):
    basic = base64.b64encode(f"token:{os.environ['GH_TOKEN']}".encode()).decode()
    request = urllib.request.Request(
        f"https://ghcr.io/token?service=ghcr.io&scope=repository:{repository}:pull",
        headers={"Authorization": f"Basic {basic}"})
    with urllib.request.urlopen(request) as response:
        return json.load(response)["token"]


def manifest(repository, reference, token):
    request = urllib.request.Request(
        f"https://ghcr.io/v2/{repository}/manifests/{reference}",
        headers={"Authorization": f"Bearer {token}", "Accept": ACCEPT})
    with urllib.request.urlopen(request) as response:
        body = response.read()
    return "sha256:" + hashlib.sha256(body).hexdigest(), json.loads(body)


def local_image(path):
    tar = tarfile.open(path)
    top = json.loads(tar.extractfile("index.json").read())["manifests"][0]
    if top["mediaType"] == INDEX:
        blob = tar.extractfile("blobs/sha256/" + top["digest"].split(":")[1]).read()
        entries = json.loads(blob)["manifests"]
        return [m["digest"] for m in entries if m.get("platform", {}).get("os") == "linux"][0]
    return top["digest"]


repository, tag = sys.argv[1].lower(), sys.argv[2]
token = pull_token(repository)
digest, body = manifest(repository, tag, token)
image = attestation = None
for entry in body.get("manifests", []):
    kind = entry.get("annotations", {}).get("vnd.docker.reference.type")
    platform = entry.get("platform", {})
    if kind == "attestation-manifest":
        attestation = entry["digest"]
    elif platform.get("os") == "linux" and platform.get("architecture") == "amd64":
        image = entry["digest"]
if not body.get("manifests"):
    image = digest
print(f"{repository}:{tag}  index {digest}  image {image}  attestation {attestation}")
if len(sys.argv) > 3:
    mine = local_image(sys.argv[3])
    print(f"  local image {mine}  {'same' if mine == image else 'DIFF'}")
