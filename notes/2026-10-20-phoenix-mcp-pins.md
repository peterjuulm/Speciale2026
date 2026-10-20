# The MCP images' last two loose inputs, pinned (20 October 2026)

Grounds: builds on `arch` of the WS branch with the change, compared with
the same day's rebuild of `v0.0.0-thesis.6`
([phoenix-delayed-rebuild](2026-10-20-phoenix-delayed-rebuild.md)). Leo
asked for the fixes on the branch the same evening, with as many builds as
needed. Run by Claude.

## Question

The three MCP images still take two inputs that nothing pins. Does pinning
both keep the images as they are, make two builds the same, and make the
date of the Debian archive decide the packages?

## Setup

- W67: the three images install Debian's packages from the live archive.
  Over six days nothing they install changed (the delayed rebuild), though
  the security archive's index did. The Dockerfiles said it themselves:
  two builds give the same image only while the archive has not changed
  the packages.
- W68: canvas, which the MCP server uses to draw charts, has an install
  script that downloads a prebuilt binary from GitHub without a checksum,
  and compiles another one when the download fails. The image's
  `canvas/build` is file for file the release asset
  `canvas-v3.1.2-napi-v7-linux-x64.tar.gz`, SHA-256 `4b0c6d81…`, the
  same digest GitHub lists for it.
- The change, on the WS branch: each MCP Dockerfile names a date on
  snapshot.debian.org and installs through a sources list of its own in
  `/tmp`, so the image keeps the base's sources. The canvas prebuilts for
  x64 and arm64 are added by their SHA-256, `prebuild-install` is pointed
  at them, and its download host at an address that answers nothing. The
  build stage's compiler and `-dev` packages go, as nothing compiles
  there any more; a missing prebuilt then fails the build.
- The builds: the three images with the release job's flags, as
  `ci-local.sh` builds them, from a fresh clone of the commit in
  `/private/tmp/rb1-pin`, with `SOURCE_DATE_EPOCH` set to
  `v0.0.0-thesis.6`'s commit time (1791961346), so their layers can be set
  against the same day's rebuild of that tag.

## Expectation

Written 16:40, while the rounds ran (16:33-16:41), and not all of it
before the results. The comparison files' times show P1 compared with the
unpinned build at 16:36 and with P2 at 16:39, so items 1, 2 and 4 were
written knowing those results. Only item 3 came before its comparison,
at 16:41. (Corrected the same evening, after Codex's check of the note;
the heading said "written before the runs".)

1. P1, the snapshot of `20261020T000000Z`: every layer of each image
   equals the layer of the same day's unpinned build. The configs differ
   in their history, which holds the changed `RUN` lines, so the
   manifests differ.
2. P2, P1 again: the same manifest for each image.
3. P3, the snapshot of `20260101T000000Z`: the builds pass, though the
   security archive's release file of that date has expired. The apt
   layer differs from P1's and holds older versions; the other layers
   are P1's.
4. P1 succeeding at all shows `prebuild-install` took the local file: the
   blocked host leaves no download, and the build stage has no compiler.

## Commands

Verbatim in `data/2026-10-20-phoenix-mcp-pins/arch/kommando.txt`.

## Result

`[V]` (`results.txt` and `environment.txt` in the data folder; the images,
their logs and the comparisons in private data). P1-P3 ran 16:33-16:41,
about two and a half minutes a round.

1. Held. In all three images every layer of P1 equals the unpinned
   build's: 15, 12 and 11 layers. The configs differ in their history
   only, where the changed `RUN` lines are, so the manifests differ.
2. Held. P2 gives P1's manifest for each image.
3. Held. The builds pass with the snapshot of 1 January, though its
   security release file has expired. The apt layer differs from P1's,
   and every other layer is P1's. The MCP server image has 12 of its 135
   packages at older versions, among them `openssl` and `libssl3`
   (3.0.17-1~deb12u3 against 3.0.22-1~deb12u1) and `ca-certificates`
   (20230311+deb12u1 against 20250419~deb12u1); the chat server and the
   broker, whose apt layers are one and the same layer, have those three.
   The files in only one of the two layers are all certificates: 63 in
   P1's, 39 in P3's.
4. Held. P1 passed with the download host blocked and no compiler in the
   build stage, and its `canvas/build` sits in a layer equal to the
   unpinned build's, whose files are the release asset's.

Codex reviewed the change after P3. Two of its points are closed on top
(`82d35f9df`). `apt-get update` exits 0 when an index fails to download,
and `install` then takes what the other indexes offer: in the base image's
apt 2.6.1, a source that does not answer gave exit 0, and 100 with
`--error-on=any`, now on all three `update` lines. And the MCP server's
build stage checks that a prebuilt for its architecture is there before
`npm ci`. P4-P6 ran on that commit, 16:50-16:57, without an expectation
written beforehand; they check that the guards change no layer:

- P4 against P1: every layer the same in all three images; the configs
  differ in one history line, the `RUN` that changed.
- P5 against P4: the same manifest for each image.
- P6, the snapshot of 1 January again, against P3: every layer the same,
  the configs again differ in that one line.

The image's history names the snapshot: each `RUN` after the `ARG` is
recorded as `RUN |1 DEBIAN_SNAPSHOT=20261020T000000Z …`, so the date can
be read back from a pushed image.

The same evening the release job's BuildKit was pinned too (`56e4b4820`):
`setup-buildx-action` started `moby/buildkit:buildx-stable-1`, a tag that
follows BuildKit's releases, and now starts `v0.33.1` by digest. The
release run of 14/10 logged `BuildKit version: v0.33.1`, and this builder
runs v0.33.1 too. No build ran with another version.

## Interpretation

**The pins move both inputs into the Dockerfiles without changing the
images.** `[V]` P1 has the unpinned build's layers, and P1 and P2 give
one manifest. Only the configs' history changes, because it records the
commands.

**The archive's date now decides the packages, and only the apt layer.**
`[V]` P3 and P6 show that another date gives other packages, in that one
layer. A rebuild of a release gets the release's packages as long as
snapshot.debian.org serves its date `[I]`. Moving the date is then a
change in the repository, reviewed like any other, rather than something
the archive does between two builds.

**The canvas binary is now an input with a hash.** `[V]` for the files:
the prebuilt in the image is the asset whose SHA-256 the Dockerfile
names. Before, it was the file GitHub served that day, or a binary
compiled in the build stage when the download failed.

**What a date on snapshot.debian.org does not pin.** `[I]` apt checks
the release files' signatures, but with the expiry check off, which an
older snapshot needs, not their dates. The build trusts the service to
serve the date it is asked for. Pinning the release files' hashes as well
would close that, at the cost of a longer bump.

## Caveats

- One machine and one builder, the same as the delayed rebuild's.
- P1's date is the day of the build, and Debian's archive had not changed
  what these images install for six days (the delayed rebuild). P1
  against the unpinned build shows that the pin keeps the images as they
  were; P3 and P6 show that it holds the packages to a date.
- The npm cache mount was warm. `npm ci` checks every package against the
  lock's integrity hash either way.
- The arm64 prebuilt is checked by its digest only; no arm64 image was
  built.

## Not tested

- An arm64 build, and the new check failing in a build. Only its input
  was looked at: `node -p process.arch` in the base image gives `x64`,
  the name the x64 prebuilt's file carries.
- The release workflow on GitHub with the BuildKit pin.
- How often snapshot.debian.org is slow or down. A failed download now
  fails the build, with five retries first.
