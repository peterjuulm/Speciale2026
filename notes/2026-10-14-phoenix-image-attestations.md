# What the release's image tags point at (14 October 2026)

Grounds: the dry run's image files of 14/10
([phoenix-ci-dry-run](2026-10-14-phoenix-ci-dry-run.md), run 1), and
two builds on `arch` described below.

## Question

The release job pushes each image with `provenance: true` and
`sbom: true`. Do two builds with those settings give the same image but
a different index, which is what the tag points at? Which fields of the
provenance and the SBOM differ?

## Already seen, before this run

From the dry run's files (run 1: CI's image files and the local
rebuild's, in private data) `[V]`:

- For all five images, CI's image manifest equals the local rebuild's:
  `6c225e6b…` WebAPI, `071244c8…` job worker, `d409dd82…` MCP server,
  `7925a643…` chat server, `54d198f6…` authorization broker.
- CI's file wraps each image in an index with a second entry, an
  attestation manifest with two statements: an SPDX 2.3 SBOM made by
  syft 1.51.0 through `docker/buildkit-syft-scanner:stable-1`, a tag,
  not a digest; and SLSA provenance v1. The local rebuild made neither,
  so its file holds the image manifest alone.
- The provenance holds `startedOn` and `finishedOn`, the build's own
  clock times, not `SOURCE_DATE_EPOCH`; an `invocationId`;
  `builder.id`, the workflow run's URL; and among its internal
  parameters the run's id, number and attempt, the runner's name and
  the event payload. The SBOM holds its creation time and a namespace
  ending in a UUID.

## Setup

- The MCP authorization broker image, the smallest of the five. Its
  base is pinned by digest; it installs `ca-certificates` from Debian's
  live archive and its packages from npm, by its lock file.
- Source: `3c375938`, the dry run's run 1 commit before its workflow
  edit (`mcp/` is the same in `be5fc56e`), in a fresh clone on `arch`.
- Builder `rb1`, docker-container driver, BuildKit v0.33.1: the version
  CI's SBOM names. `SOURCE_DATE_EPOCH=1791955202`, run 1's commit time.
  `--no-cache`, `--provenance=true --sbom=true`, output
  `type=oci,rewrite-timestamp=true` as in the dry run: the same index as
  a push, without a registry.
- Compared with `experiments/phoenix-rt/attest-compare.py`: the image,
  the index, the attestation manifest, and the paths of the differing
  fields, without their values.

## Expectation, written before the run

Written 10:35.

1. The two builds give the same image manifest, `54d198f6…`, CI's. If
   Debian has changed `ca-certificates` since 05:44 UTC, they still
   equal each other.
2. Their attestation manifests differ, so their indexes differ too.
3. In the provenance, only `invocationId`, `startedOn` and `finishedOn`
   differ. In the SBOM, only the creation time and the namespace differ.

## Commands

Verbatim in `data/2026-10-14-phoenix-image-attestations/arch/kommando.txt`.

## Result

`[V]` (`compare-b1-b2.txt`, `compare-ci-b1.txt`, `attest-layers-b1-b2.txt`
and the image files' hashes in the data folder; the build logs in
private data). The builds ran 10:52:27-10:53:02, about 20 s each.

1. Held. Both builds give the image manifest `54d198f6…`, and so does
   CI's file.
2. Held. The attestation manifests differ (`bc35ea91…`, `55f43a85…`),
   and so do the indexes (`e369ebad…`, `36e1e96f…`; CI's is
   `cefe865b…`).
3. Held for the SBOM, not for the provenance. In the SBOM, 2 of 55874
   fields differ, the creation time and the namespace, between the two
   builds and between CI's and the first. In the provenance, 56 of 476
   fields differ. Three are `invocationId`, `startedOn` and
   `finishedOn`. The other 53 are BuildKit's own record: 16 digests and
   11 sizes of the layers each step made, and 26 entries of two digest
   mappings. The provenance names 11 layer digests. The 6 that are the
   same in both builds are in the image manifest; the 5 that differ are
   not. CI's provenance differs from the first build's in 256 of 671
   fields, among them every `github_*` parameter, which a local build
   does not have.

## Interpretation

**The image can be rebuilt; the tag cannot.** `[V]` for this image. The
tag points at an index of the image and an attestation, and the
attestation describes one build: its clock times, a random ID, the
run, and the layers as BuildKit made them before `rewrite-timestamp`
lowered their times. Two builds that give the same image give
different indexes, so a check of the tag's digest always fails. The
digest to compare is the image manifest's, the tag's `linux/amd64`
entry. The attestation is set aside, as the Windows release's
signature is (W59). For the other four images it is `[I]`: their
attestations are made the same way.

**The epoch does not reach the attestations.** `[V]` `startedOn` and
`finishedOn` are the build's clock, and the layer digests the
provenance names are those from before the rewrite.

**The SBOM is reproducible but for two fields.** `[V]` Its content is
the same in three builds, CI's among them. Its maker is pulled by a tag
(`stable-1`), so a later rebuild may run another syft and get other
content `[I]`.

## Caveats

- One image, one machine, two builds 20 s apart. The other four images
  were not built with attestations here.
- Image files, not a registry: that a push stores the same index is
  `[I]`; BuildKit builds one index for both outputs.
- Why the two digest mappings differ is not established; that they
  follow from the layers as built is `[I]`.

## Not tested

- A push to a registry, and the release's separate signed
  build-provenance attestation, which the dry run cut.
- Whether a BuildKit or buildx option leaves the build's times and IDs
  out of the provenance.

