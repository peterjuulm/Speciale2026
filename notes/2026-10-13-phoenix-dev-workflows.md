# The developers' commands on the WS branch, 13 October 2026

## Question

The WS branch changes how Phoenix restores, builds and versions itself:
locked NuGet restores (W22), one pinned SDK (`global.json`), deterministic
paths, `APP_VERSION` (W45), the design-time factories moved into the
startup projects (W52), a filled frontend lock (W41) and a pinned Node
(W40). Every check so far ran the release's commands or CI's. Do the
commands a developer runs every day, the Makefile's targets, still work on
the branch, and do they leave the committed files, the lock files above
all, as they are?

## Setup

Run by Claude at Leo's request, on `arch`, on the branch head `5ec085ac`,
with `experiments/phoenix-rt/dev-workflows.sh`. A shallow clone of the
branch stands in for a developer's checkout, so `git status` shows what a
developer would see after each command. SDK 10.0.401, Node 22.23.3 with
npm 10.9.9, an empty home folder, so no .NET user secrets are read. Every
step runs in its own user, network and PID namespace without a network,
and nothing it starts outlives it. NuGet and npm work from the caches of
the earlier runs; npm runs offline, without its audit and fund requests.

The developers' configuration points the design-time commands at
`localhost:5432`, the port of the developer's own database. So the
database steps run where `127.0.0.1:5432` leads only to a scratch
PostgreSQL 17 container: the container has no network, and inside the
namespace `socat` forwards that port to the container's Unix socket.
Main's design-time guard counts only `localhost` and `127.*` as local, not
a socket path, which is why the forward is needed.

## Expectation, written before the run

All `[I]`.

1. `make install-tools` and `make build` (Debug) succeed, and `git status`
   stays empty: the build changes no committed file, no lock file.
2. `make db-migrate` applies all 160 migrations to an empty database. With
   a remote host in the environment, main's guard stops it before any
   connection, with its message about a host that is not local.
3. `make db-migration-add` runs through the WebAPI's design-time factory
   and creates a migration with no operations, since the model matches the
   snapshot; the snapshot stays as committed. `make db-migration-remove`
   takes the migration out again, and `git status` is empty.
4. A package referenced directly where it was transitive: the locked
   restore CI runs fails with NU1004 until a developer's plain restore has
   updated the lock files, and passes after it.
5. `make install-frontend`, which runs `npm install`, is the one open
   question: if npm 10.9.9 keeps the `libc` field, as npm 11 does, the
   install writes the 36 fields main's lock lost (W46) back; if it drops
   it, as 10.8.2 does, the lock stays as committed. Either way `resolved`
   and `integrity` stay in every entry (W41).
6. `make dev-frontend` serves the start page without a server error, and
   its log shows no compile error.

## Commands

Verbatim in `data/2026-10-13-phoenix-dev-workflows/arch/kommando.txt`, the
numbers in `results.txt` beside it; the logs in private data.

## Result

`[V]` (the runs' `results.txt`, their logs, and the probes beside them in
`kommando.txt`), 13/10 15:16-15:33, two runs on `5ec085ac`.

In run 1 (15:16-15:18) `make build`, the second step, failed, so nothing
was restored or built, and every later .NET step met an unrestored
checkout. `make db-migrate` failed with NETSDK1004, and the two migration
targets exited 0 although `dotnet ef` had failed. Run 2
(15:20-15:26) adds three things: `make db-migrate` on the fresh clone on
purpose (D0), the build a developer falls back to, `dotnet build
WS.Phoenix.sln` (D1-sln), and a check for dotnet ef's own "Done." beside
the targets' exit codes. Run 2, against the expectations:

1. `make install-tools` exits 0, and `git status` stays empty. `make build`
   exits 2 with MSB1011: the root holds `WS.Phoenix.sln` and
   `docker-compose.dcproj`, and `dotnet build` with no argument will not
   choose. `dotnet build WS.Phoenix.sln` (Debug) exits 0 and changes no
   tracked file, no lock file. It leaves one untracked folder,
   `.local/share/NuGet/Migrations`, in the checkout's root.
