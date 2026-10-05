# Phoenix's release with reprotest started from a clean environment

Run 5 October 2026 on `arch`, after the [full rerun](2026-10-05-phoenix-rerun.md).
The [reprotest probe](2026-10-05-reprotest-probe.md) found that the builds
inherit the whole environment reprotest is started from (R4): the full
rerun's builds carried the 105 variables of Claude Code's shell, nine Danish
`LC_*` among them. This checks whether that touched any result.
Data: `data/2026-10-05-phoenix-clean-launch/arch/`.

Phoenix is Weel-Sandvig's code and this repo is public. reprotest logs, stores,
samples and mode lists stay locally with Leo.

## Question

Started under `env -i` with five listed variables, does layer 2 still give
the release `9283b29e…`, with nothing and with everything varied?

## Setup

- As in the full rerun, with one change to `experiments/phoenix-rt/run.sh`:
  reprotest starts under `env -i HOME USER LOGNAME SHELL PATH`, with `PATH`
  `/home/leos/.local/bin:/usr/local/bin:/usr/bin`. The full rerun's version is
  commit `9f66d25`.
- The sampler now also records each process's number of environment
  variables (`nenv`) and of `LC_*` variables (`nlc`).
- Lab `/private/tmp/rb1-phoenix`, the export of `4e5237a3`, checked again
  with `labcheck.py`: 5478 files, 0 missing, 0 differing, 0 extra `[V]`.
- Two runs: L2 `none`, and L2 `all` with `LC_ALL=C.UTF-8`, the two that
  cover the most. The environment block is the full rerun's.

## Expectation, written before the runs

1. L2 `none`: green, `release.sha256` `9283b29e…`.
2. L2 `all` with the fix: green, `9283b29e…`, all eleven axes in the
   experiment's processes.
3. Every dotnet process carries a small environment: no Danish `LC_*` and
   none of the session's variables. `nenv` well below the full rerun's
   processes, which carry over 100; `nlc` 0 or 1 (`LC_CTYPE` from Python's
   locale coercion, R4), plus `LC_ALL` where it is set.
4. No process left after either run.

If 1 and 2 hold, the inherited environment changed no result of the full
rerun, and R4 closes as a protocol fix.

## Commands

Verbatim in `kommando.txt`.

## Result

| Run | Time | reprotest | Control | Experiment | Axes varied | `nenv` per process | `nlc` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| L2-none | 16:22-16:30 | successful | `9283b29e…` | `9283b29e…` | 0 | 18-27 | 1 |
| L2-all-fixed | 16:30-16:37 | successful | `9283b29e…` | `9283b29e…` | 11 | 19-33 | 2 |

`[V]` `summary.tsv`, stores, samples.

- Both give the release of the full rerun, of run 7 of 23/9 and of 24/9.
- No dotnet process in either run had more than 33 environment variables.
  The main processes have the fewest; MSBuild's nodes and the compiler
  server carry the ones MSBuild adds. A build process of the full rerun had
  over 100 `[V]` `/proc/<pid>/environ`, 5/10.
- `nlc` is 1 in L2-none, and 2 in L2-all-fixed, where `LC_ALL=C.UTF-8` is on
  every dotnet command of both builds. The one other `LC_*` variable is not
  named by the sampler; the probe's clean round had `LC_CTYPE=C.UTF-8` there.
- In L2-all-fixed all 15 experiment processes carry the variation, and no
  control process did work in the experiment's window `[V]`
  `analyze-samples.py`. No process was left after either run.

All four expectations held.

## Interpretation

**The inherited environment changed no result.** With nothing varied and
with everything varied, a build started from five listed variables gives
the same release as the full rerun's builds, which carried over 100. So the
full rerun's results stand, and from now on `run.sh` starts reprotest this
way: the builds see the same environment whoever starts them, and no
session variables reach them. R4 closes as a protocol fix.

## Caveats and not tested

- Two runs, on layer 2 only. The other axes and layer 1 were not repeated
  under the clean launch.
- The one remaining `LC_*` variable is taken to be Python's `LC_CTYPE`
  coercion from the probe, not named here.
- A clean launch still inherits reprotest's own fixed values and the NuGet
  cache in `/tmp/dch`; those are the same as in the full rerun.
