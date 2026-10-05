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

All 32 runs, 11:41-15:55. `rerun-all.sh` ended with "rerun done" at 15:55:06
and skipped L2-user_group, which had run first as the check.

| Run | Time | reprotest | Control | Experiment | Axes varied | Experiment processes with the variation |
| --- | --- | --- | --- | --- | --- | --- |
| L2-user_group | 11:41-11:49 | successful | `9283b29e…` | `9283b29e…` | 1 | 11 |
| L2-none | 11:50-11:59 | successful | `9283b29e…` | `9283b29e…` | 0 | - |
| L2-build_path | 11:59-12:07 | successful | `9283b29e…` | `9283b29e…` | 1 | 10 |
| L2-time | 12:07-12:15 | successful | `9283b29e…` | `9283b29e…` | 1 | 11 |
| L2-locales | 12:15-12:23 | **differences** | `9283b29e…` | `67d6d044…` | 1 | 11 |
| L2-umask | 12:24-12:32 | successful | `9283b29e…` | `9283b29e…` | 1 | 11 |
| L2-exec_path | 12:32-12:40 | successful | `9283b29e…` | `9283b29e…` | 1 | 12 |
| L2-timezone | 12:40-12:48 | successful | `9283b29e…` | `9283b29e…` | 1 | 10 |
| L2-environment | 12:48-12:56 | successful | `9283b29e…` | `9283b29e…` | 1 | 10 |
| L2-home | 12:56-13:06 | successful | `9283b29e…` | `9283b29e…` | 1 | 10 |
| L2-kernel | 13:06-13:14 | successful | `9283b29e…` | `9283b29e…` | 1 | 10 |
| L2-aslr | 13:14-13:22 | successful | `9283b29e…` | `9283b29e…` | 1 | 0 |
| L2-num_cpus | 13:22-13:28 | successful | `9283b29e…` | `9283b29e…` | 1 | 15 |
| L2-locales-fixed | 13:28-13:36 | successful | `9283b29e…` | `9283b29e…` | 1 | 9 |
| L2-all | 13:36-13:44 | **differences** | `9283b29e…` | `67d6d044…` | 11 | 14 |
| L2-all-fixed | 13:44-13:51 | successful | `9283b29e…` | `9283b29e…` | 11 | 15 |
| L1-none | 13:51-13:58 | successful | `ce650e0b…` | `ce650e0b…` | 0 | - |
| L1-build_path | 13:58-14:07 | **differences** | `35669df1…` | `1e77d374…` | 1 | 8 |
| L1-time | 14:07-14:16 | successful | `7c6ee157…` | `7c6ee157…` | 1 | 7 |
| L1-locales | 14:16-14:26 | **differences** | `c86c6789…` | `40fa6f02…` | 1 | 7 |
| L1-umask | 14:26-14:33 | successful | `3d56ba5d…` | `3d56ba5d…` | 1 | 7 |
| L1-exec_path | 14:33-14:42 | successful | `f8ff4343…` | `f8ff4343…` | 1 | 8 |
| L1-timezone | 14:42-14:49 | successful | `fdd4d257…` | `fdd4d257…` | 1 | 7 |
| L1-environment | 14:49-14:57 | successful | `a056c625…` | `a056c625…` | 1 | 7 |
| L1-home | 14:57-15:04 | successful | `9137d30b…` | `9137d30b…` | 1 | 7 |
| L1-kernel | 15:04-15:12 | successful | `080e4e33…` | `080e4e33…` | 1 | 7 |
| L1-aslr | 15:12-15:20 | successful | `664b5fdb…` | `664b5fdb…` | 1 | 0 |
| L1-num_cpus | 15:20-15:26 | successful | `e32606b2…` | `e32606b2…` | 1 | 7 |
| L1-locales-fixed | 15:26-15:34 | successful | `371347bf…` | `371347bf…` | 1 | 7 |
| L1-all | 15:34-15:41 | **differences** | `9fba1498…` | `006b685f…` | 11 | 7 |
| L1-all-fixed | 15:41-15:47 | **differences** | `82ade042…` | `7b11b10e…` | 11 | 7 |
| L1-user_group | 15:47-15:55 | successful | `de660ac3…` | `de660ac3…` | 1 | 7 |

`[V]` `summary.tsv`, stores, samples. "Axes varied" counts the `vary` entries
in reprotest's plan line for the experiment build; the control's plan varies
none in every run. "Experiment processes" is `analyze-samples.py`'s count of
dotnet processes that carry the axis's marker.

- The control varied nothing and the experiment exactly the axis asked for,
  in every run `[V]` the plan lines.
- No process of a control build did work in its experiment's window, in any
  run with a marker `[V]` `analyze-samples.py`. Every MSBuild node ran with
  `nodeReuse:false`, and no compiler server or MSBuild node was alive after
  any run (`leftover 0`).
- Layer 2's release is `9283b29e…` in every control build, the same as run 7
  of 23/9 and the six runs of 24/9. The system update of 4/10 changed
  nothing.
- L2-locales' experiment is 24/9's `67d6d044…` again, ten files. L2-all,
  which varies eleven axes at once, gives the same `67d6d044…`: no axis but
  the locale changes a byte of the release. With `LC_ALL=C.UTF-8` both are
  `9283b29e…`; under the fix the experiment's processes keep
  `LANG=et_EE.UTF-8`, and `LC_ALL` overrides it `[V]` samples.
- L2-aslr varied nothing: all 1402 samples of both builds show ASLR on
  (R1). L2-kernel switched ASLR off in the experiment, 668 samples against
  the control's 659 with ASLR on (R2).
- L2-num_cpus gave the experiment 12 CPUs. Its build took 2 minutes against
  the control's 4.