2. On the fresh clone, before any build, `make db-migrate` exits 2 with
   NETSDK1004: Infrastructure's `project.assets.json` does not exist.
   After the build it applies all 160 migrations to the empty database.
   With a remote host in the environment, the guard stops it with its
   message, exit 2. This step left a second `.local` folder, in
   `src/WebAPI`.
3. `make db-migration-add` runs through the WebAPI's design-time factory
   and creates a migration with no operations. `make db-migration-remove`
   takes it out. dotnet ef says "Done." both times. The snapshot did not
   stay as committed: after the remove it was still modified. In a probe
   at 15:32 the add's change to it was one line, EF's version annotation:
   `ProductVersion` 9.0.0 became 10.0.12. The remove's leftover was not
   diffed.
4. As expected. With `Microsoft.Extensions.Caching.Abstractions` 10.0.12
   referenced directly in ApplicationCore, the locked restore failed with
   five NU1004. A plain restore rewrote five lock files, and the locked
   restore then passed.
5. `npm install` exits 0 and leaves `package-lock.json` byte-identical.
   npm 10.9.9 does not keep `libc`: its arborist 8.0.5 lists `os` and
   `cpu` among the fields the lock keeps, not `libc`
   (`shrinkwrap.js:85-104`). "As npm 11 does" in the expectation is too
   broad, as Codex pointed out. npm 11.6.2 (arborist 9.1.6) has no `libc`
   there either, and npm 11.17.0 (arborist 9.8.0) has it at line 98, as
   11.19.1 did (W46). Both read in the npm copies of Rider's bundled Node
   runtimes.
6. `make dev-frontend` serves the start page: HTTP 200, 1281 bytes, in
   3.7 s, and no error lines in the server's log.

Run 1's steps that did not depend on the build, the lock files (4), npm
(5) and the dev server (6), gave the same results as in run 2.

The probes beside the runs, on where the `.local` folders come from. A
plain restore of a one-line project, inside and outside the namespace,
with and without `DOTNET_CLI_HOME`, wrote NuGet's Migrations folder under
`HOME`, never in the working folder. In the lab after run 2, a solution
restore, two forced restores of one project and two incremental builds
did not create it in the checkout, and neither did one `dotnet ef
migrations add`.

## Interpretation

`[I]` unless marked.

Once the solution is built, the branch's developer path works. Migrations
apply, a migration can be added and removed through the WebAPI's factory,
the lock files behave as CI expects, `npm install` leaves the lock alone,
and the dev server serves. A fresh clone fails in three places.

- `make setup` and `make db-migrate` before any build fail on the branch,
  and the branch caused it. This is W53 on the developers' path. dotnet-ef
  reads the projects' metadata before it builds; version 10 adds the
  target `ResolvePackageAssets` to that step, and the target needs
  `project.assets.json` `[V]` (the metadata command in run 1's log; the
  name is in dotnet-ef 10.0.12's assembly and not in 9.0.0's). dotnet-ef
  9 reads only properties there, and its build then restores, which is
  why main's `make setup` works. That is Codex's reading of dotnet-ef
  9.0.0's assembly; main was not run. CI got its restore in `21360193`;
  the Makefile has none.
- `make build` fails on main too. Both files lie at the root of main, of
  the branch point `a2dc1d5b` and of `5ec085ac`, and the target runs
  `dotnet build` with no argument `[V]` (`git ls-tree`, `Makefile:138-140`
  on main). A developer who builds from the IDE, or names the solution,
  never meets it.
- `add_migration.sh` and `remove_migration.sh` report success after
  `dotnet ef` fails `[V]`: neither sets `-e`, and each ends with an
  `echo`. The same on main. The developer reads "Migration created!" while
  nothing was created.

The snapshot's change is EF's version number and nothing else. The
committed snapshot was written by EF 9.0.0, and the first migration added
with the branch's tools rewrites that line, so that migration's diff
carries it. The model did not change: the add found no operations.

