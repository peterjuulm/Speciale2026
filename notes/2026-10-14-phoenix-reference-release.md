# A real pre-release, checked by an independent rebuild (14 October 2026)

Grounds: the release workflow on GitHub, run unmodified at a tag on the
WS branch, and a rebuild on `arch`. Leo's go, 11:16. Codex (Astra)
reviewed the plan first (private data, `codex-rc-review.md`).

## Question

Does a real release of the branch, signed through WS's Azure signing
and pushed to GHCR, come out the same in an independent rebuild? Every
output: the zips, the migrators, the SQL script, `upgrade.sh`,
`SHA256SUMS`, and the five images by their `linux/amd64` manifest.

## Setup

- `be5fc56e`, the branch head, with every measurement of 13-14/10 on
  it. Tag `v0.0.0-thesis.6`, annotated as WS's release tags are: below
  every product version, and a pre-release by its hyphen, so the GitHub
  Release is marked as one and `:latest` stays put. Production deploys
  refuse `latest` and take an exact tag.
- First a preflight: the release's own `build-and-test` job, alone, on
  GitHub's hosted runners, from a throwaway commit pushed only as the
  tag `v0.0.0-tests.1`. The job failed there on 13/10 (the 678
  integration tests, before the merge), and no dry run since ran it.
- `:latest` before the tag, from GHCR's package API: `v1.0.50` for all
  five images (index digests in the data folder).
- Before the tag, Leo asked whether the Linux jobs should first move to
  the office runner, where the Windows job runs. Tagging unchanged was
  advised, Codex agreeing: a baseline of the release as WS runs it now,
  with the move left to a later change of the workflows.
- The rebuild on `arch` alongside the run, with `ci-local.sh` at the
  tag: `APP_VERSION=v0.0.0-thesis.6`, `SOURCE_DATE_EPOCH` the commit's
  time (1791961346), from a git checkout, so the assemblies carry the
  commit as on GitHub.

## Expectation, written before the run

Written 11:21.

Preflight:

0. `build-and-test` passes on GitHub's hosted runners: the Linux leg's
   unit, integration and functional tests, and the Windows leg's build.

Release:

1. Every job passes. The Windows job signs 177 files through Azure, on
   the office runner, and its paste check passes there. The GitHub
   Release is a pre-release with both Linux and both Windows zips, the
   migrator bundles and SQL script, `SHA256SUMS` and `upgrade.sh`.
   `:latest` keeps its digest for all five images.
2. The rebuild gives the Linux zips, the Linux migrator, the SQL script
   and `upgrade.sh` byte for byte; the Windows zips and migrator byte
   for byte once the release's signatures are pasted; `SHA256SUMS`, made
   from those files, equals the published one.
3. Each image's `linux/amd64` manifest equals the local build's; the
   indexes differ by their attestations (W65). An MCP image may differ if
   Debian changed a package between the two builds; then the packages
   are compared first.
4. The signatures name WS's certificate and carry RFC 3161 timestamps.

## Commands

Verbatim in `data/2026-10-14-phoenix-reference-release/arch/kommando.txt`.

## Result

`[V]` (`results.txt`, `environment.txt`, `latest-before.txt` and
`latest-after.txt` in the data folder; the runs' logs and artifacts, the
downloaded release and the rebuild in private data). The preflight ran
09:20-09:51 UTC, the release 09:53-10:21 UTC, and the rebuild on `arch`
11:53-12:12 local time, all six jobs in 19 minutes.

0. Held. Both legs passed. The Linux leg executed 4681 unit, 807
   integration and 153 functional tests, and none failed.
1. Held. All eight jobs passed. The Windows job ran on the office
   runner, where the branch's SDK installer set up 10.0.401 for the
   first time. Of 1048 Windows binaries, 871 were already signed and 177
   were signed through Azure, all in the first attempt. The job's own
   paste check passed: 2130 files, 114 folders. The GitHub Release is a
   prerelease with nine assets, and `:latest` kept its digest for all
   five images.
2. Held. Byte for byte: the frontend export (994 files), both Linux
   zips, the Linux migrator, the SQL script and `upgrade.sh`. With the
   release's 177 signatures pasted onto the rebuild, both Windows zips
   and the Windows migrator too. A `SHA256SUMS` made from the rebuilt
   files equals the published one. The published one checks out against
   the downloaded assets, and they equal the run's artifacts.
3. Held, and the Debian caveat did not arise. All five images'
   `linux/amd64` manifests equal the local builds', the three MCP images
   included. CI built its images in the same 20 minutes as `arch`, so
   the archive had no time to move. Each release tag points at the same
   index as its `-build` tag, so the promotion kept the attestations.
4. Held. All 177 signatures verify against Microsoft's root, name WS's
   company certificate and carry a timestamp. Three were also checked
   against the timestamp authority's CRL.

## Interpretation

**A real release of the branch can be rebuilt.** `[V]` for this
release. Every output a customer can get came out the same on `arch`:
both platforms' zips, the migrators, the SQL script, the checksums and
the five images. `arch` shares with GitHub's runners and the office
runner what the branch declares, the SDK, Node, the lock files and the
base images by digest, and a few tools matched to CI's by hand, BuildKit
among them (`environment.txt`). The Debian packages of the MCP images
came from the live archive, at the same time.

**Three machines, one result.** `[V]` The Linux outputs and the images
were built on GitHub's runners, the Windows outputs on WS's office
runner. All of them equal the rebuild on `arch`.

**The real signature does not stand in the way.** `[V]` The release's
signatures, cut from the signed files and pasted onto the unsigned
rebuild, give the release's bytes for all 2130 files, as with the test
certificate on 14/10 (W59). The release job runs the same check on its
own output, and it passed there too.

**What this closes.** The items the dry runs left open: a release signed
through Azure, a push to GHCR and its promotion, `SHA256SUMS` compared,
and the branch's Windows job on the office runner, its SDK installer
included. `[V]`

## Caveats

- One release and one rebuild, made at the same time. A later rebuild
  can meet a changed Debian archive (the MCP images) and a moved
  `stable-1` tag for the SBOM's scanner (W65). Neither was tested here.
- The signer was checked by the certificate's subject and its chain to
  Microsoft's root, not by its thumbprint against WS's signing account.
- The rebuild used the tool versions CI used, the declared inputs. It
  shows the outputs follow from those inputs, not that other SDK patches
  give the same bytes (W58 showed they do not).
- The NuGet and npm caches on `arch` were warm from earlier runs. The
  packages are pinned by the lock files' hashes.
- For this commit no host copy of the frontend existed on the office
  runner, as Main CI never built it. The run shows the fixed Windows job
  downloads the release's export there; the old shortcut would also have
  found nothing to take.

## Not tested

- A rebuild days or weeks after the release.
- The content of the pushed attestations. Only their digests and the
  promotion were checked; W65 compared one image's attestations locally.
- Installing or running the release.
- A release with the Linux jobs on the office runner.

## What the release leaves

The prerelease, its tag and the image tags (`v0.0.0-thesis.6` and
`v0.0.0-thesis.6-build` for each image) stay, as the reference. The
run's 50 caches, 4.94 GB under the ref
`refs/heads/refs/tags/v0.0.0-thesis.6`, are deleted: they count toward
the repository's cache quota, and only a run on that tag could restore
them. The preflight's run, tag and caches are deleted too.
