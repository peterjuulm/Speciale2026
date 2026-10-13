# The Windows release, built twice on Linux, 13 October 2026

## Question

Since the merge of main, the release builds its Windows programs on a Linux
runner: the reusable Windows job restores the solution locked, publishes the
WebAPI, the job worker and the migrator for `win-x64`, signs the Windows
binaries in a container, and packs two zips with
`scripts/pack-release-zip.sh` (`5ec085ac`). The Windows publish has never
been built twice and compared ([windows](windows.md)). Is it reproducible:
the same files and the same zips from two builds of one commit, also under
reprotest's variations?

## Setup

Run by Claude at Leo's request, on `arch`, on the WS branch head `100e3912`.
`experiments/phoenix-rt/run.sh` gained a layer `W`, a twin of layer `Z`: the
frontend as in layer `R`, then the Windows job's commands as written in
`00-reusable-windows-publish.yml` (locked restore, three `win-x64`
publishes, the migrator copied to `release/win/` as the job copies it), then
both zips packed with the commit's own `scripts/pack-release-zip.sh` and
`SOURCE_DATE_EPOCH` set to the commit's time. The hash list covers
`release/`: the two publish folders, the migrator and the two zips. SDK
10.0.401, Node 22.23.3, `APP_VERSION=v0.0.0-thesis`, `LC_ALL=C.UTF-8` as in
the layer `Z` runs. So it was meant; the first three runs also published
the Linux release before the Windows one, through a mistake in `run.sh`
found afterwards, and are repeated without it (the rerun below).

Not signed. The CI job signs every unsigned `.exe` and `.dll` before packing,
so these zips are the job's zips before signing, not its output.

## Expectation, written before the run

All `[I]`.

1. Under `none`, both builds give the same hash list: every file in the
   publish folders, the migrator (as `migrator-probe.sh` already found for
   it) and both zips.
2. Under `all`, the same, and the same list as under `none`. The Linux
   release on SDK 10 is identical under `all`, and nothing in the Windows
   publish depends on the host's runtime, locale or time.
3. The win-x64 apphosts (`WebAPI.exe`, `BackgroundJobExecutor.exe`) are
   copied from the NuGet host pack and patched with the app's name, so they
   do not differ either.

Added at 22:03, after the first two runs and before the third: the two
runs pin `LC_ALL=C.UTF-8` as the layer `Z` runs do, but the Windows job
sets no locale, so its runner's locale reaches the compiler.

4. Under `locales` without the pin, the same list again. SDK 10's compiler
   sorts the generated types ordinally, so W26 is gone (12/10, `Z-locales`).

## Commands

Verbatim in `data/2026-10-13-phoenix-windows-release/arch/kommando.txt`.

## Result

`[V]` (reprotest's verdict in each run's log, "No differences" between
the two builds' outputs, the hash list among them; the first build's
list in private data, as reprotest keeps only a link to it for the
second build's output when the two are the same (R6); the runs' lines in
`summary.tsv`, whose second hash reads the first build's list again
through that link, and the hashes in
`results.txt` beside `kommando.txt`), 21:31-22:16:

1. Held. Under `none`, both builds gave the same list of 4256 hashes
   (`3f4539bc…`): the 2132 Windows outputs (both publish folders, the
   migrator and both zips) and the Linux release's 2124 files.
2. Held. Under `all` the same list, the same file as under `none`. The
   pinned `LC_ALL=C.UTF-8` overrides reprotest's locale in the build
   commands here, as in the layer `Z` runs.
3. Held. `WebAPI.exe` and `BackgroundJobExecutor.exe` are in the list,
   with their own hashes, as the app's name is patched into each, and the
   same in both builds.
4. Held. Under `locales` without the pin, with `LC_ALL=et_EE.UTF-8` in
   the second build, the same list again.

The zips: `ws-pems-win-x64-v0.0.0-thesis.zip` `194bbb6a…` and
`ws-pems-job-worker-win-x64-v0.0.0-thesis.zip` `d2333e88…`; the
migrator `367333f9…`. The migrator differs from the win-x64 build in
`migrator-probe.sh` (`9f601966…`), which was built with
`APP_VERSION=v9.9.9` `[I]`.

