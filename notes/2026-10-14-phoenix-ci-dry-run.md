# The release workflow on GitHub with the fixes, 14 October 2026

## Question

The second dry run of the release workflow; the first was
[phoenix-ci-dry-run](2026-10-13-phoenix-ci-dry-run.md) on 13/10. Since
then the WS branch installs exactly the SDK in `global.json`, alone, in
every job (W58); checks each signed release by pasting its signatures
onto the unsigned build ([phoenix-signing](2026-10-14-phoenix-signing.md));
fixes the locale before SHA256SUMS; and builds the MCP images with
pinned bases and without what records the build
([phoenix-shipped](2026-10-14-phoenix-shipped.md)). Does every output of
the run now equal a local rebuild, with nothing added to the local SDK?
And do the release job's new steps work on GitHub's runners?

## Setup

Run by Claude at Leo's request, on his conditions for runs on GitHub
(13/10). A throwaway commit on the branch head `3c375938` changes three
workflow files with a script kept in private data, as on 13/10:

- No `build-and-test`, so no tests; no GitHub Release: the `release` job
  stops after writing SHA256SUMS and uploads it.
- `docker-images`: no registry login and no push. All five images, the
  two .NET images and the three MCP images, are written as OCI tarballs
  with `rewrite-timestamp=true` and uploaded as artifacts, kept one day.
  No `gha` cache.
- `publish-windows` on `ubuntu-latest`, without the `release-signing`
  environment. The binaries are signed with a throwaway CA and
  certificate made in the job, through the signing image's
  `SIGN_WITH_KEYSTORE` path, with timestamps from the release's RFC 3161
  server. The job's new check runs as it would in a release, with the
  test CA added to its trust. The CA's certificate is uploaded; the keys
  stay on the runner.
- A job on `windows-latest` runs the new SDK action, builds
  `ApplicationCore` and prints the runtime its PDB records.
- Every job is bounded to an hour: `gh` could not reach GitHub's API when
  the run began, as the keyring was locked, so the run starts unattended,
  and its artifacts, the run and the tag wait for Leo to unlock it.

The tag `v0.0.0-thesis.3` on that commit starts the run; only the tag is
pushed.

The local side is `experiments/phoenix-rt/ci-local.sh`, extended today
with the SQL script and the MCP images, on `arch`, with the SDK the new
installer put in a folder of its own: runtime 10.0.12 only, nothing
added. The Windows outputs are checked as the signing README says a
rebuild is checked: CI's signatures pasted onto the local unsigned build
with `paste-signatures.sh`, then packed with the commit's packing script
(`ci-compare.sh`, extended today).

## Expectation, written before the run's results

All `[I]`.

1. Every job succeeds, the Windows job's check included. The PDB on
   `windows-latest` records runtime 10.0.12, though the runner has other
   .NET installed.
2. CI's frontend export equals the local one.
3. Both Linux zips, the Linux migrator and the SQL script equal the local
   ones byte for byte: CI's compiler ran on the SDK's own runtime, so W58
   is gone.
4. With CI's signatures pasted onto the local build, both Windows zips
   and the Windows migrator are CI's byte for byte.
5. All five images have the same image manifest in CI and here.
6. SHA256SUMS written here over the local outputs, the Windows ones
   pasted, equals CI's.

## Commands

Verbatim in `data/2026-10-14-phoenix-ci-dry-run/arch/kommando.txt`.

## Result, run 1

`[V]` (the run's job list, its steps and annotations, its logs and
artifacts, the local rebuild and `compare.txt`, in private data). The run
05:20-05:45 UTC, the local rebuild 05:20-05:35 UTC:

1. Failed. Five jobs passed; `publish-windows` failed, so `release`, which
   needs it, was skipped. The Windows job's steps passed up to signing,
   which passed too; the check that follows never finished. GitHub's only
   record of it is the runner's own crash, `No space left on device`
   while writing its diagnostic log; the job's log was lost. On
   `windows-latest`, `ApplicationCore.pdb` recorded runtime `10.0.12`,
   built with the SDK the action put in `D:\a\_temp\dotnet-sdk`, which
   held runtime 10.0.12 alone. The runner's own .NET held eight runtimes;
   its newest 10.0 one was 10.0.12 too.
2. Held. CI's frontend export and the local one: the same 994 files.
3. Held. Both Linux zips, the Linux migrator and the SQL script are the
   local ones byte for byte. CI's compiler ran on runtime 10.0.12, and no
   runtime was added here: W58 is gone.
4. Not tested: the Windows job uploaded neither zips nor its migrator.
5. Held. All five images have the same image manifest in CI and here:
   WebAPI `6c225e6b…`, job worker `071244c8…`, MCP server `d409dd82…`,
   chat server `7925a643…`, authorization broker `54d198f6…`.
6. Not tested: without the release job, CI wrote no SHA256SUMS.

Where the disk went: `[V]` for the sizes, measured on the local rebuild
of the same job, `[I]` for how they add up on the runner. A hosted runner
starts with 13 GB free (the `df` that the `docker-images` job prints
before its cleanup). When the check began, the job held the NuGet
packages (4.9 GB here), the SDK, the publishes' intermediate files
(`src/**/bin` and `obj`, 1.8 GB; `publish/`, 512 MB), `release/win`
(1.7 GB) and the unsigned copy kept before signing (1.7 GB). The check
then wrote a second full copy, its output. On 13 October the job, without
the check, passed.

Cleanup, 05:58 UTC: the run with its artifacts deleted, the tag deleted;
the run made no cache.

## Run 2: the Windows job after the disk fix

Added after run 1's result, before run 2, at 09:05.

### Setup

The WS branch at `be5fc56e`, five commits after `3c375938`:

- `paste-signatures.sh` takes its output directory as an option. Without
  it, each signature is pasted into a temporary file, verified, hashed
  and deleted, and the release is compared with a listing of the
  rebuild in which each pasted file's mode and hash replace its twin's;
  a listing names every folder too. The Windows job runs the check so,
  and removes `publish/` and every `bin` and `obj` under `src` after its
  three publishes: 2.3 GB freed, against the unsigned copy (1.7 GB) and
  one pasted file at a time (at most 530 MB). Tested on `arch` first
  ([phoenix-signing](2026-10-14-phoenix-signing.md), the addendum).
- The Windows job takes the release's own frontend export. On a
  self-hosted runner it used to take a copy left on the host for the
  same commit, which on WS's office runner is Main CI's, built without
  the release's version. `[V]` v1.0.50's Windows and Linux WebAPI zips
  hold two frontend builds: 141 of 1188 files differ, among them the
  build ID (W64). On a hosted runner, as here, the step never ran.
- The SDK action keeps archives between jobs only on a self-hosted
  runner, the installer deletes those unused for 30 days, and the
  download goes to the job's temporary folder. Tested on `arch` first
  (`installer-tests.sh`).
- The manual image script's BuildKit check, and PR validation's backend
  filter, which now includes the SDK action and installer. Neither runs
  here.

A throwaway commit on that head cuts every job but the frontend export,
the Windows job and the `windows-latest` SDK job (`dryrun-edit-2.py`,
kept in private data as it quotes WS's workflows). For those it makes
run 1's edits: the throwaway certificate, no cache, artifacts kept one
day, an hour per job. The Windows job also writes its free disk every
five seconds and prints the low point. The tag `v0.0.0-thesis.5` on that
commit starts the run; only the tag is pushed.

The local side: `ci-local.sh` with the frontend and Windows jobs, at the
same commit, with an SDK the installer put in a folder of its own; then
`ci-compare.sh`, which now reports an output the run did not make as
not in this run.

### Expectation, written before run 2

All `[I]`.

1. All three jobs pass. The Windows job's check pastes 177 signatures and
   finds every file and folder the release's.
2. The Windows job never has less than 1 GB free. From the sizes, its
   low point comes while the unsigned copy exists, at about 3 GB.
3. CI's frontend export equals the local one.
4. With CI's signatures pasted onto the local build, both Windows zips and
   the Windows migrator are CI's byte for byte.
5. On `windows-latest`, the action works with its download in the job's
   temporary folder and no cache, and the PDB records `10.0.12`.

## Result, run 2

`[V]` (the run's jobs and steps, its logs and artifacts, the local
rebuild and `compare.txt`, in private data). The run 07:04-07:20 UTC,
the local rebuild 07:04-07:09 UTC:

1. Held. All three jobs passed, the Windows job in all its steps. Its
   check pasted 177 signatures and found 2130 files and 114 folders
   equal to the signed release.
2. Held, below the estimate. The Windows job started with 13 GB free and
   reached its low point, 2183 MiB, at 07:17:49, three seconds into the
   check: the unsigned copy existed, and the first file pasted is the
   migrator, the largest. The estimate of about 3 GB was 0.9 GB too
   high. At the end 3.9 GB were free.
3. Held. CI's frontend export and the local one: the same 994 files.
4. Held. With CI's signatures pasted onto the local build (exit 0, 2130
   files and 114 folders equal), both Windows zips and the Windows
   migrator are CI's byte for byte.
5. Held. On `windows-latest` the SDK came from Microsoft's archive, not
   from a cache, into `D:\a\_temp\dotnet-sdk`, which was then the only
   entry in the job's temporary folder; the PDB records `10.0.12`.

Cleanup, 07:24 UTC: the run with its artifacts deleted, the tag
deleted; no cache on the tag.

## Interpretation

**Across machines, every output of the release can now be rebuilt
byte for byte, with nothing added to the local SDK.** `[V]` for
GitHub's hosted runners and `arch`, over the two runs: the frontend,
both Linux zips, the Linux migrator, the SQL script and all five images
(run 1), and both Windows zips and the Windows migrator once the
signatures are pasted (run 2). SHA256SUMS is the one output not
compared: run 1 lost the job that writes it, and run 2 did not include
it. Its inputs are the outputs compared here and `upgrade.sh` from the
commit, and its order is fixed by `LC_ALL=C` (W63) `[I]`.

**A check inside the release job costs what the job can spare.** `[V]`
Run 1's check doubled the Windows build on disk, and the hosted runner
crashed taking the job's log with it, the hardest kind of release
failure to diagnose. Run 2's check fits by freeing the build's
intermediate files first, with 2.1 GB left at the low point `[V]`. A
hosted runner leaves this job little room: the image job already frees
preinstalled toolchains to fit, and the Windows job would need the same
if it grows `[I]`.

**A runner's shortcut decided what a release contained.** `[V]` for
v1.0.50: the Windows zip carries another frontend build than the Linux
zip, because the Windows job on WS's office runner took a copy of the
export that Main CI had left on the host for the same commit. The
release job's inputs depended on what else had run on that machine.
The branch now takes the release's own export; that it does so on the
office runner is not tested `[I]`.

## Caveats

- Hosted runners only. WS's releases run the Windows job on its office
  runner, which neither run touched: its disk, its Docker daemon and
  Azure signing were not used.
- A throwaway certificate, as in
  [phoenix-signing](2026-10-14-phoenix-signing.md).
- One run of each, on one day's runner images.
- The disk was sampled every five seconds; a shorter low point could
  fall between two samples.

## Not tested

- The Windows job on the office runner, with Azure signing, and the
  frontend export it now takes there.
- The SDK action's cache on a self-hosted runner over time, and its
  pruning after 30 days there.
- SHA256SUMS from CI.
