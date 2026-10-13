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
   that log starts with "Build started...": dotnet-ef 9 got through its
   metadata step, and its build restored. Corrected 13/10: an earlier
   version said dotnet-ef 9 built first. It reads the metadata first too,
   but only properties; version 10 adds the target
   `ResolvePackageAssets`, which needs the restore
   ([phoenix-dev-workflows](2026-10-13-phoenix-dev-workflows.md)).
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
`migration-bundles` job never does; dotnet-ef 9 read only properties
there, and its build restored (corrected 13/10, see result 1). The move to
.NET 10 (`332752b9`) broke the job, and the CI-equivalent check missed it,
since it ran `dotnet ef` after a full restore and build. `publish-windows`
restores the solution before its bundle step and is not affected; the
migrations Dockerfile restores first too. A one-step fix, a locked restore
before the bundle as in `publish-windows`, was prepared for the branch and
went onto it on 13/10 at Leo's request, as `21360193` together with the
same restore for PR validation's migration guard (see the follow-up
below); neither has run in CI.

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

## Follow-up after review: PR validation's migration guard

Codex, reviewing the restore before it was pushed, pointed out that PR
validation's `migration-guard` job runs `dotnet ef migrations
has-pending-model-changes` after only `dotnet tool restore`, on a runner
of its own. The NuGet cache it restores holds packages, not the projects'
`obj/project.assets.json`.

Expectation, written before the run `[I]`: on a fresh export of the branch
with the restore (`2973ab8a`), SDK 10.0.401 and `GITHUB_ACTIONS=true` as on
a runner, the job's two commands fail with NETSDK1004, as the bundle did.
With `dotnet restore ./WS.Phoenix.sln` first, locked through
`GITHUB_ACTIONS`, the check runs and exits 0: the branch's model matches
its last migration.

Commands: run by Claude at Leo's request, in bash, with
`experiments/phoenix-rt/guard-probe.sh`; verbatim in `kommando.txt`. The
connection string points at a closed local port, so nothing can reach a
real database.

Result `[V]` (the logs, 13/10 07:36-07:38):

1. As the job runs it: exit 1 after 3 seconds, NETSDK1004 on
   Infrastructure's `project.assets.json`, the same as the bundle.
2. With `dotnet restore ./WS.Phoenix.sln` first: exit 0, and dotnet-ef
   reports no changes to the model since the last migration.

The expectation held.

Interpretation `[V]`: the move to .NET 10 broke a second job the same
way. PR validation's `migration-guard` would have failed every backend
pull request. Before the push, its restore went into the branch's restore
commit, which now covers both jobs: `21360193`, "Restore before dotnet ef
on a fresh checkout". `2973ab8a`, measured here, is that commit before
then; the two trees differ only in `01-pr-validation.yml`, which the
commands do not read.

## The fix: a migrator project in the repository

Leo asked on 13/10 for the migrator project, built on the WS branch and
measured before and after; Codex reviewed the design first (Astra, extra
high). The design: `src/DbMigrator`, a project in the repository whose
program is the one line `dotnet ef` generates for every bundle,
`MigrationsBundle.Execute(context, migrationsAssembly, startupAssembly,
args)` (EF Core's public entry point for bundles, read in dotnet-ef
10.0.12's template). EF keeps its command line, transactions, history and
locking; the repository's `Directory.Build.props` reaches the project, so
`PathMap`, a lock file and `APP_VERSION` apply. It is published like the
WebAPI and the job worker, and the bundle steps' `SkipLockedRestore`
exception goes.

Every run against a database below goes to a PostgreSQL container without
a network, through its Unix socket, and the migrators run in a namespace
without a network (`unshare -rn`): both appsettings files point the default
connection at a remote host, and no code path may reach it.

Expectation, written before the runs `[I]`:

1. EF creates the context with `DatabaseContextFactory`, the one that reads
   the connection string from the environment, not with
   `DatabaseContextDesignTimeFactory`, which reads
   `../WebAPI/appsettings.Development.json`: the deployment's tenant upgrade
   passes the connection only through the environment and would fail with
   the second.
2. Two builds of the migrator from fresh exports at two different paths
   are byte-identical, for linux-x64 and for win-x64 (cross-built here,
   before signing).
3. The migrator and the old bundle (built from `acbea21c`, the same
   migrations) leave identical databases, from empty to the latest
   migration and from an older migration to the latest: the same
   `__EFMigrationsHistory`, the same `pg_dump` of schema and data, apart
   from values the run's clock fills in, if any.
4. The same command line: the same `--help`; on an up-to-date database
   exit 0 with nothing applied; on an unreachable database exit 1 from
   both; the connection from the environment works without `--connection`,
   and `--connection` overrides it.
5. The migrator is smaller than the bundle's 827 MB, since the WebAPI's own
   dependencies are no longer in it. How much smaller is not predicted.
6. Back from the latest migration to an older one (the migrations' `Down`
   methods), the two again leave identical databases. Added before that
   run, after the first result below.

Commands: run by Claude at Leo's request, in bash; verbatim in
`kommando.txt`, with `experiments/phoenix-rt/migrator-probe.sh` (two
builds) and `experiments/phoenix-rt/migrator-parity.sh` (old against new).

Result `[V]` (logs, `cmp`, `pg_dump`; 13/10 08:33-09:03):

1. Expectation 1 failed. `dotnet ef migrations list --no-connect
   --verbose` on `21360193` says "Using DbContext factory
   'DatabaseContextDesignTimeFactory'", from the repository root and from
   `src/WebAPI`. The bundle of `acbea21c`, run from an empty folder, stops
   with `DirectoryNotFoundException` for `<folder>/../WebAPI/` before it
   connects, both with `--connection` and with the connection in the
   environment only. EF takes the first factory for the context in the
   assembly's type order, and the second factory, added in `c2a77964`
   on 10 July, comes first. WS commit `d1500897`
   leaves one factory: the environment first, then for PostgreSQL the
   development settings if `../WebAPI` has them, then a local default.
   Its five unit tests pass, one of them checks that there is one
   factory, and EF then uses `DatabaseContextFactory`.
2. Held. Two builds from fresh exports at `/private/tmp/rb1-mig-a/x` and
   `/private/tmp/rb1-mig-bb/longer/path/x`, with the release jobs'
   commands, are byte-identical: on `37dc477a`, which the pushed
   `cd36f241` and `82ea130a` change only in a README and the release
   workflow, linux-x64 `a51039ce…`, 793,328,676
   bytes, and win-x64 `eca1c874…`, 528,249,265 bytes, cross-built and
   unsigned. A first version of the program, whose comment was later
   corrected, also gave two identical builds.
3. Held, for content. The old bundle had to run from a checkout's
   `src/WebAPI`, with `--connection`, because of its factory; the
   migrator ran from an empty folder. From empty to the latest of 150
   migrations, both leave the same history and the same rows, but one
   seed table's rows in another order, so `pg_dump` differs in 24 lines
   and the sorted dumps are identical. Two runs of the same tool differ
   the same way, in the same table, so the order is not the tool's. From
   an older migration to the latest the dumps are byte-identical.
4. Held. On an up-to-date database both apply nothing and exit 0. With a
   server that cannot be reached both exit 1 with the same
   `NpgsqlException`. `--help` is the same text, exit 0. The connection
   from the environment alone migrates the same rows, and `--connection`
   overrides a wrong connection in the environment. The planned check
   "a database that does not exist fails" was wrong: EF's migrate creates
   a missing database, for the bundle as for the migrator, so the server
   that cannot be reached replaced it.
5. Held, narrowly: 793 MB against the bundle's 827 MB.
6. Held. Back down to the older migration, both leave the same history
   and the same rows; one seed table's order differs as in 3. That
   database differs in content from one migrated up to the same
   migration from empty, for both tools: the `Down` methods do not undo
   every data change.

Also measured: with the migrator's own assembly as the startup assembly,
as Codex had first suggested, the migration works the same and the entry
point runs once. Infrastructure stays the startup assembly because it is
the library that holds the context and its factory. The release job's new
smoke-test step, run here against `postgres:17-alpine` on 127.0.0.1 from a
temporary folder: exit 0, 150 migrations applied.

**The release's migrator is reproducible as a project in the repository.**
`[V]` With `src/DbMigrator`, two builds of one commit at two paths give
the same file for both runtimes, where the bundle differed in 93 bytes.
The project gets `PathMap`, a lock file and `APP_VERSION` from
`Directory.Build.props`, and the bundle steps' unlocked restore is gone.

**It behaves as the bundle did, where the bundle worked at all.** `[V]`
The same EF program, so the same command line and the same databases, in
every case measured. `[I]` The branch's bundle could not have worked
outside a checkout since `c2a77964`, which no step before a deployment
exercised; the release job now runs the migrator against an empty
PostgreSQL before it ships it.

Caveats and not tested:

- The migrations image was not built: its base images and a NuGet restore
  inside the build need downloads. Its commands were not run outside
  Docker either.
- win-x64 was cross-built on Linux and is unsigned; the Windows job, its
  signing and the Windows migrator's behaviour are not measured.
- Nothing here ran in GitHub Actions: not the restore steps, not the smoke
  test with its service container. CI's .NET steps did run here, on
  `37dc477a` (08:59-09:41): locked restore, Release build, 4231 unit, 678
  integration and 149 functional tests passed, none failed, and the
  migration guard reports no model changes. The run spans a suspend of
  the laptop.
- No released migrator was run. Releases are built from main, which the
  branch left on 14/9, and main rewrote both factories on 22/9 with a
  guard that keeps design-time commands from remote hosts unless they are
  allowed. What the July factory did to the branch therefore says little
  about main's releases; how the guard meets the migrator is part of
  merging main into the branch. Corrected 13/10: an earlier version of
  this caveat inferred that every migrator built after `c2a77964` fails,
  from the factory's file being present, not from its content.
- The database comparisons ran against PostgreSQL 17.9 with trust
  authentication over a socket, one machine.
