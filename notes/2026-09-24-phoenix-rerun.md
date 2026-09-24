# Phoenix layers 1 and 2 again: every reprotest axis, the new protocol

Run 24 September 2026 on `arch`, after
[phoenix-layer2-reprotest](2026-09-24-phoenix-layer2-reprotest.md) and
[toolchain-servers](2026-09-24-toolchain-servers.md) changed how we run
reprotest. Replaces the axis runs of
[phoenix-reprotest](2026-09-15-phoenix-reprotest.md) (layer 1, 15/9) and
[phoenix-layer2-reprotest](2026-09-24-phoenix-layer2-reprotest.md) (layer 2,
this morning).
Data: `data/2026-09-24-phoenix-rerun/arch/`.

Phoenix is Weel-Sandvig's code and this repo is public. reprotest logs, stores,
samples and mode lists stay locally with Leo.

## Question

With the variation now reaching every build process, which of reprotest's
axes does each layer tolerate? And do the axes we never ran on Phoenix
(timezone, environment, home, kernel, aslr, num_cpus, domain_host) change
anything?

## Setup

- Lab `/private/tmp/rb1-phoenix`: the export of `4e5237a3`, the branch commit
  that adds `LC_ALL: C.UTF-8` to the Linux release jobs (pushed 24/9 at
  14:50). It differs from `2570034b` only in `.github/workflows/03-release.yml`,
  which no build step reads `[V]` `git diff --stat`. Checked with
  `labcheck.py` before the first run: 5478 files, 0 missing, 0 differing,
  0 extra.
- `experiments/phoenix-rt/run.sh LAYER AXIS`, for every run:
  - `dotnet build-server shutdown` at the start and at the end of every build;
  - `--min-cpus 2`: both builds get two CPUs unless `num_cpus` is varied,
    where the experiment gets 3 to 16;
  - `experiments/sample-dotnet.py` around the run, with a marker per axis,
    and `analyze-samples.py` to check that the experiment's processes carry
    the variation;
  - a mode list of the output from each build.
- Layer 1: `dotnet build` of WebAPI and BackgroundJobExecutor, as on 15/9. The
  artefacts are a hash list of every file under `src/*/bin`, plus our
  assemblies and WebAPI's json files.
- Layer 2: the release job's sequence, as this morning. The artefacts are
  `release.sha256` plus our assemblies and launchers.
- Per layer, 15 runs: `none` (nothing varied), the eleven single axes
  build_path, time, locales, umask, exec_path, timezone, environment, home,
  kernel, aslr, num_cpus, then `locales` with `LC_ALL=C.UTF-8` on the dotnet
  commands, `all` (everything except user_group, fileordering and domain_host)
  and `all` with `LC_ALL=C.UTF-8`. Layer 2 first.
- Not here: `fileordering` needs `disorderfs`; `user_group` runs after this
  batch (below); `domain_host` cannot run on `arch`. Without sudo it calls
  `domainname`, which Arch does not have: "domainname: command not found",
  exit 127 in a smoke test on the minimal .NET project `[V]`.
- The sampler cannot read a process's personality: `/proc/<pid>/personality`
  needs ptrace rights, and Yama's `ptrace_scope` is 1 `[V]`. So `kernel`
  (uname 2.6) is checked only in reprotest's log, which names the setarch
  arguments. ASLR is read from the stack address in `/proc/<pid>/maps`: with
  ASLR off, the main stack ends at `7ffffffff000` `[V]` checked against
  `setarch -R`. A smoke test found the first sampler version crashing on the
  personality read for every process; it was fixed before these runs.
- `user_group`, prepared during the batch. Leo ran
  `experiments/phoenix-rt/setup-user-group.sh` as root at 15:00: user `rb1b`
  (uid 952), the SDK copied to `/opt/rb1-dotnet` (same `csc.dll`,
  `644a4d33…`), and reprotest's own sudo rules, checked with `visudo`. The first
  smoke test on the minimal .NET project failed: as `rb1b`, `dotnet
  build-server shutdown` and `dotnet build` stop on "Failed to read NuGet.Config
  due to unauthorized access". NuGet creates `NuGet.Config` with mode 0600
  `[V]`. It lists only nuget.org, so it was made 0644. The second smoke test
  was green, and the samplers, one per user, show every process of the
  experiment build running as `rb1b`, with its own compiler server `[V]`.
  Phoenix's `user_group` runs follow this batch: `run.sh` cannot be changed
  while it runs, since bash reads a script as it executes it.

