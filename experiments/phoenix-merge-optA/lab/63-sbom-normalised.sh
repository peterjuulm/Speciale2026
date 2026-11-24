# The SBOM pairs of 62-sbom-twice, with docker-images.sh's two fields set as
# it sets them (creationInfo.created: the commit's time; documentNamespace:
# the asset's URL): identical?
set -uo pipefail
o=/private/tmp/rb1-sbom
for name in wspems-chat-server wspems-mcp-server; do
  for run in 1 2; do
    python3 -I - "$o/$name-$run.spdx.json" "$o/$name-$run.norm.json" 1795514037 "https://example/v0.0.0-dryrun.1/$name.spdx.json" <<'PY'
import json, sys, time
d = json.load(open(sys.argv[1]))
d["creationInfo"]["created"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(int(sys.argv[3])))
d["documentNamespace"] = sys.argv[4]
open(sys.argv[2], "w").write(json.dumps(d, sort_keys=True, indent=2, ensure_ascii=False) + "\n")
PY
  done
  cmp -s "$o/$name-1.norm.json" "$o/$name-2.norm.json" && echo "$name: normalised SBOMs IDENTICAL" || { echo "$name: still DIFFERENT"; diff "$o/$name-1.norm.json" "$o/$name-2.norm.json" | head; }
done
