#!/bin/bash
# Build one Dockerfile stage per variant, under Rosetta (builder rb1) and
# under BuildKit's own QEMU (builder rb1q), as OCI files. Written 24
# November 2026 for rosetta-cache-layer.
#
#   variants.sh CONTEXT DOCKERFILE TARGET OUT SDE LINES VARIANT...
#
# DOCKERFILE is relative to CONTEXT. LINES is a comma-separated list of
# the line numbers of the RUN instructions to change. TARGET may be "-"
# for the whole Dockerfile. Each VARIANT is one of
#   v0     the Dockerfile unchanged
#   cache  --mount=type=tmpfs,target=/root/.cache on each listed RUN
#   home   --mount=type=tmpfs,target=/root on each listed RUN
#   shm    a line ARG HOME=/dev/shm before each listed RUN
# The changed Dockerfile goes to OUT/<variant>.Dockerfile, outside the
# context, so the context's own .dockerignore applies. Per builder b:
# OUT/<variant>-<b>.oci.tar and .log. The builds run one at a time, with
# the release workflow's build arguments for the WebAPI image (the other
# images ignore them). Nothing is pushed or loaded. BUILDERS in the
# environment picks the builders (default "rb1 rb1q"). NOCACHE picks the
# cache flag (default --no-cache); --no-cache-filter=<stages> instead
# reruns only those stages and takes the others from the builder's cache.
set -eu
BUILDERS=${BUILDERS:-"rb1 rb1q"}
NOCACHE=${NOCACHE:---no-cache}
CTX=$1 DF=$2 TARGET=$3 OUT=$4 SDE=$5 LINES=$6
shift 6
mkdir -p "$OUT"
for v in "$@"; do
  awk -v lines=",$LINES," -v v="$v" '
    index(lines, "," NR ",") {
      if (v == "cache") { if (!sub(/^RUN /, "RUN --mount=type=tmpfs,target=/root/.cache ")) exit 3 }
      else if (v == "home") { if (!sub(/^RUN /, "RUN --mount=type=tmpfs,target=/root ")) exit 3 }
      else if (v == "shm") { if ($0 !~ /^RUN /) exit 3; print "ARG HOME=/dev/shm" }
      else if (v != "v0") exit 4
    }
    { print }' "$CTX/$DF" > "$OUT/$v.Dockerfile"
  t=()
  [ "$TARGET" = - ] || t=(--target "$TARGET")
  for b in $BUILDERS; do
    echo "$(date '+%H:%M:%S') $v $b"
    env SOURCE_DATE_EPOCH="$SDE" docker buildx build --builder $b --platform linux/amd64 \
      $NOCACHE --provenance=false ${t[@]+"${t[@]}"} -f "$OUT/$v.Dockerfile" \
      --build-arg APP_VERSION=v0.0.0-thesis.7 --build-arg SKIP_SPA_BUILD=true \
      --output "type=oci,dest=$OUT/$v-$b.oci.tar,rewrite-timestamp=true" "$CTX" \
      > "$OUT/$v-$b.log" 2>&1 || echo "   exit $? (see $OUT/$v-$b.log)"
  done
done
echo "$(date '+%H:%M:%S') done"
