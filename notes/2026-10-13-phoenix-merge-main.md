# Merging main into the WS branch, 13 October 2026

## Question

The WS branch `thesis/reproducible-builds` left main on 14 September
(`a2dc1d5b`). By 13 October main was 122 commits ahead, still on .NET 9.
What do those commits do to the branch's reproducibility work, and does the
merged branch still build, test and release reproducibly?

## Setup

Run by Claude at Leo's request, on `arch`. A merge, not a rebase: the notes
cite the branch's commits by hash, and a rebase would orphan them. On top
of the pushed `82ea130a`, and pushed together after results 7-9:

- `459de87e`, the merge of main.
- `bc0c52f6`, main's frontend lock filled again (W41).
- `805275c4`, the design-time factories kept in the startup projects.
- `79cb67a7`, the release tag checked and the migrator smoke-tested both
  ways.

SDK 10.0.401; Node 22.23.3 from nodejs.org, its SHA-256 checked against
`SHASUMS256.txt`; npm 10.9.9. Downloads, approved by Leo: NuGet.Packaging
6.12.5 and its NuGet.* dependencies, about 106 MB of npm packages, Node
22.23.3 (57 MB). Database runs went to a PostgreSQL 17 container without a
network, through its Unix socket, with the tools in a namespace without a
network. Runs that read the developers' configuration used an empty home
folder, for the reason in result 3. Heavy runs went one after the other:
a first attempt at results 7 and 9 ran both at once, on `805275c4`, and
the kernel's out-of-memory killer stopped both at 11:23; their partial
logs are kept in private data.

## Expectation

None written down before these runs: they check a merge, not a claim.

## What the merge met

Read in main's commits and code `[V]`:

- Main deleted the Dependabot configuration (#646). The merge follows main;
  the branch's Dependabot change of the morning falls away, and its PR
  check that the Dockerfiles build in `global.json`'s SDK stays.
- Main moved its release tests to an office runner behind a repository
  variable, moved the migration checks into the reusable backend build
  (#787), and made the Windows publish a reusable workflow that builds on
  Linux and signs through a Docker image. The merge keeps all of it and
  ports the branch's changes into the new places: the SDK from
  `global.json`, one locked restore and publishes without their own,
  the version from `APP_VERSION`, the migrator from `src/DbMigrator`.
- Main sets the release version with `-p:` flags and hard-codes
  `InformationalVersion` in two project files. The merge keeps the
  branch's single `APP_VERSION`, read by `Directory.Build.props`, so
  restore and publish see the same version (W45).
- Main needs Node 22 for the frontend. `.nvmrc` and the WebAPI Dockerfile
  now pin 22.23.3 exactly, the tarball by SHA-256 (W40).
- Main's new frontend lock again had 362 of 1406 entries without
  `resolved` and `integrity` (W41).
- Main's #619 (22/9) added a guard: a design-time EF command refuses a
  connection string whose host is not local, unless
  `WS_EF_ALLOW_REMOTE=1`, and refuses a missing one. Both of main's
  factories call it, and main reactivated a SQL Server factory whose
  context derives from `DatabaseContext`, so through covariance three
  factories in Infrastructure fit `DatabaseContext`, and file order
  chooses.

## Commands

Verbatim in `data/2026-10-13-phoenix-merge-main/arch/kommando.txt`, the
numbers in `results.txt` beside it. CI's .NET steps ran through a script
in Leo's private repository; `kommando.txt` writes out its steps.

## Result

`[V]` (logs, test results, the runs' commands in `kommando.txt`):

1. The merge commit `459de87e`. CI's .NET steps: 4679 unit, 807
   integration and 153 functional tests passed, none failed. The migration
   guard reported no model changes when rerun; its first run stopped with
   "Build failed", which did not happen again. The frontend on Node 22:
   `npm ci`, lint, 1610 tests in 164 suites and `next build` passed.
2. The lock fill `bc0c52f6`: 362 entries filled with
   `experiments/phoenix-fe/fill-lock.js`, 20 of 20 controls matching, no
   entry added, removed or changed in version.
3. Main's migrator design, as a bundle built the release's way
   (`dotnet ef migrations bundle`, startup WebAPI) from the merge commit's
   tree: with a remote host in `ConnectionStrings__CatalogConnection`, as
   the migrations image runs it, the guard stops it ("not a local host");
   with `--connection` alone, as the release runbook runs it, the guard
   stops it ("No database connection string"); exit 1 both times, before
   any migration. Building that bundle on this machine had failed first:
   main's design-time configuration also reads the developer's .NET user
   secrets, which here name a remote host, and the guard refused it. With
   an empty home folder it builds, as it would in CI.
4. The migrator on `805275c4`, from an empty folder: the environment alone
   and `--connection` alone each apply all 160 migrations, and the verbose
   log names `MigratorContextFactory`; `--connection` overrides a wrong
   value in the environment; a second run applies nothing; with neither it
   stops with "The ConnectionString property has not been initialized",
   having contacted no server, also with the developer's user secrets in
   place; a provider other than PostgreSQL is refused; a remote host in the
   environment is tried, with no guard in the way.
5. On `805275c4`: the solution builds; the placement test and main's guard
   tests pass, 29 of 29.
6. The release's smoke step on `79cb67a7`, taken from the workflow and run
   against `postgres:17-alpine` with trust authentication: 160 migrations
   through `--connection` and 160 through the environment, and the run with
   neither fails. The Windows publish's new tag check accepts `v1.0.51`
   and `v0.0.0-thesis.2` and refuses `1.0.51`, `v1.0` and `v1.0.51-`.
7. CI's .NET steps on the head `79cb67a7`, with an empty home folder:
   4681 unit, 807 integration and 153 functional tests passed, none
   failed, and the EF check found no model changes, at the first run.
   The two unit tests more than in 1 are the placement test's.
8. The migrator built twice from the head, at two paths: identical, for
   linux-x64 (`062f730d…`) and win-x64 (`9f601966…`, cross-built,
   unsigned).
9. The whole release built twice under reprotest's `none` on the head:
   all 2124 files identical, and the normalised zips too (WebAPI
   `548f5fd3…`, job worker `dbd40cc6…`). The zips packed the old CI way
   differ, as in W48; the release no longer packs them so.
10. Main's CI workflow on GitHub, started by hand on the branch after the
    push (`02-main-ci.yml`, run 38387985880, 13:07-13:27, the backend on
    WS's office runner): every job passed. The backend's 4681 unit, 807
    integration and 153 functional tests, the counts of 7, and the EF
    check; the frontend's 1610 tests; the Node services' tests; all five
    images built, not pushed.

## Interpretation

**Main's design-time guard and the release's migrator want different
things.** `[V]` The guard keeps developers' commands away from real
databases; the migrator exists to change them. As merged, the guard stops
the migrator in both deployment paths (3). So the migrator now creates its
context itself, with a factory in its own project that reads only the
deployment contract, and the developers' factories, guard included, live in
the WebAPI, the startup project of every `dotnet ef` command here. EF takes
a startup project's factories for the exact context each declares; nothing
in Infrastructure is left for file order to choose between, which a unit
test now checks.

**The merge keeps main's intent where the two met.** `[V]` Main's runner,
signing, migration checks and the removal of Dependabot stay; the branch's
measured fixes go into main's new structure instead of beside it.

**The merged branch is as reproducible as the branch was.** `[V]` On the
head the whole release and the migrator are identical in two builds, and
CI's tests pass, here and on WS's office runner (7-10), with main's 122
commits, Node 22 and the new factories in. Measured under `none` only: the varied axes have not run on
the merged code.

## Caveats and not tested

- On GitHub only main's CI ran on the merged branch (10). Pushing the
  branch starts no workflow: PR validation needs a pull request, the
  release a tag, and neither has run on it.
- The migrations image was not built: its base images and a NuGet restore
  inside the build need downloads.
- The Windows publishes were not built here, and the Windows migrator was
  only cross-built, not signed (8).
- The released migrators were not run; result 3 is a bundle from main's
  code in the merge commit's tree, built here.
- `79cb67a7` differs from `805275c4` only in two workflow files and the
  gitleaks configuration, so results 4 and 5 hold for it `[I]`.
- One machine, and reprotest's `none` only.
