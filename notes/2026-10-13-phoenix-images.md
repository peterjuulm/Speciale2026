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
