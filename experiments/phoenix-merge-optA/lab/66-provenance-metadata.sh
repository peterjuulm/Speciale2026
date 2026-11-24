# Stage 2's provenance file: does buildx write buildx.build.provenance into
# --metadata-file when the build makes no provenance attestation
# (--provenance=false)? BUILDX_METADATA_PROVENANCE=max; the broker image of
# the dry-run clone, rb1 (BuildKit v0.33.1); then the same with
# --provenance=mode=max, for comparison. Then: the keys, and any github_,
# e-mail address or name-like field in what is there.
set -uo pipefail
c=/private/tmp/rb1-ci/images o=/private/tmp/rb1-prov; rm -rf "$o"; mkdir -p "$o"
export DOCKER_CONFIG=/private/tmp/rb1-docker BUILDX_METADATA_PROVENANCE=max SOURCE_DATE_EPOCH=$(git -C "$c" log -1 --format=%ct)
docker buildx version
for p in false mode=max; do
  flock /tmp/claude-1000/phoenix-dotnet.lock docker buildx build --builder rb1 -f "$c/mcp/auth-broker/Dockerfile" --provenance=$p --sbom=false \
    --metadata-file "$o/meta-$p.json" --output "type=oci,dest=$o/broker-$p.oci.tar,rewrite-timestamp=true" "$c/mcp/auth-broker" > "$o/build-$p.log" 2>&1
  echo "== --provenance=$p: build exit $?"
  python3 -I - "$o/meta-$p.json" <<'PY'
import json, re, sys
m = json.load(open(sys.argv[1]))
print("metadata keys:", sorted(m))
p = m.get("buildx.build.provenance")
if p is None:
    print("buildx.build.provenance: ABSENT"); sys.exit()
t = json.dumps(p)
print("buildx.build.provenance: present,", len(t), "bytes; top keys:", sorted(p) if isinstance(p, dict) else type(p).__name__)
print("  github_ keys:", sorted(set(re.findall(r'"(github_[a-z_]+)"', t))))
print("  e-mail addresses:", sorted(set(re.findall(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}", t)))[:10])
print("  times:", sorted(set(re.findall(r"20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z?", t)))[:6])
print("  invocationId/buildType/builder:", p.get("invocationID") or p.get("metadata", {}).get("buildInvocationID"), p.get("buildType"), (p.get("builder") or {}).get("id"))
PY
done
