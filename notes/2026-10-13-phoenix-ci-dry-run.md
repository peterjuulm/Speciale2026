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

## Result

`[V]` (the run's logs and artifacts, the local rebuild and
`compare.txt`, in private data; `results.txt` beside `kommando.txt`). The run
20:57-21:19 UTC, the local rebuild 22:57-23:08:

1. Held. All five jobs passed. The migrator's smoke test applied all 160
   migrations to each of its two databases, and refused to run without a
   connection string. The images were rewritten to the commit's time in
   CI too: the build log names the epoch.
2. Held. CI's frontend export and the local one: the same 994 files.
3. Failed. Every zip differs from its local twin, and both migrators do
   too, in 225 and 226 bytes. In each zip 6 files differ, all ours: the
   three assemblies of that program and their PDBs. The other entries are
   the same, 1618 of 1624 in the WebAPI's Linux zip. Each PDB differs in
   one field, the `runtime-version` its compilation options record:
   `10.0.13` in CI, `10.0.12` here. Same compiler, `5.9.0-1.26423.113`.
   The assemblies differ only in what is derived from the PDB and the
   content: the MVID, the PE timestamp and the debug directory.
4. Held. Both images have the same image manifest in CI and here: WebAPI
   `79bc623e…`, job worker `af5aa102…`. CI's indexes, with provenance and
   SBOM, are `e575f6fd…` and `d9ee4f61…`.

Where `10.0.13` comes from `[V]`: `actions/setup-dotnet` v6 first
installs the newest LTS runtime, then the SDK from `global.json`
(`install-dotnet.sh --runtime dotnet --channel LTS` in the job log;
`src/installer.ts` lines 418-425 at `v6`). Runtime 10.0.13 was the newest
on 13 October. The SDK's compiler asks for runtime 10.0.12 and may roll
forward (`csc.runtimeconfig.json`: `"version": "10.0.12"`,
`"rollForward": "Major"`), so it ran on 10.0.13. Here the SDK folder holds
only its own runtime.

A check after the result, with no expectation written first, 23:35-23:39:
Microsoft's runtime 10.0.13 (released 13 October, SHA-512 checked against
the release metadata) added to a copy of the SDK folder, and the Linux,
Windows and migrator jobs rebuilt with it. All six outputs are byte for
byte CI's: both Linux zips, both Windows zips and both migrators.

A second check, 23:44-23:52, also without an expectation written first:
does `DOTNET_ROLL_FORWARD=Disable` keep the compiler on the SDK's own
runtime with 10.0.13 present? `ApplicationCore` built alone with
`--no-incremental` in the Linux job's clone: with the variable its PDB
says `10.0.12`, without it `10.0.13`. A first try without
`--no-incremental` reused the first build's output and showed `10.0.13`
both ways; it is discarded. The variable also reaches every other .NET
program in a step, and `dotnet-ef` asks for runtime 8.0.0
(`dotnet-ef.runtimeconfig.json`), which `Disable` would demand exactly.

Cleanup, 21:32 UTC: the run with its artifacts deleted, the tag deleted,
no cache or deployment created. While checking, 83 caches from the test
tag of the morning turned up (3.1 GB of Docker build cache on
`v0.0.0-thesis.1`), with the repository's caches at their 10 GB limit;
they were deleted too. The morning run's deployment record in
`release-signing` stays as its record.

## Interpretation

**Across machines, the release is the same but for one recorded
fact.** `[V]` for GitHub's runner and `arch`: the frontend, every
third-party file and both images are identical, and our assemblies
differ only in the runtime patch the compiler ran on. With that patch
installed here, every output of the run is reproduced byte for byte.

**`global.json` pins the SDK, not the runtime its compiler runs on.**
`[V]` for this run. The PDB records that runtime, so a build in CI
differs from the one before it whenever setup-dotnet finds a new runtime
patch, here the day it shipped `[I]`. A rebuild has to run its compiler
on the same patch. Two fixes would remove it; neither is made. Only the
SDK from `global.json`, in a folder of its own, as in the SDK image and
this lab: then the compiler can only run on the SDK's own runtime. Or
`DOTNET_ROLL_FORWARD=Disable` on the build steps, which works for the
compiler (the 23:44 check) but which Microsoft's documentation keeps for
testing, and which would break `dotnet ef` in a step that runs both. The
first is the sounder `[I]`. Either changes how CI installs or runs .NET,
for Leo and Peter to choose.

**The images do not take the runner's .NET; the zips do.** `[V]` The
images' compiler runs in the SDK image, not on the runner's .NET: the
WebAPI image's `ApplicationCore.pdb` is the same file from CI and from
here, and records runtime `10.0.12` (checked after Codex's check of this
note, at 00:09 on 14/10 with `oci-file.py`). With the timestamp fix
(`fa60ea97`) both images were
the same on the two machines. Their builds are not hermetic: they still
download the base images and the NuGet packages.

**The two kinds of release output carry different versions.** `[V]`
The zips' assemblies say `v0.0.0-thesis.2+2ec8e0ca…`: the SDK adds the
commit in a git checkout. The images' say `v0.0.0-thesis.2`, as
`.dockerignore` keeps `.git` out of the build context.

## Caveats

- One run, one runner image (`ubuntu-24.04`, `20261004.327.1`), one
  day. The local side used the same SDK tarball and caches as the other
  runs on `arch`.
- The dry run is not the release: no tests, no signing, no MCP images,
  no push, no cache. Signing would change every Windows binary anyway.
- The migrators were compared as whole files. That their 225 bytes are
  the same three assemblies' IDs is `[I]`.
- buildx differed (0.37.2 in CI, 0.38.0 here); BuildKit was 0.33.1 on
  both.

## Not tested

- Either fix for the runtime, and the release with signing and pushes.
- The Windows outputs after signing.