## The rerun without the Linux publishes

Found after the runs, in Codex's check of this note at 23:47: every
build above also published the Linux release, before the Windows one.
Layer `W` meant to take layer `R`'s build without its last part, the
Linux restore and publishes, by cutting the text `&& $L2` off it; but
`R`'s build holds `L2` already expanded, so nothing was cut. The list of
4256 hashes holds 2132 Windows outputs (2130 files under `release/win/`
and the two zips) and the Linux release's 2124. `run.sh` builds the
frontend step on its own now (`FRONT`), and layer `W` takes only that
before the Windows job's commands. The three runs are repeated with it,
as `W2-none`, `W2-all` and `W2-locales`, in a fresh lab of `100e3912`.

Expectation, written at 23:54 before the reruns, all `[I]`:

5. Under `none`, `all` and `locales` (without the pin), reprotest finds
   no differences between the two builds.
6. Each list holds 2132 hashes: the two publish folders' 1628 and 501
   files, the migrator and the two zips.
7. The three lists are the same file, and its 2132 lines are the
   Windows lines of the first runs' list: the Linux publishes before
   them changed nothing in the Windows outputs.

Result `[V]` (reprotest's verdict in each run's log; the first build's
list in private data; the runs' lines in `summary.tsv`, whose second
hash now reads `link`; `results.txt`), 23:54-00:33:

5. Held. reprotest found no differences in any of the three runs. Under
   `locales` the second build's .NET processes had `LC_ALL=et_EE.UTF-8`
   (its log and the samples).
6. Held. Each list holds 2132 hashes and no Linux file: 1628 and 501 in
   the publish folders, the migrator and the two zips.
7. Held. The three lists are the same file (`04cc5759…`), and it is the
   first runs' list without its 2124 Linux lines, line for line. The
   zips, the migrator and the apphosts keep the hashes above.

## Interpretation

**Before signing, the Windows release is reproducible on Linux.** `[V]`
for `arch`: two builds of one commit, with the job's commands alone, gave
the same 2132 files and the same two zips, under every variation
reprotest makes here, and with the locale the job leaves unset (the
reruns). A Linux publish before them in the same tree changed none of
those files (the first runs). Built on Linux as the job builds it, the
Windows publish adds no differences of its own, and neither does the
packing script on its real input.

**On one toolchain, what is left between two runs of the job is
signing.** `[I]` The job
signs every unsigned `.exe` and `.dll` before packing, with an RFC 3161
timestamp from Microsoft's timestamp server (`sign-windows.sh`, lines 9
and 58). Each signing pass embeds its own timestamp, so the signed files
and the zips cannot match a second run. A rebuild can only be compared
with a release after the signatures are taken out again, file by file.
Whether that gives back the unsigned bytes exactly is not measured.
Across machines the dry run later that night found one more cause, the
runtime patch the compiler runs on (W58).

## Caveats

- One machine, one SDK and one NuGet cache. The job runs on WS's office
  runner. Later that night the dry run ran it on GitHub's `ubuntu-latest`
  and compared it with a local build of its own commit
  ([phoenix-ci-dry-run](2026-10-13-phoenix-ci-dry-run.md), W58).
- The job restores with `dotnet restore ./WS.Phoenix.sln`, locked through
  `Directory.Build.props`; `run.sh` also passes `--locked-mode`. The same
  restore `[I]`.
- `APP_VERSION` is `v0.0.0-thesis`, not a tag's name, so the bytes are not
  a release's bytes.
- The frontend export is built in each build, as in layer `R`; the job
  downloads the export the frontend job built.

## Not tested

- Signing, and a signed file compared with its unsigned build.
- The job on the merged branch, signed, on WS's office runner. Before the
  merge it ran on the test tag of 13/10 on `82ea130a`, on GitHub's
  Windows runner; unsigned, it ran in the dry run.
- A build on Windows: line endings at checkout, paths, the developer's
  publish.
