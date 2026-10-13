# The release's .NET images, built twice, 13 October 2026

## Question

Layer 5 of the [layer plan](2026-09-15-layer-plan.md) is the Docker images.
The release's `docker-images` job builds five images and pushes them to
WS's registry: the WebAPI, the job worker and three MCP images. Two of
them carry the .NET programs the zips carry: `src/WebAPI/Dockerfile` and
`src/BackgroundJobExecutor/Dockerfile`. Is either reproducible: does one
commit, built twice the way the job builds it, give the same image? If
not, what differs, and does BuildKit's `SOURCE_DATE_EPOCH` with the
exporter's `rewrite-timestamp=true` remove it?

## Setup

Run by Claude at Leo's request, on `arch`, on the WS branch head
`100e3912`. `experiments/phoenix-rt/image-probe.sh` exports the commit to
a lab with `git archive` (checked with `labcheck.py`), builds the frontend
export there as layer `R` does (Node 22.23.3, the offline npm cache,
`APP_VERSION=v0.0.0-thesis`), then builds each image twice with
`docker buildx build` on a `docker-container` builder, which is what
`docker/setup-buildx-action` gives the job: buildx 0.38.0, BuildKit
0.33.1. Each build gets `--no-cache`, the build arguments the job passes
(`APP_VERSION`, and `SKIP_SPA_BUILD=true` for the WebAPI), no provenance,
and writes an OCI tarball. `experiments/phoenix-rt/oci-diff.py` compares
two tarballs: the image manifest's digest, the config's fields, and the
entries of every layer that differs.

Two passes:

- `P1`, the job's settings: no `SOURCE_DATE_EPOCH`.
- `P2`: `SOURCE_DATE_EPOCH` set to the commit's time as a build argument,
  and `rewrite-timestamp=true` on the OCI exporter.

Each build downloads: the base images by digest from Microsoft's
registry, and in its restore the NuGet packages from nuget.org, since
nothing is cached.

Not like the job:

- The job builds with `cache-from: type=gha` and `cache-to` (mode
  `min`). A warm cache gives it layers from an earlier run; these builds
  are the cold case.
- The job adds a provenance attestation and an SBOM (`provenance: true`,
  `sbom: true`), each a manifest of its own in the image index. Here the
  comparison is of the image manifest itself.
- The three MCP images are left out.

## Expectation, written before the runs

All `[I]`.

1. `P1`: the two builds of each image differ. The config differs in
   `created` and in each history entry's `created`. The layers that come
   from the `aspnet` base image are the same; the layers the build adds
   differ in their entries' times only: the WebAPI's `RUN mkdir` layer
   for the data-protection folder, the directory `WORKDIR` makes, and the
   layer `COPY --from=publish` makes.
2. In both passes, the files the publish stage copies into the image have
   the same content in both builds. The publish inside the image is
   deterministic like layer 2's, with other options: framework-dependent,
   no apphost.
3. `P2`: the two builds of each image give the same manifest digest and
   byte-identical tarballs. The fix works for these images as it did for
   a minimal image before the runs.

## Commands

Verbatim in `data/2026-10-13-phoenix-images/arch/kommando.txt`.

## Result

`[V]` (the tarballs in the lab, the comparisons in private data, their
summaries in `results.txt` beside `kommando.txt`), 22:17-22:37:

1. Held, but for one layer. `P1`: the two builds of each image differ in
   the config's `created` and history times and the index's `created`
   annotation. The six layers from the `aspnet` base image are the same.
   The WebAPI's `RUN mkdir` layer differs in its three folders' times,
   and the `COPY --from=publish` layer in the times of 123 of its 1408
   entries; the job worker's in 9 of 172. The exception: the layer
   `WORKDIR /app` makes was the same in both builds. BuildKit took that
   step from its cache in the second build despite `--no-cache` (the logs
   say `CACHED`), so the folder kept the first build's time.
2. Held. No entry differs in content, mode, owner or order, in either
   image: only times.
