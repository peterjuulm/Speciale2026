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
  main's job pushes them, and no tests run.

## Expectation, written before the results

Written 17:00, while run 1 was in its first job.

1. All six jobs pass in both runs. Main's code compiles with SDK 10.0.401
   and the branch's settings.
2. Run 2 equals run 1 byte for byte: the frontend export, the four zips,
   both migrators and the SQL script, and the five images by manifest.
   Main's commits add code, not inputs, so nothing new can vary.

## Commands

Verbatim in `data/2026-10-20-phoenix-merge-trial/arch/kommando.txt`.