## Expectation, written before the runs

Layer 2:

1. `none`: green, and `release.sha256` identical to run 7 on 23/9, manifest
   `9283b29e…`. The first layer 2 reprotest build on more than one CPU.
2. `build_path`, `time`, `umask`, `exec_path`: green, as before.
3. `locales`: red, the same ten files as this morning's run 2. With
   `LC_ALL=C.UTF-8`: green.
4. `timezone`, `environment`, `home`, `aslr`, `num_cpus`: green. The lab's
   Copenhagen, `da_DK` and 16-core builds already matched reprotest's
   `GMT+12`, `C.UTF-8` and one-CPU builds (W28). `home` does not reach dotnet
   or NuGet, because `DOTNET_CLI_HOME` points both elsewhere.
5. `kernel` (uname reports 2.6): green. It ran on the minimal project in the
   smoke test; whether a 2.6 kernel version changes anything in Phoenix's
   build is weakly held.
6. `all`: red, from the locale alone. `all` with the fix: green.
7. In every run, all dotnet processes of the experiment build carry the
   variation, and nothing from the control build does its work.

Layer 1:

8. `none`: green. The hash list is new: the lock files and the
   `RuntimeIdentifiers` change have come in since the last layer 1 manifest.
9. `build_path`: red, and only in `spa.proxy.json` and
   `WebAPI.staticwebassets.runtime.json`, which carry the path (W8, W9), and
   the hash list that includes them.
10. `locales`: red in the same assemblies as layer 2; with the fix green.
11. The other axes as for layer 2. `all` red; `all` with the fix red only
    from the two json files.

## Commands

Verbatim in `kommando.txt`.

## Result

### Found while running: MSBuild's worker nodes outlive the shutdown

With two CPUs, MSBuild starts worker nodes (`MSBuild.dll /nodemode:1
/nodeReuse:true`). `dotnet build-server shutdown` stops the compiler server but
not these nodes. A node started at 15:00:51 in L2-build_path's control build
was still alive at 15:07, in the next run `[V]` `ps`. Every build started
nodes of its own. In L2-build_path the leftover node used 0.01 s of CPU in the
experiment's window, against 5.3 s for the experiment's own node `[V]`
samples. So it was alive but did no work.

Why the later builds do not connect to it is not established: the node listens
on `/tmp/MSBuild<pid>`, and the node and the later builds share one session.
The sampler follows every `~/.dotnet/dotnet` process, leftover nodes from
earlier runs included. So every run below is checked for any process started
before its experiment window that does work in it. From the `user_group` runs
on, node reuse is switched off (`MSBUILDDISABLENODEREUSE=1`), so nothing can
outlive a build.

### The runs, stopped after six

Stopped at 15:28 at Leo's request, after the sixth run, before the next one
started. The loop was stopped, not a run. The remaining 24 runs are the
continuation.

| Run | Time | reprotest | Control | Experiment |
| --- | --- | --- | --- | --- |
| L2-none | 14:55-15:00 | successful | `9283b29e…` | `9283b29e…` |
| L2-build_path | 15:00-15:05 | successful | `9283b29e…` | `9283b29e…` |
| L2-time | 15:05-15:10 | successful | `9283b29e…` | `9283b29e…` |
| L2-locales | 15:11-15:17 | **differences** | `9283b29e…` | `67d6d044…` |
| L2-umask | 15:17-15:22 | successful | `9283b29e…` | `9283b29e…` |
| L2-exec_path | 15:22-15:28 | successful | `9283b29e…` | `9283b29e…` |

`[V]` `summary.tsv`, stores. `9283b29e…` is run 7 of 23/9.

- In all six, every dotnet process of the experiment build carried the
  variation, and no process started earlier did work in the experiment's
  window `[V]` samples. Under `time`, libfaketime was mapped in all nine.
- L2-locales' experiment is byte-identical to this morning's run 2: the
  Estonian build is deterministic, it just differs from the others.
- L2-umask changes the modes of the same 142 files as this morning's run 3.
- With the shutdown at the end of each build, the `time` run took 5 minutes;
  this morning reprotest waited 10 minutes for the compiler server.
- Two leftover worker nodes were stopped by hand after the last run. One had
  lived from 15:00 to 15:28, so a node outlives more than one run.

Per expectation: 1 and 2 held, 3 held for `locales` without the fix, 7 held
for the six runs. The rest is not run yet.


## Interpretation

## Caveats and not tested
