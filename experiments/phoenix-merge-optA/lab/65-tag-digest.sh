# Stage 2's tag check, without GHCR: a throwaway registry on localhost:5000
# and a builder of the pinned BuildKit on the host network. docker-images.sh
# push (stage 2's script; dry run 5's source, 8491a0d63, whose
# docker-images.sh is the one at 96e2990a6, the commit to be tagged) pushes the five images by digest; then
# the release job's own tagging, imagetools create --prefer-index=false, and
# its check that the tag's digest is the manifest's. Also the old way
# (without --prefer-index=false) on one image, to see what it would make.
# First run 24/11 evening, after 64g; buildx 0.38 has no create -q.
set -uo pipefail
V=/private/tmp/rb1-verify S=$V/src R=localhost:5000/weel-sandvig T=v0.0.0-dryrun.5 B=rb1-reg
export DOCKER_CONFIG=/private/tmp/rb1-docker
c=$V/tagtest; rm -rf "$c"; git clone -q "$S" "$c" && git -C "$c" checkout -q --detach "$(git -C "$S" rev-parse HEAD)"
rm -rf "$c/src/WebAPI/ClientApp/out"; cp -a "$V/work1/jobs/frontend/src/WebAPI/ClientApp/out" "$c/src/WebAPI/ClientApp/out"
docker rm -f rb1-registry > /dev/null 2>&1
docker run -d --name rb1-registry -p 127.0.0.1:5000:5000 registry:2 > /dev/null && echo "registry: $(docker inspect rb1-registry --format '{{.Image}}')"
printf '[registry."localhost:5000"]\n  http = true\n  insecure = true\n' > "$V/buildkitd.toml"
docker buildx rm "$B" > /dev/null 2>&1
bk=$(sed -n 's/^  BUILDKIT_IMAGE: //p' "$c/.github/workflows/03-release.yml")
docker buildx create --name "$B" --driver docker-container --driver-opt "image=$bk" --driver-opt network=host --buildkitd-config "$V/buildkitd.toml" --bootstrap > /dev/null 2>&1 || { echo "builder failed"; exit 1; }
echo "== push $(date +%H:%M:%S)"
(cd "$c" && APP_VERSION=$T BUILDX_BUILDER=$B flock /tmp/claude-1000/phoenix-dotnet.lock scripts/release/docker-images.sh push "$R" "$V/pushed") > "$V/push.log" 2>&1
echo "push exit $?"; grep -E "^[a-z-]+ (sha256|sbom)" "$V/push.log"
echo "== tag, as the release job does"
for image in ws-pems ws-pems-job-worker wspems-mcp-server wspems-chat-server wspems-mcp-auth-broker; do
  digest=$(cat "$V/pushed/$image.digest")
  type=$(BUILDX_BUILDER=$B docker buildx imagetools inspect --raw "$R/$image@$digest" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("mediaType"))')
  BUILDX_BUILDER=$B docker buildx imagetools create --prefer-index=false -t "$R/$image:$T" "$R/$image@$digest" > /dev/null 2>&1; rc=$?
  tagged=$(BUILDX_BUILDER=$B docker buildx imagetools inspect "$R/$image:$T" | sed -n 's/^Digest:[[:space:]]*//p')
  [ "$tagged" = "$digest" ] && v=SAME || v=DIFFERENT
  echo "$image: pushed $type $digest; create exit $rc; tag $tagged: $v"
done
echo "== without --prefer-index=false (the default), for ws-pems-mcp-auth-broker"
digest=$(cat "$V/pushed/wspems-mcp-auth-broker.digest")
BUILDX_BUILDER=$B docker buildx imagetools create -t "$R/wspems-mcp-auth-broker:default-index" "$R/wspems-mcp-auth-broker@$digest" > /dev/null 2>&1
d=$(BUILDX_BUILDER=$B docker buildx imagetools inspect "$R/wspems-mcp-auth-broker:default-index" | sed -n 's/^Digest:[[:space:]]*//p')
t=$(BUILDX_BUILDER=$B docker buildx imagetools inspect --raw "$R/wspems-mcp-auth-broker:default-index" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("mediaType"))')
echo "default: tag $d ($t); manifest $digest"
echo "== the tag against build-manifest.json: rebuild 1's manifest lists each linux/amd64 manifest"
for image in ws-pems ws-pems-job-worker wspems-mcp-server wspems-chat-server wspems-mcp-auth-broker; do
  listed=$(python3 -c 'import json,sys; print(next("sha256:" + s["digest"]["sha256"] for s in json.load(open(sys.argv[1]))["subject"] if s["name"].startswith(f"pkg:docker/ghcr.io/weel-sandvig/{sys.argv[2]}@")))' "$V/work1/build-manifest.json" "$image")
  tagged=$(BUILDX_BUILDER=$B docker buildx imagetools inspect "$R/$image:$T" | sed -n 's/^Digest:[[:space:]]*//p')
  [ "$tagged" = "$listed" ] && echo "$image: tag = build-manifest.json's $listed" || echo "$image: tag $tagged, build-manifest.json $listed: DIFFERENT"
done
echo "== the pushed manifests against the OCI files of rebuild 1"
for image in ws-pems ws-pems-job-worker wspems-mcp-server wspems-chat-server wspems-mcp-auth-broker; do
  oci=$(tar -xOf "$V/work1/images/$image.oci.tar" index.json | python3 -c 'import json,sys; print(json.load(sys.stdin)["manifests"][0]["digest"])')
  [ "$oci" = "$(cat "$V/pushed/$image.digest")" ] && echo "$image: same as rebuild 1's OCI file" || echo "$image: DIFFERENT from rebuild 1's OCI file ($oci)"
done
for image in ws-pems wspems-chat-server; do cmp -s "$V/pushed/$image-$T.spdx.json" "$V/work1/images/$image-$T.spdx.json" && echo "$image SBOM: same as rebuild 1's" || echo "$image SBOM: DIFFERENT"; done
docker rm -f rb1-registry > /dev/null; docker buildx rm "$B" > /dev/null; echo "registry and builder removed"
