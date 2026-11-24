#!/usr/bin/env python3
"""GHCR's linux/amd64 image of a tag as an OCI tarball, for oci-diff.py
(written 23 November 2026, for phoenix-macstudio-rebuild).

    GH_TOKEN=... ghcr-oci.py OWNER/IMAGE TAG LOCAL.oci.tar OUT.oci.tar

Fetches the tag's index, its linux/amd64 image manifest and config from
GHCR. Each layer is taken from LOCAL when LOCAL has a blob of that digest,
otherwise downloaded from GHCR and its sha256 checked. Prints the manifest's
digest and, per layer, whether it came from LOCAL or GHCR.
"""
import base64, hashlib, io, json, os, sys, tarfile, urllib.request

repo, tag, local, out = sys.argv[1].lower(), sys.argv[2], sys.argv[3], sys.argv[4]
ACCEPT = ("application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, "
          "application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json")
basic = base64.b64encode(f"token:{os.environ['GH_TOKEN']}".encode()).decode()
with urllib.request.urlopen(urllib.request.Request(
        f"https://ghcr.io/token?service=ghcr.io&scope=repository:{repo}:pull",
        headers={"Authorization": f"Basic {basic}"})) as r:
    token = json.load(r)["token"]

def get(path, accept=ACCEPT):
    req = urllib.request.Request(f"https://ghcr.io/v2/{repo}/{path}",
                                 headers={"Authorization": f"Bearer {token}", "Accept": accept})
    with urllib.request.urlopen(req) as r:
        return r.read()

def check(digest, body):
    got = "sha256:" + hashlib.sha256(body).hexdigest()
    if got != digest:
        sys.exit(f"digest mismatch: {digest} {got}")
    return body

index = json.loads(get(f"manifests/{tag}"))
entry = [m for m in index["manifests"] if m.get("platform", {}).get("architecture") == "amd64"
         and m.get("platform", {}).get("os") == "linux"][0]
manifest_body = check(entry["digest"], get(f"manifests/{entry['digest']}"))
manifest = json.loads(manifest_body)
print(f"{repo}:{tag} image manifest {entry['digest']}")
lt = tarfile.open(local)
names = set(lt.getnames())
blobs = {entry["digest"]: manifest_body}
cfg = manifest["config"]["digest"]
blobs[cfg] = check(cfg, get(f"blobs/{cfg}"))
for layer in manifest["layers"]:
    d = layer["digest"]
    name = "blobs/sha256/" + d.split(":")[1]
    if name in names:
        blobs[d] = lt.extractfile(name).read(); src = "local"
    else:
        blobs[d] = check(d, get(f"blobs/{d}", "*/*")); src = "GHCR"
    print(f"  layer {d} {layer['size']} from {src}")
idx = {"schemaVersion": 2, "mediaType": "application/vnd.oci.image.index.v1+json",
       "manifests": [{"mediaType": manifest.get("mediaType", "application/vnd.oci.image.manifest.v1+json"),
                      "digest": entry["digest"], "size": len(manifest_body),
                      "platform": {"architecture": "amd64", "os": "linux"}}]}
with tarfile.open(out, "w") as t:
    def add(name, data):
        info = tarfile.TarInfo(name); info.size = len(data); t.addfile(info, io.BytesIO(data))
    add("oci-layout", b'{"imageLayoutVersion":"1.0.0"}')
    add("index.json", json.dumps(idx).encode())
    for d, data in blobs.items():
        add("blobs/sha256/" + d.split(":")[1], data)
