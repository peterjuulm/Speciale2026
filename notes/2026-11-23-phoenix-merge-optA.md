# Main merged into the branch again, with the migrations in their own project (23 November 2026)

Grounds: the merge of main (`8ed4010da`) into the WS branch
`thesis/reproducible-builds`, resolved by Claude in a side session and
checked on Leo's Mac Studio (`macstudio`) and on `arch`. Leo chose
"option A" for the migrator after a Fable review. Run at the writing
session's request. The merge is `8f4227eb2`, and `30b5c745d` on top of it
fixes two hadolint warnings in the WebAPI Dockerfile.

## Question

Main moved the PostgreSQL migrations into a project of their own,
`src/Infrastructure.Migrations` (#1139, 23/11). The branch's release
migrator, `src/DbMigrator`, read them from `Infrastructure`. With
DbMigrator kept and pointed at the new project (option A), does the
merged branch do the following?

- build, restore locked and pass CI's tests;
- migrate a database fully;
- give the same release outputs twice;
- generate the same release SQL as main?

## Setup

- **The merge.** 16 conflicting files. Option A:
  - DbMigrator references Infrastructure.Migrations and names it as the
    migrations assembly.
  - Infrastructure.Migrations moves to net10.0 and EF 10.0.12, with a
    lock file.
  - The developers' design-time factories move from the WebAPI into
    Infrastructure.Migrations, the startup project of main's `dotnet ef`
    commands.
  - The release's smoke test also counts the migration history.
  - Lock files are regenerated with SDK 10.0.401.

  The full list is in the merge's commit message, and in the side
  session's note (not in this repository).
- Tested as `81b0e8450` and `f88ddf722`, the same trees as `8f4227eb2`
  and `30b5c745d`. The two were later re-parented onto the branch's tip
  (`a50671fd1`, the npm pin plus a removed test workflow) without a change
  of tree.
- **`macstudio`:** SDK 10.0.401 in `~/rb1-dotnet-10.0.401`, from the
  branch's installer (its fallback on Apple's Python 3.9.6). The checks
  ran in the merge worktree, and the publishes in `git archive` exports
  under `/private/tmp`.
- **`arch`:**
  - SDK 10.0.401 in `~/rb1-dotnet-10.0.401`, installed the same day by
    the branch's installer.
  - Docker 29.9.2, with PostgreSQL 17 in throwaway containers.
  - Every heavy step under the shared memory guard
    `/tmp/claude-1000/ws-mem-run.sh` (a lock and a systemd scope with
    MemoryMax). It runs in the tmux session `lab`, which Leo watched.
  - `LC_ALL=C.UTF-8` as on CI's runners. `arch`'s shell is Danish, and
    Part 5 of the result shows why that matters.
  - The source is a `git clone --shared` of Leo's clone in
    `/private/tmp/rb1-merge-src`, with the branch from a bundle.

## Expectation, written before the run

Written 16:35. By then the `macstudio` checks (1 and 3-5 below) and the
first `arch` migrator tests had run in the side session, and D1 on `arch`
had restored, built and run the unit tier. The rest of `arch` (the
integration and functional tiers, D2-D5) had not run.

1. **CI's .NET job on both machines:**
   - the locked restore with `GITHUB_ACTIONS=true` (no NU1004 or NU1201);
   - the Release build;
   - `verify-nuget-downloads.py`;
   - the model check ("No changes");
   - all three test tiers pass on `arch`, as the trial merge's did on
     20/10 (unit 4731, integration 812, functional 159 then; more now).
2. **The migrator against PostgreSQL 17:**
   - The release's own smoke test passes: 200 migrations, newest
     `20261120161834_FrequentAutovacuumForFirstLevelData`.
   - A second run applies nothing.
   - The migrator as git merged it, with DbMigrator before option A,
     applies nothing and exits 0, and the new count check fails it.
3. **Publishes twice, from two paths:** DbMigrator linux-x64 and win-x64,
   the WebAPI and the job worker. Identical, and
   `Infrastructure.Migrations.dll` is not in the WebAPI or job worker.
   On `arch` also identical to `macstudio`'s, though that has not been
   shown for the .NET outputs across these two machines.
4. **The release SQL** equals main's published
   `bootstrap-postgresql-v1.0.60.sql`, apart from what EF 10 writes
   differently and the one migration main added after v1.0.60.
5. **Memory:** the peak of `dotnet publish src/WebAPI` on the merge is
   not above main's, since neither compiles the migrations.
6. **The migrations image** builds and migrates a database fully (200
   rows).
7. **The whole release twice on `arch`** (`rebuild.sh`, adapted to the
   merge's SQL step): every output equal between the two runs.
6b. Added on 24 November at 09:02, before D4 ran: the release workflow
   does not build the migrations image (it builds five images), so D4
   also builds it twice, as the release builds its images (BuildKit
   v0.33.1, `--no-cache`, `SOURCE_DATE_EPOCH` the commit's time,
   `rewrite-timestamp`), from clones at two paths. The two give the same
   manifest. `[I]` It has the WebAPI image's shape (the pinned SDK image
   builds, the pinned ASP.NET image runs), and that matched GHCR on
   14/10. Its final stage runs one `RUN chmod` as root, which on x86-64
   adds nothing of the builder's.
8. Added on 24 November at 08:51, before D4 and D5 ran (`arch` went off
   the network on 23/11 before them): the release SQL of D5, generated on
   Linux under `LC_ALL=C.UTF-8`, equals `macstudio`'s invariant-culture
   script of check 4 (`d46aeeb1…`). Same commit tree and the same
   `dotnet-ef`, and .NET reads `C.UTF-8` as the invariant culture.