Peter's finding on `mac`
([dependency-plan](2026-10-12-dependency-plan.md)), now W54: `src/DbMigrator` sets
`PublishSingleFile` and two runtimes but no single runtime, so the SDK
adds the host's runtime to the restore
(`Microsoft.NET.RuntimeIdentifierInference.targets:130-154`, SDK
10.0.401) `[V]`. On `osx-arm64` the lock has no graph for it; on
linux-x64 and win-x64 hosts the host's runtime is already in the list.
Codex's check of the fix: `UseDefaultPublishRuntimeIdentifier=false` in
the project stops that inference and nothing else. A conditional
`PublishSingleFile`, or one moved to the publish command, would also stop
the single-file analyzer during restore
(`Microsoft.NET.Sdk.Analyzers.targets:76-81`). That analyzer brings
`Microsoft.NET.ILLink.Tasks`, which the lock lists as a direct dependency,
so the lock would change.

## Open problems

None fixed; the fixes are candidates for the WS branch, waiting for
Leo's go.

1. The fresh clone. `make setup` and `make db-migrate` (NETSDK1004, the
   branch's), `make build` (MSB1011, main's too), and the migration
   scripts' exit codes (main's too). Candidates: a restore before the
   Makefile's EF targets, `make build` naming `WS.Phoenix.sln`, and
   `set -e` in both scripts.
2. The migrator's lock on macOS (W54). Candidate:
   `UseDefaultPublishRuntimeIdentifier=false`. The migrator's bytes with
   it are not measured.
3. The `.local/share/NuGet/Migrations` folders. The first build of the
   fresh clone made one in the root, and `make db-migrate` one in
   `src/WebAPI`; git shows both as untracked. The probes did not make
   them again, and the cause is unknown.
4. W46 stays open. CI's npm since the merge, 10.9.9, writes no `libc`
   either, and a developer with npm 11.17 or later would write the fields
   back with any `npm install` that rewrites the lock.

## Caveats and not tested

- One machine and one Linux distribution, one run of each command. The
  developer path on macOS and Windows was not run; the migrator's lock on
  macOS is Peter's run.
- The harness differs from a developer's machine: an empty home folder,
  no network, its own user and PID namespaces, NuGet and npm from caches.
  The `.local` folders may come from the harness.
- The database steps ran against a scratch PostgreSQL 17 through a
  forward, not against the developers' own database.
- Main's developer path was not run. What is said about main is read in
  its files, apart from dotnet-ef 9's metadata step, which is Codex's
  reading of its assembly.
- `make setup` as a whole was not run, only its `db-migrate` step.
- Only the add's change to the snapshot was diffed, not the remove's.

## Follow-up: the fixes, 13/10 evening

At Leo's go, four commits on the WS branch, one per problem above:

- The Makefile names `WS.Phoenix.sln` in every `dotnet` command that takes
  a project or solution: `build`, `clean`, `format` and `format-check`.
- A `restore` target, a prerequisite of `db-migrate`, `db-migration-add`
  and `db-migration-remove`.
- `set -e` in `add_migration.sh` and `remove_migration.sh`.
- `UseDefaultPublishRuntimeIdentifier=false` in `src/DbMigrator` (W54).

### Expectation, written before the runs

All `[I]`.

1. Run 3 of `dev-workflows.sh`, on the new head. `make db-migrate` on the
   fresh clone (D0) applies all 160 migrations, and `make build` exits 0.
   Neither changes a tracked file. D2 to D6 give run 2's results.
2. Two new failures, on purpose, show the scripts' exit codes. A second
   `make db-migration-add name=ThesisProbe` fails, since the name is
   taken. A second `make db-migration-remove` fails, since the last
   migration left is applied to the database. Both exit non-zero and
   print neither "Migration created!" nor "Migration removed!".
3. `make clean` exits 0, and `make format-check` gets past choosing the
   solution: no MSB1011 in either log. Whether the formatting check
   itself passes is not part of the question.
4. W54 on Linux, with the host's runtime set to `osx-arm64`
   (`-p:NETCoreSdkPortableRuntimeIdentifier=osx-arm64`): the locked
   restore of `src/DbMigrator` fails with NU1004 on `5ec085ac` and passes
   on the fix.
5. `migrator-probe.sh` on the fix: both builds identical, and the same
   bytes as on `79cb67a7` (linux-x64 `062f730d…`, win-x64 `9f601966…`),
   since the release publishes with `-r` and the property only matters
   without one. A publish without `-r` stops with NETSDK1097.
