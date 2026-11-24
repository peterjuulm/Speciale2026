# The three MCP images of the v0.0.0-thesis.6 rebuild on arch against GHCR:
# which layers differ, the Debian package versions in them, and who owns each
# differing entry. With the Mac Studio session's tools of 23/11
# (Speciale2026/experiments/phoenix-rt: ghcr-oci.py, dpkg-diff.py,
# layer-owners.py), and oci-diff.py of dotnet-rebuild-experiments at d991fc5.
# Reads files only; runs beside the linux job.
set -uo pipefail
N=/private/tmp/rb1-rebuild6 T=v0.0.0-thesis.6 X=/private/tmp/rb1-lab R=/private/tmp/rb1-dre
O=$N/trace; mkdir -p $O
for n in wspems-mcp-server wspems-chat-server wspems-mcp-auth-broker; do
  echo; echo "=== $n"
  GH_TOKEN=$(gh auth token) python3 -I $X/ghcr-oci.py weel-sandvig/$n $T $N/local/images/$n.oci.tar $O/ghcr-$n.oci.tar 2>&1 | tail -n 12
  python3 -I $R/1-ws-pems/scripts/6-images/oci-diff.py $O/ghcr-$n.oci.tar $N/local/images/$n.oci.tar > $O/oci-diff-$n.txt 2>&1
  head -n 3 $O/oci-diff-$n.txt
  python3 -I - $O/ghcr-$n.oci.tar $N/local/images/$n.oci.tar > $O/layers-$n.txt <<'PY'
import json, sys, tarfile
def layers(p):
    t = tarfile.open(p); idx = json.load(t.extractfile("index.json"))
    m = idx["manifests"][0]["digest"].split(":")[1]
    man = json.load(t.extractfile("blobs/sha256/" + m))
    if "manifests" in man:
        m = [x for x in man["manifests"] if x.get("platform", {}).get("architecture") == "amd64"][0]["digest"].split(":")[1]
        man = json.load(t.extractfile("blobs/sha256/" + m))
    return [l["digest"].split(":")[1] for l in man["layers"]]
a, b = layers(sys.argv[1]), layers(sys.argv[2])
print(len(a), len(b))
for i, (x, y) in enumerate(zip(a, b), 1):
    if x != y: print(i, x, y)
PY
  cat $O/layers-$n.txt
  tail -n +2 $O/layers-$n.txt | while read i a b; do
    echo "-- layer $i: packages (GHCR -> arch)"; python3 -I $X/dpkg-diff.py $O/ghcr-$n.oci.tar $a $N/local/images/$n.oci.tar $b 2>&1
    echo "-- layer $i: differing entries by owner"; python3 -I $X/layer-owners.py $O/ghcr-$n.oci.tar $a $N/local/images/$n.oci.tar $b 2>&1 | head -n 30
  done
done
echo "== done $(date +%H:%M:%S)"
