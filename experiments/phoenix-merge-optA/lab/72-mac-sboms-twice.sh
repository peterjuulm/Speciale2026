# The Mac Studio, 24 November evening: scripts/release/sboms.sh (thesis.8's
# SBOM zip, branch commit 758cd3f06, not pushed yet) on thesis.7's published
# files, twice, each time on a fresh builder of the pinned BuildKit; the two
# zips must be identical. A local trial before the GitHub dry run: it runs
# natively (linux/arm64 builder; the scanned images are FROM scratch), so
# its zip is not expected to equal a GitHub runner's, only itself.
# The release's files laid out as the sboms job downloads them: zips at the
# top, the migrators in db/; the five image SBOMs from thesis.7's assets.
set -uo pipefail
C=${C:-758cd3f06} A=$HOME/rb1-mac-t7/t7/assets H=$HOME/rb1-mac-t7/sboms
export PATH=/private/tmp/rb1-ms-docker/bin:$PATH DOCKER_CONFIG=/private/tmp/rb1-ms-docker/config
rm -rf "$H"; mkdir -p "$H/release/db" "$H/images"
cp "$A"/*.zip "$H/release/"; cp "$A"/ws-pems-db-migrator-* "$H/release/db/"; cp "$A"/*.spdx.json "$H/images/"
ls -R "$H/release" "$H/images" | head -30
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$H:$H" -v "$HOME/Dev/Weel-Sandvig/WS.Phoenix:/repo:ro" \
  rb1-verifier:amd64 bash -c "
    set -e
    git clone -q --no-checkout /repo /src && git -C /src checkout -q --detach $C && echo \"source: \$(git -C /src log -1 --format='%h %s')\"
    bk=\$(sed -n 's/^  BUILDKIT_IMAGE: //p' /src/.github/workflows/03-release.yml)
    for w in 1 2; do
      echo \"== run \$w \$(date +%H:%M:%S)\"
      docker buildx create --name sb\$w --driver docker-container --driver-opt image=\$bk --bootstrap > /dev/null 2>&1
      (cd /src && BUILDX_BUILDER=sb\$w APP_VERSION=v0.0.0-thesis.7 SOURCE_DATE_EPOCH=1795530171 scripts/release/sboms.sh $H/release $H/images $H/out\$w) > $H/run\$w.log 2>&1 || { echo \"run \$w failed\"; tail -30 $H/run\$w.log; }
      grep -E '^== |packages|sbom-' $H/run\$w.log | grep -v '^#' || true
      docker buildx rm sb\$w > /dev/null 2>&1 || true
    done
    cmp $H/out1/ws-pems-sbom-v0.0.0-thesis.7.zip $H/out2/ws-pems-sbom-v0.0.0-thesis.7.zip && echo 'the two zips: identical'
    unzip -l $H/out1/ws-pems-sbom-v0.0.0-thesis.7.zip
  "
echo "== done $(date +%H:%M:%S)"
