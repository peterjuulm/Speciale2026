# The release workflow on GitHub against a local rebuild, 13 October 2026

## Question

Two questions in one run. Does the release workflow run on GitHub's
runners with the WS branch as it is tonight (`fa60ea97`): after the merge
of main, the developers' fixes, the packing script and the images'
timestamps? And do its outputs equal a local rebuild of the same commit,
byte for byte? The second is the release's first comparison across
machines: GitHub's `ubuntu-latest` against `arch`. The cross-machine
axis has waited for a VM since September (W14).

## Setup

Run by Claude at Leo's request, on Leo's conditions for runs on GitHub:
one run, nothing anyone could use or deploy, and as few traces as
possible.

A throwaway commit on `fa60ea97` changes only the three workflow files,
with a script kept in private data, as it quotes the workflows:

- No `build-and-test` and no `release` job, so no tests and no GitHub
  Release.
- `docker-images`: no registry login and no push. The two .NET images
  are written as OCI tarballs with `rewrite-timestamp=true` and uploaded
  as artifacts, kept one day. No `gha` cache, and the three MCP images
  are left out.
- `publish-windows` on `ubuntu-latest`, not WS's office runner, without
  the `release-signing` environment and the three signing steps. The
  Windows binaries stay unsigned.
- The frontend job without its npm cache, and its export kept one day.

The tag `v0.0.0-thesis.2` on that commit starts the run; only the tag is
pushed, and no branch. Afterwards the run, its artifacts and the tag are
deleted, after its logs and artifacts are kept in private data.

The local side is `experiments/phoenix-rt/ci-local.sh`. It rebuilds each
job from its own shallow clone of the tag, with `origin` set to the URL
`actions/checkout` uses, so Source Link and the SDK get the same commit
and repository URL as in CI. It uses the jobs' commands and settings
(`APP_VERSION` from the tag, `LC_ALL` where the job sets it,
`GITHUB_ACTIONS=true` for the locked restore), the SDK 10.0.401
tarball, Node 22.23.3, the offline NuGet and npm caches, and the lab's
Info-ZIP 3.0. The images are built as the dry run builds them, without
attestations.

## Expectation, written before the run

All `[I]`.

1. Every job succeeds, the migrator's smoke test included.
2. CI's frontend export equals the local one, file for file.
3. The Linux and Windows zips and both migrators from CI equal the local
   ones byte for byte, given the same commit, URL, version, SDK and
   packages. The zips might still differ through the zip program: CI's is
   Ubuntu's Info-ZIP 3.0, the lab's another build of 3.0. If so, the
   files inside are still the same.
4. The two images from CI have the same image manifest digests as the
   local builds. Their indexes differ, as CI adds provenance and an SBOM.

## Commands

Verbatim in `data/2026-10-13-phoenix-ci-dry-run/arch/kommando.txt`.