3. Held. `P2`: both builds of each image give one manifest (WebAPI
   `2b8a8ff1…`, job worker `dfb87e07…`), and the tarballs are
   byte-identical. Against `P1` only times changed: the same entries and
   contents, the six base layers with their digests unchanged. Every time
   later than the epoch became the epoch, and earlier ones stayed. Of the
   WebAPI layer's 1408 entries, 1117 were later and became the epoch,
   290 were earlier and kept their times, and one was the epoch already;
   of the job worker's 172, 9, 162 and one. Each rewritten layer carries
   the annotation `buildkit/rewritten-timestamp` with the epoch.

A check at 22:30, on the minimal image: `SOURCE_DATE_EPOCH` only in
buildx's environment, the way Docker's documentation passes it to
`docker/build-push-action`, fixes the config's times, but the folder
`COPY` makes keeps the build's time.

Two checks after the passes, with no expectation written first, on the
WebAPI image:

- 22:41-22:45, the cache. A build with a new epoch (`1791924000`), the
  builder's cache filled at other epochs, against a `--no-cache` build
  with that epoch: the same image (`2a287f0f…`). The cached build reran
  `WORKDIR /app` and every step after it. In all earlier builds
  `WORKDIR` came from the cache only under the same epoch, so the epoch
  is part of that step's cache key `[V]` (the build logs).
- 22:47-22:49, the epoch as the workflow would pass it: `SOURCE_DATE_EPOCH`
  in buildx's environment instead of a build argument, with
  `rewrite-timestamp=true`. Byte-identical to `P2`'s WebAPI.

## Interpretation

**The two images differ only in time.** `[V]` for these two images on
`arch`: between two builds only the build's clock differs, in the config,
the index, and the times of the files in the layers the build adds. The
programs in them are the same bytes.

**BuildKit's own settings remove it.** `[V]` for `arch`:
`SOURCE_DATE_EPOCH` with `rewrite-timestamp=true` gives byte-identical
images and leaves the base layers alone, so they stay shared with
Microsoft's image. The epoch alone is not enough (the 22:30 check), and
it can come from the environment (the 22:47 check). In the release job
that is the commit's time in the job's environment and
`rewrite-timestamp=true` on each image's output; on GitHub `[I]`.

**One builder hides part of the difference.** `[V]` that `WORKDIR` came
from the cache. CI starts each run with a new builder `[I]`, so there the
folder would carry each run's time as well. With the fix it is rewritten
like the rest (`P2`, the WebAPI's layer 6).

The fix is in the release job since `fa60ea97` on the WS branch, after a
review by Codex: the commit's time in `SOURCE_DATE_EPOCH`, and the image
exporter with `push=true,rewrite-timestamp=true` instead of `push: true`
for all five images. Codex's points: the provenance attestation keeps
the build's own times, so the index around the image still differs; the
three MCP images have base images without digests, which the fix cannot
help.

## Caveats

- One machine and one builder, so not a cold rebuild everywhere, as the
  `WORKDIR` layer shows. The base images were pulled once.
- No provenance or SBOM. CI adds both as manifests of their own in the
  index, which were not compared.
- The frontend export was built after the commit, so its 990 files are
  later than the epoch and `P2` rewrote their times too (1117 entries
  against `P1`'s 123). CI downloads the export, which gives the files
  later times as well `[I]`.
- `APP_VERSION` is `v0.0.0-thesis`, not a tag's name.

## Not tested

- CI's cache itself (`type=gha`). The fix rewrites only times later
  than the epoch, so a cached layer from an earlier run would keep an
  older time. In the 22:41 check a new epoch reran every step that adds
  a layer to these two images, so none came from the cache `[I]` for
  `gha`.
- Pushing to a registry with `rewrite-timestamp`. The job ran on GitHub
  in the dry run later that night, with OCI output and no push, and gave
  the same two image manifests as `arch`
  ([phoenix-ci-dry-run](2026-10-13-phoenix-ci-dry-run.md)).
- The three MCP images.
