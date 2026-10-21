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
      runner the release would run a `dotnet-ef` from the pull requests'
      folder, which the check of 8 would report as not restored `[I]`.
      The migration job now has a CLI home of its own, and the check's
      `--tools` fails when a restored tool is not in the package folder.
- Added after the runs: `2cd85fd01`, the fix for what the dev
  container's test found (Result 10). The installer's tests, with a new
  L7, and the dev container's test ran again at it.
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

Verbatim in `data/2026-10-21-phoenix-pins/arch/kommando.txt`: the run
at `b3e0134ff`, 10:29-11:27, and the reruns after the fix, 11:33-11:37.
The outputs are in `results.txt`, the tools in `environment.txt`.

## Result

The numbers follow the expectation's.

1. actionlint exits 0, and the dependency page is up to date: 93 NuGet,
   160 npm, 10 images. `[V]`
2. L1-L6 as expected. `--record` writes the committed lock byte for
   byte. The network install carries runtime 10.0.12 alone. The install
   from the cache runs offline, and fails offline without it ("Network is
   unreachable", exit 1). The corrupt entry is downloaded again. Each of
   the six locks that do not fit stops it with exit 1 and its own
   message. The action's step passes on both kinds of runner, and only
   the self-hosted one keeps the archive. `[V]`
3. N2-N9 as expected. N1 tested nothing: `run.sh` ran the tests before
   `ci-local.sh` had cloned the tag into the sql folder, so N1 met the
   trial merge's clone of 20 October, which has no lock, and stopped
   ("no .../nuget-downloads.lock.json"). Run again after run 2, on the
   tag's own restore, all eight packages are ok, exit 0. In N9 the used
   home leaves the new package folder empty and runs `dotnet-ef` from
   `/tmp/dch/.nuget/packages`. The new home puts the three tools in the
   new folder and runs `dotnet-ef` from there. `[V]`
4. All six jobs pass in both runs: run 1 10:30-10:47, run 2
   10:47-11:13. In every .NET job of both runs the NuGet check gives 8
   ok, 0 not restored and 0 errors. The frontend's check names
   `@next/swc-linux-x64-gnu` 15.5.25 in both. Run 2 equals run 1: 1002
   of 1002 files by SHA-256, and the five images by manifest, config and
   every layer. `[V]` The three tools also count as ok in the jobs that
   do not restore them, because this lab's one package folder holds them
   from earlier restores. `[V]`
5. The export built with the install scripts equals run 1's, 995 of 995
   files. `[V]`
6. The MCP images at P4's clock: every layer equals P4's of 20 October,
   15, 12 and 11 of them. The configs differ only in their history, so
   the manifests differ too. `[V]` The history differs in more than the
   apt step. Each image has three more entries, empty layers for the `ARG`
   lines of the three hashes. Every `RUN` of the final stage from the
   apt step on records four build arguments where it recorded one.
   `[V]` (`oci-diff.py`, which now aligns the history)
7. The broker's build stops at the release-file check, exit 1, both
   times. With the wrong hash, `bookworm-security` fails and the other
   two pass. With the snapshot of 14 October, `bookworm-updates` and
   `bookworm-security` fail and `bookworm` passes. `[V]`
8. The signing image builds with the five versions expected, and keeps
   Ubuntu's own sources. `[V]`
9. A year ahead, `date -u` in the build gives 21 October 2027. The
   build tests of both images pass: the MCP server's build step with
   `npm test` (131.7 s), and the chat server's 40 test files with 542
   tests. `[V]`
10. The dev container's image builds. At `b3e0134ff`, D1-D3 fail:
    `install-sdk.sh` stops in the installer with "refusing .: outside
    the target". D4 gives 9.0.318, as expected. `[V]` The container's
    Python is 3.11.2, without `tarfile.data_filter` `[V]`, so the
    installer took its fallback. That fallback required each member's
    real path to start with the target and a separator. The archive's
    root entry, `.`, is the target itself, so every archive was refused:
    L7 on `b3e0134ff`'s installer refuses the SDK and all six test
    archives at `.`. `[V]`

    The fallback came in with the installer on 14 October
    (`62ac787a4`). Every Python known to have run it since has the
    filter: 3.14 on `arch`, and 3.12 on GitHub's Ubuntu 24.04. `[I]`
    The fix, `2cd85fd01`, came after these runs. A name or link target
    must be relative and have no `..`, and only files, folders and
    links pass. At the fix:
    - L1-L7 pass. In L7 the SDK installs from the cache through the
      fallback, the fine archive unpacks, and the five others are each
      refused by their reason. `[V]`
    - D1 installs 10.0.401 with runtime 10.0.12 alone. D2 takes it from
      the volume in 0.13 s. D3 finds it from a non-login shell. D4 still
      gives the image's 9.0.318. `[V]`

Codex (Sol, high) checked the two fixes. On `b3e0134ff`, the
tool-restore fix, it found no problem. On `2cd85fd01` it called the rule
sound for a target that starts empty, in any member order. The installer
refuses a target that is not empty (`install-dotnet-sdk.py:184`). `[V]`

## Interpretation

The pins cost no reproducibility. With every new check in the path, the
head builds each release output twice the same. The MCP layers equal
those of 20 October, so the release-file hashes changed only what the
images record about their build, not what they contain.

Each new check passes on the real inputs and stopped each wrong input
it was given: the SDK lock in L5, the NuGet packs and tools in N3-N5 and
N7, and Debian's release files in 7. Within what was tried, the checks
tell right from wrong, not merely run. The test with 14 October uses
real data: Debian's updates and security archives moved between the two
dates and its main archive did not. An old date fails at the release
files, before any package is installed, since `sha256sum -c` precedes
`apt-get install` in the same step (`mcp/Dockerfile:91-98`). `[V]`

That the export equals the one built with install scripts shows that
skipping them changes nothing for this lock. That none of them writes
what the build reads is an inference. `[I]` The two images' build tests
pass a year from now, so they are unlikely to stop a rebuild in that
time. Only one shift was tried. `[I]`

The dev container's failure is the one defect the runs found. The
fallback was code no run had reached, and only the first environment
with a Python without the filter exposed it. A self-hosted runner with
such a Python would have failed the same way, since the action takes
any Python from 3.8. `[I]` It was found by running the installer in
that environment, not by reading the code.

Codex's finding on the tools, which `b3e0134ff` fixes, cannot show in
this lab. Every job here has the same package folder, so a tool resolves
into it whatever the CLI's home (4). N9 shows the mechanism directly.
`[V]`

## Caveats

- Everything ran on `arch`. Neither GitHub's runners nor the office
  runner ran any of it. The workflows' new steps ran only as
  `ci-local.sh` imitates them, or as the action's step taken out of it
  (L6).
- `ci-local.sh` runs the release's commands, not the workflow. Where
  the branch changed a job, the script finds the new commands by
  searching the tag's workflow.
- The lab has one NuGet folder for all jobs (4). The release's own
  folder on the office runner is not imitated.
- N1 first ran on the wrong clone (3). It was rerun after run 2, on the
  restore the run's sql job made.
- Two tests changed after the expectation's commit. L7 was added. In
  the dev container test, the checks after an install are now grouped,
  so none runs after a failed install. Before that, D1's output at
  `b3e0134ff` showed dotnet's error after the failed install. The
  checks are unchanged.
- L7 hides the filter from the installer on the host's Python. Python
  3.14's own `extractall` still applies its default filter when the
  fallback unpacks. The fallback's `extractall` on a real old Python ran
  only in the dev container (D1), on the SDK archive.
- The builds were not run again at `2cd85fd01`. It changes only the
  installer's fallback, which no build output contains and
  `ci-local.sh` does not run. `[I]` Its own outputs differ from
  `b3e0134ff`'s anyway, by the commit hash and time they carry. `[I]`
- Inside the WebAPI and job worker Dockerfiles, the restore takes the
  runtime packs without the check. They do not reach the images, whose
  final stages copy only the publish output. `[I]`
- The dev container's image was built without the `ws` CLI. Its
  download, from WS.CLI, answers 404 from outside WS. That predates the
  branch.
- The labs of these runs were removed from `arch` the same day, after
  the results were written, to free disk: `/private/tmp/rb1-pins`, the
  job clones in `/private/tmp/rb1-ci`, `/private/tmp/rb1-sdk-tests-3` and
  the dev container's test image. The outputs and logs are in the
  private data.

## Not tested

- The release workflow on GitHub with a test tag. That is Leo's call.
- CI's .NET test tiers and the frontend's tests at the head. The trial
  merge's tree passed the test tiers on 20 October. No C# file has
  changed since the merge. In the project files, only `WebAPI.csproj`'s
  publish target changed, which now runs `npm ci --ignore-scripts`. The
  release skips that step in every publish and image build
  (`SkipSpaBuild`, `SKIP_SPA_BUILD`).
- arm64: Node's arm64 hash, canvas's arm64 prebuilt, Next's arm64
  compiler.
- Windows: the installer's zip path, and the NuGet check in the
  release's Windows job.
- macOS: the installer with Apple's Python 3.9.6, which takes the
  fallback, and the members of the osx archives.
- The office runner's Python: whether it has the filter.
- `docker-build-push.sh`, which needs a registry login.
- The SBOM generator's pin in a release. It was tried only on a
  one-file image, while writing.
- A shift of the clock other than a year, and build tests in the other
  images.