- L2-umask changes the modes of the same 142 files as on 24/9.
- Layer 1's hash list differs between runs in `spa.proxy.json` and
  `WebAPI.staticwebassets.runtime.json` only: both record the build path,
  and every reprotest run builds in its own random `/tmp/reprotest.XXXXXX`
  `[V]` `diff` of the control hash lists. So layer 1 is compared within a run
  only, and expectation 14 has to leave these two files out.
- L1-build_path differs in those two files only `[V]` `diff` of the hash
  lists. L1-locales differs in 14 files: the same four assemblies as layer
  2, copied into each project's `bin` that uses them. L1-umask changes 29
  modes, 644 to 664; the 605 files from the NuGet cache stay 0744.
- Neither of the two path-carrying files is in the release: `release.sha256`
  of L2-none lists neither `[V]`. They come only from `dotnet build`.
- L1-aslr varied nothing, like L2-aslr: ASLR on in all 1240 samples. L1-kernel
  had ASLR off in the experiment, 626 samples against 687.
- L1-all differs in 16 files: L1-locales' 14 and the two path files. Apart
  from the path files, its experiment output is byte-identical to
  L1-locales' experiment `[V]` `join` of the two hash lists. L1-all-fixed
  differs in the two path files only.
- L1-user_group's hash list equals L1-none's, apart from the two path files
  `[V]` `diff`. Both builds used the SDK copy in `/opt/rb1-dotnet`.

Per expectation: all fourteen held. 4 held for `aslr` only because nothing
was varied, and 14 with the two path files left out, since every run builds
in its own folder.

## Interpretation

**Phoenix's release survives every axis reprotest can vary on `arch`,
except the locale, and the locale pin fixes that.** L2-all is the strongest
single result: eleven axes at once give exactly the Estonian build's bytes,
so none of the other ten changes a byte, and with `LC_ALL=C.UTF-8` the
release is the one CI would ship. That is the WS branch's fix (`4e5237a3`)
measured under every variation together.

**Layer 1 adds only the two dev files.** With the locale pinned, `dotnet
build` differs across all eleven axes in `spa.proxy.json` and
`WebAPI.staticwebassets.runtime.json` alone, which carry the build path and
do not ship (W8, W9). The 15/9 layer 1 axis results that W10 rejected are now
measured with the compiler inside the variation: time, umask and exec_path
green, locales red as in layer 2.

**The protocol held.** No process crossed from a control build into its
experiment, nothing survived a run, and every variation reached every
process it could. The exception is reprotest's own: `aslr` varies nothing
(R1), so ASLR was varied only together with the kernel version (R2). Both
combinations came out green.

**The second user changes nothing.** `user_group` is green on both layers.
Building as `rb1b`, with the SDK in another folder and sudo's `PATH`, gives
the same release and, on layer 1, the same output apart from the path files.

## Caveats and not tested

- One run per axis. reprotest's random picks (the CPU sets, the hours of the
  time shift, the `setarch` architecture) were drawn once each.
- ASLR alone is untested (R1); `kernel` tests it only together with the
  kernel version.
- The builds' base environment was Claude Code's shell's (R4). Whether a
  clean `env -i` launch gives the same release is the next run.
- Rider was open during the batch, with another solution and no builds. The
  builds took about 4 minutes each against 2.5 on 24/9; likely Rider's
  background load, which can change timing, not bytes `[I]`.
- `fileordering`, `domain_host`, other machines and Windows are not covered.
- glibc has only `da_DK.UTF-8` and `en_US.UTF-8` generated; `et_EE.UTF-8` is
  not there `[V]` `locale -a`, `/etc/locale.gen` unchanged since March. So
  under `locales` only .NET sees Estonian: it takes the name from the
  environment through ICU. Tools that use glibc's locales fall back to C.
  It was the same on 24/9.
- When diffoscope finds no difference, reprotest replaces the experiment's
  store with a link to the control's `[V]` `run_diff()` in reprotest's
  `__init__.py`, and `store-L2-none/experiment-1 -> control`. So on a green
  run, the experiment column in `summary.tsv` repeats diffoscope's verdict; it
  is not a second reading. Only red runs keep the experiment's own files.
- reprotest sets the stored artifacts' mtimes to 1970 (`touch -d@0` at the end
  of `run_build()`), and diffoscope runs with `--exclude-directory-metadata=yes`
  `[V]` the code. Differences in loose files' timestamps cannot show here.
- The builds inherit the whole environment reprotest is started from
  (`make_build_commands(build_command, os.environ)`); its blacklist only
  applies in another mode `[V]` the code. This batch was started from Claude
  Code's shell, so both builds got ten `LC_*` categories set to
  `da_DK.UTF-8`, the desktop session's variables, and 27 `CLAUDE_*` variables
  `[V]` `/proc/<pid>/environ` of a running build. reprotest overrides only
  `LANG`, `LANGUAGE`, `TZ` and `HOME` here. Both builds share that base, so the
  comparisons hold. .NET's culture should still be invariant: ICU reads
  `LC_ALL`, then `LC_MESSAGES`, then `LANG`, and the first two are unset
  `[I]`, not measured. A batch started from another shell sees another base.
- `user_group` runs the build through `sudo -E`, which keeps that
  environment: `rb1b`'s build had the control's `LANG`, `TZ` and `HOME`
  `[V]` samples.
- The time axis shifts only the experiment's clock, by 398 days plus some
  hours. reprotest skips the shift, with one INFO line in the log, when the
  newest file in the source tree is more than 398 days old `[V]`
  `faketime()` in `build.py`. The lab is an export of a 24/9 commit, and the
  log shows the shift applied. An export of an old release would not be
  shifted.