6. The `.local/share/NuGet/Migrations` folders appear again, as in run 2;
   none of the fixes touches them.

### Result

`[V]` (`results.txt` and `kommando.txt` beside the first runs; the logs in
private data), 13/10 21:01-21:33.

- Run 3 (21:01-21:07, `39ce4321`) does not count for the EF steps.
  `dotnet tool restore` wanted nuget.org: the reboot had wiped the lab's
  NuGet cache, and the package folder copied back from Leo's own cache
  lacks NuGet's HTTP cache, which an offline tool restore and D6's new
  reference need. Its `make clean` (exit 0) and `make format-check` (no
  MSB1011) stand. One online tool restore and one online restore with D6's
  reference filled the HTTP cache.
- Run 4 (21:08-21:14, `39ce4321`), expectations 1-3: `make db-migrate` on
  the fresh clone applies all 160 migrations, `make build` exits 0. The
  second add exits 2 ("is used by an existing migration"), the second
  remove exits 2 ("has already been applied to the database"), and
  neither prints its success message. `make clean` exits 0; `make
  format-check` gets past choosing the solution and fails on the code's
  own import order, about 2,400 findings. D2 to D6 as in run 2.
- Expectation 4: with the host's runtime set to `osx-arm64`, the locked
  restore of `src/DbMigrator` fails on `5ec085ac` with NU1004 ("Project's
  runtime identifiers: linux-x64;osx-arm64;win-x64, lock file's runtime
  identifiers linux-x64;win-x64") and passes on the fix. With `linux-x64`
  both pass.
- Expectation 5: both migrator builds on the fix are identical and the
  same bytes as on `79cb67a7`, `062f730d…` and `9f601966…`. The publish
  without `-r` did not stop with NETSDK1097, as expected and as the first
  version of the project's comment said: it published for `linux-x64`. A
  second rule in the same targets file, `UseCurrentRuntimeIdentifier`
  (lines 103-123), picks the host's runtime while publishing. The comment
  and the commit message were corrected before the push.
- Expectation 6: the `.local` folders appeared again. Six probes beside
  the runs (a restore and a build of an export or of a clone, with and
  without the namespaces, with the script's whole environment) put NuGet's
  Migrations folder under `HOME` every time, never in the checkout. Only
  the script's own steps leave it there.
- Codex reviewed the four commits: correct, but `dotnet format` stops with
  an error of its own, not MSB1011; the scripts' `mkdir` made an unused
  `src/WebAPI/Data/Migrations`; and the scripts called directly, and the
  docs, still ran `dotnet ef` or bare `dotnet` commands without a restore
  or a solution. The series became five commits: `3e4fbc48` (the
  solution in the Makefile), `d547d192` (`set -e`, no `mkdir`),
  `a853043f` (the `restore` target for `db-migrate`; the three bash
  migration scripts restore the startup project themselves), `0b52e115`
  (W54) and `100e3912` (docs). Codex's second look found one more
  problem: the setup guide's `dotnet ef database update` had no
  `--context`, though the WebAPI has two contexts. It was broken before
  tonight; the guide runs `make db-migrate` now.
- Run 5 (21:23-21:30, `b6d16f70`, the docs commit amended afterwards):
  as run 4, and the scripts run directly on the untouched fresh clone
  restore for themselves: the migration is created and removed, dotnet ef
  says "Done." twice, no NETSDK1004.
- The branch was pushed at 21:33, `79cb67a7..100e3912`. No workflow ran.

### Interpretation

`[I]`. On a fresh clone every Makefile target and bash script that runs
`dotnet ef` now works, the bare `dotnet` commands name the solution, a
failed `dotnet ef` fails its script, and W54 is fixed without changing the
release's bytes. Left: the PowerShell scripts, not changed and not run
here (no `pwsh`); EF snippets in `DEBUGGING.md` and `adding-features.md`
that lack `--context`, as before; whether the fix works on a real Mac.

A lesson for the harness: an offline lab needs NuGet's HTTP cache as well
as its package folder.