## Commands

Verbatim in `data/2026-11-23-phoenix-merge-optA/<machine>/kommando.txt`.

## Result

`[V]` throughout, from the logs and summaries in the data folders.

### `macstudio`

| | Check | Result |
| --- | --- | --- |
| 1 | locked restore with `GITHUB_ACTIONS=true` | exit 0, no NU1004 or NU1201 |
| 1 | Release build | 0 errors |
| 1 | `verify-nuget-downloads.py --tools` | all ok |
| 1 | model check | "No changes have been made to the model since the last migration" |
| 1 | unit tier | 6443 passed, 34 skipped, 0 failed; among them PostgresMigrationsTests (1), DesignTimeFactoryPlacementTests (3) and ConnectionStringSafetyTests (27) |
| – | `PostgresMigrations.g.cs` | its 200 names in the files' ordinal order. MSBuild sorts wildcard results ([phoenix-cross-machine](2026-09-23-phoenix-cross-machine.md)) |
| – | `dotnet ef migrations list --no-connect` | with Infrastructure.Migrations as startup: 200, through `DatabaseContextDesignTimeFactory`. With DbMigrator as startup: 200, through `MigratorContextFactory`. SQL Server: 5, through `SqlServerDatabaseContextFactory` |
| 3 | publishes twice | 1153 files identical between the two paths: DbMigrator linux-x64 and win-x64, the WebAPI and the job worker. No `Infrastructure.Migrations.dll` in the WebAPI or job worker |
| 4 | release SQL against v1.0.60's | identical, with the invariant culture, once three things are set aside: EF's version in 200 history rows, EF 10's 199 per-migration transactions, and the 5 blocks of main's newer `20261118093436_AlarmRepeatCounter`. Under the Mac's region (Denmark), the two `ALTER TABLE` lines of `20261120161834` differ: `0,01` for `0.01` |

### `arch`

| | Check | Result |
| --- | --- | --- |
| – | SDK | 10.0.401 installed by the branch's installer into `~/rb1-dotnet-10.0.401`: the archive's SHA-512 matched the lock, runtime 10.0.12 alone |
| 1 | locked restore (D1) | all seven projects restored, no NU1004 or NU1201 |
| 1 | build | succeeded, 0 errors |
| 1 | NuGet check | as CI's build job: exit 0. As the release's migration job (a CLI home of its own, `--tools`): the packs and all three tools ok |
| 1 | model check | "No changes" |
| 1 | the three tiers | unit 6449 passed, 28 skipped. Integration 966 passed, 19 skipped (11 min). Functional 386 passed, 1 skipped. None failed |
| 2 | M1, the release's smoke test (verbatim) | both paths: 200, newest `20261120161834_FrequentAutovacuumForFirstLevelData`; without a connection string it fails; exit 0 |
| 2 | M2, the migrator again | nothing applied, exit 0 |
| 2 | M3, the migrator as git merged it | **exit 0, 0 migrations**: only the history table |
| 2 | M4, the smoke test with that migrator | the count check fails it, exit 1 |
| 3 | D2: the publishes twice, from two paths | 1153 files identical between the two paths, **and identical to `macstudio`'s 1153**: DbMigrator linux-x64 and win-x64, the WebAPI and the job worker. Built on macOS arm64 and on Linux x86-64. No `Infrastructure.Migrations.dll` in the WebAPI or job worker. DbMigrator linux-x64's publish peaked at 9629 MiB and 8869 MiB (it compiles Infrastructure.Migrations) |
| 5 | D3: peak memory of `dotnet publish src/WebAPI`, from a fresh export | merge (SDK 10.0.401): 2038 MiB. main `8ed4010da` (SDK 9.0.123): 1946 MiB, so the merge is 4.7 % above. Neither publish compiles or ships the migrations (0 `Infrastructure.Migrations.dll`). The restores before them peaked at 5214 MiB and 4898 MiB |
| 6 | D4: the migrations image | not yet: the first attempt stopped on an upper-case image tag, and `arch` went off the network before the second ran (Caveats) |
| 7 | D5: the whole release twice | not run: `arch` went off the network during the v0.0.0-thesis.6 rebuild that ran before it |

D1's first pass printed exit 1 after every step: its helper for the
scope's peak memory read a two-line `/proc/self/cgroup`. The test lines
show the true outcomes, and the build, NuGet and model checks were rerun
with the helper fixed (step 11).



### GitHub

The merge was pushed to the branch after it passed on `arch`. Leo's
go-ahead covered that. Then the repository's read-only
`04-manual-checks.yml` ran on the branch with `check-type=all`:
[run 45217454796](https://github.com/Weel-Sandvig/WS.Phoenix/actions/runs/45217454796),
on the office runner `ws-office`. All seven jobs passed:

- the backend build and the backend tests: unit 6449 of 6477,
  integration 966 of 985 and functional 386 of 387 passed, the same
  counts as on `arch`;
- the frontend's lint, test and build;
- Trivy;
- the secrets history scan.

### A culture bug in main's newest migration

- M5, `arch`: the merged migrator under `LANG=da_DK.UTF-8` (no `LC_ALL`)
  applies 199 migrations, then stops at `20261120161834`:
  `42601: syntax error at or near "01"`. Npgsql writes the migration's
  storage parameters (`0.01`) with the current culture.
- main's own released migrator, `v1.0.60` (EF 9, Npgsql 9, its SHA-256
  checked against the release's `SHA256SUMS`), does the same. Under C it
  applies 199. Under `da_DK.UTF-8` it fails with the same error and rolls
  back to 0.

## Interpretation

## Caveats

## Not tested
