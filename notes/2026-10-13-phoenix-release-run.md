# The release workflow on a test tag, 13 October 2026

## Question

Does the release workflow run end to end on GitHub's runners with the WS
branch's changes, none of which had run there: the restores before
`dotnet ef` (W53), the normalised zip packing (W48), the migrator built
from `src/DbMigrator` and its smoke test (W52), the SDK pin from
`global.json` and the Windows job on .NET 10?

## Setup

Run by Claude at Leo's request. The tag `v0.0.0-thesis.1` on the branch
head `82ea130a`, pushed to WS's private repository, starts
`03-release.yml`: build and tests, the frontend export, the migration
bundles with the smoke test against a PostgreSQL 17 service container,
five Docker images to WS's private registry, the Linux and Windows
publishes (the Windows ones signed), and a pre-release with the assets.
The hyphen makes it a pre-release, never `latest`. Leo chose the full run
over stopping before the pre-release; anyone in WS who watches the
repository's releases may get a notification. Afterwards the pre-release,
the tag, the image tags and the run are deleted; the run's logs are kept
in private data first.

## Expectation, written before the run

All `[I]`.

1. Every job succeeds, the pre-release included.
2. The smoke-test step applies all 150 migrations to the service database.
3. The Windows job publishes the migrator from `src/DbMigrator` and its
   `--help` run exits 0, and signing picks up the new file like the
   bundle before it.
4. Nothing in the run depends on the thesis machine: no step fails for a
   path, a locale or a tool that only exists here.

## Commands

The tag `v0.0.0-thesis.1` on `82ea130a`, pushed 09:53 (run
38365577952); the jobs followed with `gh run view`; the run's logs saved
to private data; afterwards the tag and the run deleted. Verbatim in
`data/2026-10-13-phoenix-release-run/arch/kommando.txt`.

## Result

`[V]` (the run's job and step results and logs), 07:53-08:21 UTC:

1. Expectation 1 failed. Every job succeeded except the Linux
   build-and-test leg: all 678 integration tests failed in their fixtures,
   where Testcontainers could not create its database container ("No such
   image: postgres:15.1") on the GitHub-hosted runner. The unit tests had
   passed. So the final release job was skipped: no pre-release, no
   notification, no release image tags.
2. Held. The smoke-test step applied all 150 migrations to the
   PostgreSQL 17 service database, after the locked restore and the
   migrator's publish.
3. Held. The Windows job published the migrator from `src/DbMigrator`,
   its `--help` run passed, signing chose it among 178 unsigned of 1049
   PE files, signed it, and the Authenticode check passed.
4. Held for what ran: the restores (W53), the normalised zip packing in
   the Linux publish (W48), the SDK from `global.json` and the .NET 10
   builds, on GitHub's runners.

Cleanup: no release existed; the tag and the run, with its artifacts,
were deleted. Fifteen image versions it pushed to WS's private registry
(five tagged `v0.0.0-thesis.1-build`) could not be deleted with Leo's
rights, a member's, and remain.

## Interpretation

**The branch's changes work on GitHub's runners.** `[V]` Every job that
builds or checks what the branch changed succeeded.

**The one failure is the branch's age, not its changes.** `[I]` The
branch left main on 14 September. Main has since moved its release
build's tests to WS's office runner, behind a repository variable, and
reworked that workflow; the branch's copy still runs them on a
GitHub-hosted runner, where the PostgreSQL image for Testcontainers was
not there. The fixture code is the same on both. Merging main into the
branch is the next step (Leo, 13/10).

## Caveats

- CI's files were not compared with local builds: the tag gives another
  `APP_VERSION`, so the bytes differ by design.
- PR validation did not run: only the release workflow did.
- Why Testcontainers did not pull the image itself was not investigated.
