# The dry run (GitHub run RUN, commit 30a2d3264, v0.0.0-dryrun.1) against its
# rebuild on arch (60-dryrun-rebuild.sh), 24 November: the run's artifacts
# laid out as compare.sh reads them, compare.sh with SIGNED=test (the run's
# throwaway CA), then build-manifest.py from the commit on the rebuilt files
# that compare.sh assembles (compare/sums: the local Linux files, the pasted
# Windows files, upgrade.sh, a new SHA256SUMS) and the local images' OCI
# files, and cmp with the run's build-manifest.json.
set -uo pipefail
RUN=${RUN:-45369603779} T=v0.0.0-dryrun.1 N=/private/tmp/rb1-dry1 CLONE=/private/tmp/rb1-ci/windows
E=/private/tmp/rb1-dre/1-ws-pems/scripts/5-release/local-vs-github-comparison
export DOCKER_CONFIG=/private/tmp/rb1-docker
echo "clone $(git -C "$CLONE" rev-parse HEAD) ($(git -C "$CLONE" describe --tags 2>/dev/null))"
echo "== the run's artifacts $(date +%H:%M:%S)"
rm -rf "$N/ci-raw" "$N/ci"; mkdir -p "$N/ci-raw" "$N/ci"
for a in release-frontend-export release-zips-linux release-zips-windows db-migration-bundles-linux db-migration-bundles-windows \
         release-checksums thesis-test-ca dry-run-release image-ws-pems image-ws-pems-job-worker image-wspems-mcp-server \
         image-wspems-chat-server image-wspems-mcp-auth-broker; do
  gh run download "$RUN" -R Weel-Sandvig/WS.Phoenix -n "$a" -D "$N/ci-raw/$a" > /dev/null 2>&1 && printf '  %-30s %s files\n' "$a" "$(find "$N/ci-raw/$a" -type f | wc -l)" || echo "  FAILED $a"
done
for a in release-zips-linux release-zips-windows db-migration-bundles-linux db-migration-bundles-windows thesis-test-ca \
         image-ws-pems image-ws-pems-job-worker image-wspems-mcp-server image-wspems-chat-server image-wspems-mcp-auth-broker; do
  ln -s "$N/ci-raw/$a" "$N/ci/$a"
done
ln -s "$N/ci-raw/release-frontend-export" "$N/ci/frontend-export"; ln -s "$N/ci-raw/release-checksums" "$N/ci/sha256sums"
echo; echo "== compare.sh $(date +%H:%M:%S)"
(cd /private/tmp && SIGNED=test CLONE=$CLONE SIGNING_IMAGE=ws-signing:rb-dry1 bash "$E/compare.sh" "$N" $T) 2>&1 | tee "$N/compare.txt"
echo "compare exit ${PIPESTATUS[0]}"
echo; echo "== the run's release folder against the rebuilt one (compare/sums)"
R=$N/ci-raw/dry-run-release/release
(cd "$R" && find . -type f ! -name build-manifest.json -exec basename {} \; | LC_ALL=C sort) > "$N/run-files.txt"
for f in $(cat "$N/run-files.txt"); do
  a=$(find "$R" -name "$f" -type f); b=$(find "$N/compare/sums" -name "$f" -type f)
  if [ -n "$b" ] && cmp -s "$a" "$b"; then echo "same  $f"; else echo "DIFF  $f"; fi
done
echo "SHA256SUMS: $(wc -l < "$R/SHA256SUMS") lines; names build-manifest.json: $(grep -c build-manifest "$R/SHA256SUMS")"
echo; echo "== build-manifest.json regenerated from the rebuild $(date +%H:%M:%S)"
python3 -I "$CLONE/scripts/release/build-manifest.py" --repo-dir "$CLONE" --commit "$(git -C "$CLONE" rev-parse HEAD)" --tag $T \
  --assets "$N/compare/sums" --images "$N/local/images" --output "$N/build-manifest-rebuilt.json"
echo "generator exit $?"
sha256sum "$R/build-manifest.json" "$N/build-manifest-rebuilt.json"
if cmp "$R/build-manifest.json" "$N/build-manifest-rebuilt.json"; then echo "cmp: IDENTICAL"; else echo "cmp: DIFFERENT"; diff "$R/build-manifest.json" "$N/build-manifest-rebuilt.json" | head -40; fi
python3 -I - "$R/build-manifest.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
b = d["predicate"]["buildDefinition"]
print("subjects:", len(d["subject"]), "files", sum(not s["name"].startswith("pkg:") for s in d["subject"]), "images", sum(s["name"].startswith("pkg:") for s in d["subject"]))
print("resolvedDependencies:", len(b["resolvedDependencies"]), [x["uri"].rsplit("/", 1)[-1] for x in b["resolvedDependencies"]])
print("source:", b["externalParameters"]["source"]["digest"]["gitCommit"], "env:", b["externalParameters"]["env"])
PY
echo "== done $(date +%H:%M:%S)"
