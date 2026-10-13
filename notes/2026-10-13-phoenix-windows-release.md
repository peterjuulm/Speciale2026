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
the layer `Z` runs.

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

Added at 22:05, after the first two runs and before the third: the two
runs pin `LC_ALL=C.UTF-8` as the layer `Z` runs do, but the Windows job
sets no locale, so its runner's locale reaches the compiler.

4. Under `locales` without the pin, the same list again. SDK 10's compiler
   sorts the generated types ordinally, so W26 is gone (12/10, `Z-locales`).

## Commands

Verbatim in `data/2026-10-13-phoenix-windows-release/arch/kommando.txt`.

## Result

`[V]` (each run's two hash lists in private data; the runs' lines in
`summary.tsv` and the hashes in `results.txt` beside `kommando.txt`),
21:31-22:16:

1. Held. Under `none`, both builds gave the same list of 4256 hashes
   (`3f4539bc…`): both publish folders, the migrator and both zips.
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

## Interpretation

**Before signing, the Windows release is reproducible on Linux.** `[V]`
for `arch`: two builds of one commit gave the same 4256 files and the
same two zips, under every variation reprotest makes here, and with the
locale the job leaves unset. Built on Linux as the job builds it, the
Windows publish adds no differences of its own, and neither does the
packing script on its real input.

**What is left between two runs of the job is signing.** `[I]` The job
signs every unsigned `.exe` and `.dll` before packing, with an RFC 3161
timestamp from Microsoft's timestamp server (`sign-windows.sh`, lines 9
and 58). Each signing pass embeds its own timestamp, so the signed files
and the zips cannot match a second run. A rebuild can only be compared
with a release after the signatures are taken out again, file by file.
Whether that gives back the unsigned bytes exactly is not measured.

## Caveats

- One machine, one SDK and one NuGet cache. The job runs on WS's office
  runner, not compared with these builds yet.
- The job restores with `dotnet restore ./WS.Phoenix.sln`, locked through
  `Directory.Build.props`; `run.sh` also passes `--locked-mode`. The same
  restore `[I]`.
- `APP_VERSION` is `v0.0.0-thesis`, not a tag's name, so the bytes are not
  a release's bytes.
- The frontend export is built in each build, as in layer `R`; the job
  downloads the export the frontend job built.

## Not tested

- Signing, and a signed file compared with its unsigned build.
- The job on the merged branch on GitHub: it ran on the test tag of 13/10
  on `82ea130a`, before the merge, on GitHub's Windows runner.
- A build on Windows: line endings at checkout, paths, the developer's
  publish.
