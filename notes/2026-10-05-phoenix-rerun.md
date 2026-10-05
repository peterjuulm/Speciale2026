# Phoenix layers 1 and 2: every reprotest axis, in full

Run 5 October 2026 on `arch`. A full rerun of
[phoenix-rerun](2026-09-24-phoenix-rerun.md), which stopped after 6 of 30 runs
on 24/9, with two additions: the second user (`user_group`) and MSBuild's node
reuse switched off.
Data: `data/2026-10-05-phoenix-rerun/arch/`.

Phoenix is Weel-Sandvig's code and this repo is public. reprotest logs, stores,
samples and mode lists stay locally with Leo.

## Question

With the variation reaching every build process, which of reprotest's axes
does each layer tolerate? Does building as a second user change anything? And
with node reuse off, is anything from one build still running in the next?

## Why all 30 again

The machine was updated and rebooted on 4/10: kernel 7.2.6 to 7.2.8, and new
glibc, coreutils and util-linux `[V]` `/var/log/pacman.log`. The protocol
changes too. Continuing after 24/9's six runs would put two systems and two
protocols in one table. So all 30 runs again, plus `user_group` on each layer:
32 runs.

## Setup

As in [phoenix-rerun](2026-09-24-phoenix-rerun.md), with these changes:

- Lab `/private/tmp/rb1-phoenix`, the export of `4e5237a3`, untouched since
  24/9 except for one file. `labcheck.py` found Rider's
  `.idea/.idea.WS.Phoenix/.idea/workspace.xml` extra, written 24/9 at 15:48,
  when the lab was opened in Rider after the batch stopped. It was removed.
  Then 5478 files, 0 missing, 0 differing, 0 extra, and no `bin` or `obj`
  `[V]`.
- `MSBUILDDISABLENODEREUSE=1` on every dotnet command. The sampler now records
  whether each MSBuild node was started for reuse. After each run, `run.sh`
  lists any compiler server or MSBuild node still alive and counts them in
  `summary.tsv`.
- The NuGet cache. `/tmp` is a tmpfs, so the reboot emptied
  `DOTNET_CLI_HOME=/tmp/dch` and the packages in it. Before the runs, one
  locked restore of the solution, in a copy of the lab that was then deleted,
  filled it again from nuget.org: 4.3 GB in 49 s `[V]`. Every run starts with a
  full cache, as on 24/9.
- `user_group`: the experiment build runs as `rb1b`. Both builds use the SDK
  copy in `/opt/rb1-dotnet` (same `csc.dll`), since `rb1b` cannot reach
  `/home/leos`. A second sampler runs as `rb1b`; the mode lists go through
  `/private/tmp/rb1-shared`. The restore recreated `NuGet.Config` with mode
  0600, and `run.sh` makes it 0644 before each `user_group` run.
- Environment in `environment.txt`. `dotnet --info` is unchanged from 24/9
  `[V]` diff.
- Order: layer 2's `user_group` first and alone, as a check of the new code
  in `run.sh`. Then `rerun-all.sh`, which skips a label that is already done.
- Rider stays open, with another solution (the `WS.Phoenix-repro` worktree).
  Nobody builds in it during the runs. The sampler skips Rider's own
  processes, which carry `JetBrains` in their command line.

## Expectation, written before the runs

1-11 are the expectations of 24/9, unchanged:

1. L2 `none`: green, and `release.sha256` is `9283b29e…`, as in run 7 of 23/9
   and the six runs of 24/9. The system update changes nothing.
2. L2 `build_path`, `time`, `umask`, `exec_path`: green.
3. L2 `locales`: red, and the experiment's `release.sha256` is 24/9's
   `67d6d044…`. With `LC_ALL=C.UTF-8`: green.
4. L2 `timezone`, `environment`, `home`, `aslr`, `num_cpus`: green.
5. L2 `kernel`: green, weakly held.
6. L2 `all`: red, from the locale alone. `all` with the fix: green.
7. In every run, all dotnet processes of the experiment build carry the
   variation, and nothing from the control build does its work.
8. L1 `none`: green, with a hash list not measured before.
9. L1 `build_path`: red, only in `spa.proxy.json`,
   `WebAPI.staticwebassets.runtime.json` and the hash list.
10. L1 `locales`: red in the same assemblies as layer 2; with the fix green.
11. L1, the other axes as for layer 2. `all` red; `all` with the fix red only
    from the two json files.

New:

12. Node reuse off: every MSBuild node starts with `nodeReuse:false` and is
    gone when its build ends. No process is left after any run.
13. L2 `user_group`: green, and `release.sha256` is `9283b29e…`. Where the SDK
    is installed does not reach the release. Every process of the experiment
    build runs as `rb1b`, with its own compiler server.
14. L1 `user_group`: green, with the same hash list as L1 `none`. Weakly
    held: layer 1's output holds the app host, which comes from the SDK's
    folder. The copy is byte-identical, so the output should be too.

## Commands

Verbatim in `kommando.txt`.

## Result

## Interpretation

## Caveats and not tested

- glibc has only `da_DK.UTF-8` and `en_US.UTF-8` generated; `et_EE.UTF-8` is
  not there `[V]` `locale -a`, `/etc/locale.gen` unchanged since March. So
  under `locales` only .NET sees Estonian: it takes the name from the
  environment through ICU. Tools that use glibc's locales fall back to C.
  It was the same on 24/9.
