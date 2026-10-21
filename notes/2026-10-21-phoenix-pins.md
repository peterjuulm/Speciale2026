# The branch's remaining pins, checked (21 October 2026)

Grounds: the WS branch as it is to be pushed on 21 October, after main
was merged in for real and the pins left open on 20 October were added,
built and tested on `arch`. Leo asked for both that morning, with Codex
to check the work. Done and run by Claude.

## Question

Main is merged in and every input the analysis of 20 October found
unpinned is now pinned or checked. Does the branch still build every
release output twice the same, and does each new check pass on the real
inputs and stop a wrong one?

## Setup

- The merge, `1b9659554`: the same tree as the trial `7e90bad9`, built
  twice and tested on 20 October
  ([phoenix-merge-trial](2026-10-20-phoenix-merge-trial.md)).
- After it, one commit each:
  1. The dependency page regenerated. Main's change to its check (#805)
     fails a page whose versions differ from the project files, and the
     branch's .NET 10 packages and image digests did.
  2. The migrator's smoke test on a port Docker picks. Since the merge
     the job runs on the office runner, where a fixed port collides.
  3. The MCP images: the SHA-256 of the three Debian release files at
     the snapshot time, checked after `apt-get update`
     ([phoenix-mcp-pins](2026-10-20-phoenix-mcp-pins.md) pinned the time).
  4. The SBOM scanner by tag and digest: `buildkit-syft-scanner` 1.12.0,
     which runs syft 1.51.0, as the reference release's SBOM records.
  5. GitHub's own actions by commit, as the third-party ones were.
  6. The release's GitHub runners by image: `ubuntu-24.04` and
     `windows-2025`, what `-latest` gave the release of 16 October.
  7. The SDK from a lock beside `global.json`, `dotnet-sdk.lock.json`:
     each archive's URL and SHA-512, recorded from Microsoft's metadata
     by the installer's `--record`. The installer reads only the lock,
     so a cached archive installs offline, and it checks that the
     unpacked SDK carries the lock's runtime and no other.
  8. The NuGet packages no lock file pins, checked after each restore
     against `nuget-downloads.lock.json`: the five runtime and apphost
     packs a restore takes through `PackageDownload` (W21), the apphost
     pack a Windows host takes instead, and the three tools, each by the
     SHA-512 of its whole `.nupkg` as nuget.org serves it.
  9. Node by hash: the frontend job installs the `.nvmrc` version from
     nodejs.org against `node.sha256`, which the WebAPI Dockerfile reads
     too. `npm ci` runs without the packages' install scripts, and a
     check before `next build` stops it unless Next's locked native
     compiler loads at Next's version.
  10. The dev container: the SDK `global.json` names, from the lock.
  11. `docker-build-push.sh` on the release's BuildKit.
  12. The signing image from Ubuntu's snapshot archive, its three release
      files pinned as in 3.
  13. The release's tools restored into its own package folder. Codex's
      review of 1-12 found that `dotnet tool restore` skips a tool the
      resolver cache in the CLI's home already points at, so on the office
      runner the release ran a `dotnet-ef` from the pull requests' folder,
      which the check of 8 reported as not restored. The migration job now
      has a CLI home of its own, and the check's `--tools` fails when a
      restored tool is not in the package folder.
- Each check was tried once while it was written: the installer offline
  from its cache, the NuGet check on the trial's restore, the signing
  image's build, the SBOM flag on a one-file image. The runs below start
  after this expectation is committed.
- `ci-local.sh` now follows each tag's own workflow where the branch
  changed it: `--ignore-scripts` and Next's switches when the tag's
  frontend job has them, the NuGet check after each .NET restore when
  the tag has the script. The same tools as on 20 October
  (`environment.txt`).
- New test scripts in `experiments/phoenix-rt/`:
  `installer-lock-tests.sh`, `nuget-check-tests.sh`,
  `faketime-tests.sh`, `devcontainer-test.sh`.

## Expectation, written before the runs

1. actionlint finds nothing in the workflows, and the dependency page is
   up to date.
2. The installer: `--record` writes the committed lock again, byte for
   byte (L1). An install from the network carries runtime 10.0.12 alone
   (L2). An install from a filled cache runs without network; without the
   cache it fails offline (L3). A corrupt cache entry is downloaded again
   (L4). Each lock that does not fit stops it with exit 1: another
   version, no linux-x64 archive, a malformed hash, another hash (after
   the download), another runtime (after unpacking), no lock (L5). The
   action's step passes on both kinds of runner and keeps the archive
   only on a self-hosted one (L6).
3. The NuGet check passes on the trial's restore and on its copy (N1, N2),
   and fails naming the package on a runtime pack with another hash, on a
   pack the lock does not name, and on a tool with another hash (N3-N5).
   A tool not restored passes as "not restored" (N6), and fails with
   `--tools` (N7). Without a restore it stops (N8). Tool restore with the
   home of the earlier restores leaves the new package folder empty and
   keeps `dotnet-ef` in the old one; with a new home the tools land in
   the new folder and run from there (N9).
4. `ci-local.sh` twice: all six jobs pass in both runs. The NuGet check
   passes in the four .NET jobs, with `--tools` in the sql job, the
   frontend's check names `@next/swc-linux-x64-gnu` 15.5.25, and run 2
   equals run 1: the 1002 files by SHA-256, and the five images by
   manifest, config and every layer.
5. The frontend export built with the install scripts equals the one
   built without, file for file. The scripts in the lock print banners
   or look for binaries npm already installed; none writes what the
   build reads.
6. The MCP images, built at P4's clock (`SOURCE_DATE_EPOCH` 1791961346):
   every layer equals P4's of 20 October, since nothing under `mcp/` but
   the three Dockerfiles changed and the packages come from the same
   snapshot. The configs differ, in the history of the apt step that now
   carries the hashes, so the manifests differ.
7. The broker's build stops at the release-file check: with a wrong hash
   for `bookworm-security`, that file fails; with the snapshot of 14
   October against the hashes of 20 October, `bookworm-updates` and
   `bookworm-security` fail and `bookworm` passes. On snapshot.debian.org
   the first two release files moved between the two dates and the third
   did not.
8. The signing image builds, with the versions of the build tried while
   writing: osslsigncode 2.13-1, openjdk 21.0.12.1+1-1~26.04.4, python3
   3.14.3-0ubuntu2, curl 8.18.0-1ubuntu2.8, ca-certificates
   20260601~26.04.1; the image keeps Ubuntu's own sources.
9. A year ahead (`faketime +365d`), the MCP server's and the chat
   server's build tests pass. No test is known to read the date; a
   failure names a test that will break a later rebuild.
10. The dev container's image builds. On the branch, `install-sdk.sh`
    installs SDK 10.0.401 with runtime 10.0.12 (D1), a new container
    takes it from the volume without a download (D2), and a non-login
    shell finds it (D3). On main before the branch, without the lock,
    `dotnet` is the image's SDK, 9.0.318 (D4).

## Commands

Verbatim in `data/2026-10-21-phoenix-pins/arch/kommando.txt`.

## Result

## Interpretation

## Caveats

## Not tested
