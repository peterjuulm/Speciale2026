# Is an image's SBOM reproducible? Stage 2 moves the SBOM out of the image
# index into a release asset; if it is reproducible it can be a subject of
# build-manifest.json. The chat server and the MCP server of 30a2d3264 (the
# dry run's commit, in /private/tmp/rb1-ci/images), each SBOM built twice with
# --no-cache, BuildKit v0.33.1 (rb1) and the release's scanner, dated by the
# commit; then the SPDX documents compared.
set -uo pipefail
c=/private/tmp/rb1-ci/images o=/private/tmp/rb1-sbom; rm -rf "$o"; mkdir -p "$o"
export DOCKER_CONFIG=/private/tmp/rb1-docker SOURCE_DATE_EPOCH=$(git -C "$c" log -1 --format=%ct)
gen=$(sed -n 's/^  SBOM_GENERATOR: //p' "$c/.github/workflows/03-release.yml")
echo "commit $(git -C "$c" rev-parse HEAD), SOURCE_DATE_EPOCH $SOURCE_DATE_EPOCH, generator $gen"
for name in wspems-chat-server wspems-mcp-server; do
  case $name in wspems-chat-server) f=mcp/chat-server/Dockerfile ;; wspems-mcp-server) f=mcp/Dockerfile ;; esac
  for run in 1 2; do
    flock /tmp/claude-1000/phoenix-dotnet.lock docker buildx build --builder rb1 --no-cache -f "$c/$f" --provenance=false --sbom="generator=$gen" \
      --output "type=oci,dest=$o/$name-$run.oci.tar,rewrite-timestamp=true" "$c/mcp" > "$o/$name-$run.log" 2>&1
    echo "$name build $run exit $?"
    python3 -I - "$o/$name-$run.oci.tar" "$o/$name-$run.spdx.json" <<'PY'
import json, sys, tarfile
t = tarfile.open(sys.argv[1]); blob = lambda d: t.extractfile("blobs/" + d.replace(":", "/", 1)).read()
def entries(i):
    for e in i["manifests"]:
        if "index" in e["mediaType"] or "list" in e["mediaType"]: yield from entries(json.loads(blob(e["digest"])))
        else: yield e
att = [e for e in entries(json.loads(t.extractfile("index.json").read())) if (e.get("annotations") or {}).get("vnd.docker.reference.type") == "attestation-manifest"]
layers = [l for l in json.loads(blob(att[0]["digest"]))["layers"] if "spdx" in (l.get("annotations") or {}).get("in-toto.io/predicate-type", "")]
spdx = json.loads(blob(layers[0]["digest"]))["predicate"]
open(sys.argv[2], "w").write(json.dumps(spdx, sort_keys=True, indent=2, ensure_ascii=False) + "\n")
print("  ", sys.argv[2].rsplit("/", 1)[1], "packages", len(spdx.get("packages", [])), "created", spdx.get("creationInfo", {}).get("created"), "namespace", spdx.get("documentNamespace"))
PY
  done
  if cmp -s "$o/$name-1.spdx.json" "$o/$name-2.spdx.json"; then echo "$name: SBOM IDENTICAL ($(sha256sum < "$o/$name-1.spdx.json" | cut -c1-16))"; else echo "$name: SBOM DIFFERENT"; diff "$o/$name-1.spdx.json" "$o/$name-2.spdx.json" | head -20; fi
done
