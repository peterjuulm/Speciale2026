# Main merged into the branch again, as a trial (20 October 2026)

Grounds: a merge of main into the WS branch in a scratch clone, built twice
on `arch` with `ci-local.sh`. Not pushed; the real merge waits for Leo's
decisions. Run by Claude at Leo's request, with a review of what is left on
the branch.

## Question

Main is 48 commits ahead of the branch since their merge base of 9 October,
among them WS's release pipeline change of 16 October and two releases.
Does the branch with main merged in still build every release output, and
twice the same?

## Setup

- The merge: `7e90bad9`, the branch's `56e4b4820` and main's `c87b2555`,
  tagged `v0.0.0-merge-trial.2` in the scratch clone only. Six files
  conflicted, all in the build and release setup: `global.json`, the
  `Makefile`, the secret scanner's allow list, and three workflows. They
  were resolved with the branch's build settings inside main's pipeline:
  the branch's SDK pin (10.0.401, roll-forward off) over main's `9.0.0`
  with `latestFeature`, the branch's SDK installer over main's
  `setup-dotnet` with `9.0.x` in the Windows job, and main's jobs, runners
  and checksum job around them. Main's commits touch no lock file, project
  file or product Dockerfile.
- `ci-local.sh` at `fe4be3c`, all six jobs, as for the delayed rebuild of
  the same day, with the same tools (`environment.txt`). The NuGet cache
  is warm from that rebuild; the frontend installs offline from the npm
  cache of 14/10. Run 2 starts when run 1 ends.
- What `ci-local.sh` builds is the branch's release commands, not main's
  pipeline: the images go to OCI files, not to a registry by digest as
  main's job pushes them. Of the tests, only those the MCP server and chat
  server images run in their builds; CI's .NET tests run in a check of
  their own (item 3 below).

## Expectation, written before the results

Written 17:00, while run 1 was in its first job.

1. All six jobs pass in both runs. Main's code compiles with SDK 10.0.401
   and the branch's settings.
2. Run 2 equals run 1 byte for byte: the frontend export, the four zips,
   both migrators and the SQL script, and the five images by manifest.
   Main's commits add code, not inputs, so nothing new can vary.

Added at 17:34, after the two runs and before the next check's results:

3. CI's .NET steps on the merge, as on 13/10 (`stage.sh`: restore, build,
   the three test tiers with CI's filters, tool restore, EF's check for
   model changes without a migration): every step passes. Main's new
   code and tests have not run on .NET 10 before.

## Commands

Verbatim in `data/2026-10-20-phoenix-merge-trial/arch/kommando.txt`.

## Result

`[V]` (`results.txt` and `environment.txt` in the data folder; the runs,
their logs, the comparisons, the check's logs and TRX files, and a git
bundle of the merge in private data).

1. Held. All six jobs passed in both runs, 16:58-17:14 and 17:14-17:33.
2. Held. Run 2 equals run 1: 1002 files by SHA-256 (the frontend export's
   995, the four zips, both migrators and the SQL script, the Windows ones
   unsigned), and the five images by manifest, config and every layer.
3. Held. Every step passed, 17:34-18:07. Unit 4731 passed, 44 skipped;
   integration 812 and 25; functional 159 and 5; none failed. EF found
   no model change without a migration. On 13/10 the merged branch had
   4681, 807 and 153 passed.

## Interpretation

**Main's 48 commits bring no new source of difference into the release.**
`[V]` for two builds on one machine. Under fixed conditions the merged
branch is as deterministic as the branch: every output twice the same.

**Main's code runs on .NET 10.** `[V]` for CI's .NET steps. Its new tests
pass with SDK 10.0.401 and the branch's packages; nothing in main's
commits needed a change for the move.

**The merge's work is in the build setup, not the code.** `[V]` All 21
conflicting hunks sit in `global.json`, the `Makefile`, the secret
scanner's allow list and three workflows. Both sides changed the release
pipeline in the same weeks; the code merged without a conflict.

## Caveats

- One machine, the same tools and warm caches for both runs. It shows
  determinism under fixed conditions, not across machines or time.
- `ci-local.sh` runs the branch's release commands. Main's pipeline around
  them did not run: the pushes by digest, the checksum job, the release
  jobs on WS's office runner.
- The Windows outputs are unsigned; signing is not reproducible anyway,
  and its check pastes the release's signatures (W59).

## Not tested

- The merged workflows on GitHub: PR validation, Main CI, a release.
- The merged tree on another machine, against these hashes.
- The migrator's smoke test, which the release job runs against a
  PostgreSQL service.
