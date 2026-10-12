# Phoenix: the EF Core migration bundle

Experiment note, 13 October 2026, on `arch`. Private data in Leo's
`speciale-2026/data/phoenix-bundle/arch-2026-10-13/`; the public part will be
in `data/2026-10-13-phoenix-bundle/arch/`. Phoenix source and build output do
not land in this repo. Expectation written before the first build.

## Question

The release ships a database migrator for Linux, built in
`03-release.yml`'s `migration-bundles` job with
`dotnet ef migrations bundle --self-contained -r linux-x64`. No run so far
has measured it. Built twice from the same commit, at the same path, with
the job's commands, is it the same file?

## Setup

- `experiments/phoenix-rt/bundle-probe.sh` on the WS branch's head, `acbea21c`:
  one export of the commit, checked file by file; each build copies it to
  the same folder, `/private/tmp/rb1-bundle`, and runs `dotnet tool restore`
  and the job's bundle command under `env -i`, with the job's environment
  (`LC_ALL=C.UTF-8`, `SkipLockedRestore=true`) and Microsoft's SDK 10.0.401.
- Two builds, one after the other. Not under reprotest.

## Expectation, written before the run

All `[I]`.

1. The two bundles differ. `dotnet ef` writes a small project of its own
   into a new, randomly named folder under the temporary directory and
   publishes it; that project lies outside the repository, so the
   repository's `Directory.Build.props` with `PathMap` does not reach it,
   and its build path ends up in the bundle, at least in the debug
   directory of its own assembly.
2. Everything else in the bundle, Phoenix's assemblies included, is the
   same in both.

## Commands

Run by Claude at Leo's request, in bash. Verbatim in `kommando.txt`.

## Result

`[V]` (the probe's logs, `cmp`, the bundles' own table of contents read by
`bundle-map.py`, `strings`), 13/10 00:14-00:33, three runs:

1. As the job runs it, on `acbea21c`: both builds stop within seconds,
   before any bundle exists. `dotnet ef` cannot read the projects'
   metadata: `NETSDK1004: Assets file '…/src/Infrastructure/obj/
   project.assets.json' not found`. The same commands on `b744ab91`, the
   last commit on .NET 9 (SDK 9.0.120, dotnet-ef 9.0.0), build the bundle;
   that log starts with "Build started...", so dotnet-ef 9 built, and
   restored, first.
2. With a locked restore of the solution first (`PRE_RESTORE=1`), both
   builds succeed, 827,679,012 bytes each, and differ in 111 bytes. This
   run named the two outputs `bundle-1` and `bundle-2`, and dotnet-ef names
   the bundle's own assembly after its output, so most of those bytes are
   the name: in that assembly, its `deps.json`, the apphost and the
   bundle's table of contents. A flaw of the probe, not of the build.
3. With one output name in two folders, as CI would make it: both builds
   succeed, 827,679,078 bytes each, and differ in 93 bytes. 81 are in the
   bundle's own assembly, `ws-pems-db-migrator.dll` (4096 bytes), and 12
   are the bundle ID in the header (`ve_BzlfR7604` against
   `Ix3KUdZaCsVa`). Every other of the 734 bundled files is the same: all
   of Phoenix's assemblies and the runtime. In the assembly the PDB path
   differs: `/tmp/edcd3bw0.pxw/obj/Release/net10.0/linux-x64/
   ws-pems-db-migrator.pdb` against `/tmp/mdzdnlcp.dff/…`.

Where the expectation failed: 1 and 2 held for the bundles that were
built; that the job's own commands no longer build one at all on .NET 10
was not expected.

## Interpretation

**The release's migrator is not reproducible, for one reason.** `[V]`
`dotnet ef` writes the bundle's project into a new, randomly named folder
under `/tmp` and publishes it there. The folder's path ends up in that
project's assembly, through its PDB path, and the bundle ID follows. The
repository's `PathMap` (W5) never reaches that project, since
`Directory.Build.props` applies only below the repository.

**The job is broken on .NET 10.** `[V]` dotnet-ef 10 reads project
metadata before it builds and so needs the projects restored, which the
`migration-bundles` job never does; dotnet-ef 9 built first. The move to
.NET 10 (`332752b9`) broke the job, and the CI-equivalent check missed it,
since it ran `dotnet ef` after a full restore and build. `publish-windows`
restores the solution before its bundle step and is not affected; the
migrations Dockerfile restores first too. A one-step fix, a locked restore
before the bundle as in `publish-windows`, is prepared for the branch but
not applied (Leo's call: it changes the release workflow).

**A fix for the bundle itself.** `[I]` Not `dotnet ef`'s temporary project
but a small migrator project in the repository, which applies the
migrations and is published self-contained like the two programs: it
would get `PathMap`, the lock files and `APP_VERSION` from
`Directory.Build.props`. That is the "migrator project" already in the
plan; it changes how releases and deployments run migrations, so it is
for Leo and WS to decide.

## Caveats and not tested

- Plain builds at one path, not under reprotest.
- Only the Linux bundle; the Windows one is built the same way with
  `-r win-x64` and is not measured.
- Whether the bundle ID follows the content or is random is not known: it
  differed together with the assembly.
- The idempotent SQL script the job also writes is not measured.
