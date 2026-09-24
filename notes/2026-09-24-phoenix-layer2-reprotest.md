# Phoenix layer 2, environment axes: reprotest

Run 24 September 2026 on `arch`. Continues
[phoenix-layer2](2026-09-23-phoenix-layer2.md), where the release's publish
step was green on one path and across paths. The same four axes on layer 1:
[phoenix-reprotest](2026-09-15-phoenix-reprotest.md), runs 5-8.
Data: `data/2026-09-24-phoenix-layer2-reprotest/arch/`.

Phoenix is Weel-Sandvig's code and this repo is public. reprotest logs, hash
lists, mode lists and process samples stay locally with Leo.

## Question

Does the release's publish step give the same bytes under a different clock,
locale, umask and `PATH`? One axis per run, as on layer 1.

A second question came up while preparing: does reprotest's variation reach
the processes that write the bytes? .NET keeps build servers alive between
builds, and reprotest runs its two builds back to back.

## Setup

- Lab `/private/tmp/rb1-phoenix`: the export of `2570034b` from 23/9, checked
  again on 24/9 at 10:29 with `experiments/labcheck.py`: 5478 files, 0 missing,
  0 differing, 0 extra. No `bin`, `obj` or `release`.
- SDK: Microsoft's 9.0.120 in `~/.dotnet`, `csc.dll` `644a4d33…`. reprotest
  0.7.32, diffoscope 329, faketime 0.9.13. Environment block in
  `environment.txt`.
- Build command: the one from reprotest `+build_path` on 23/9, the release
  job's sequence. Locked restore with the version properties, the two
  publishes with `--no-restore`, a hash list of `release/`. The artefacts are
  the same too: `release.sha256` and the own assemblies, launchers and json
  files in both publish folders.
- Each build also writes a mode list of `release/` into Leo's data folder,
  named by the build's umask and shell PID. It lies outside the artefacts, so
  the verdict is unchanged.
- `-v`, so the log names the variation reprotest applied.
- `experiments/sample-dotnet.py` samples every `~/.dotnet/dotnet` process
  once a second. It records the role (main command, MSBuild worker node,
  compiler server), start time, umask, CPU time, and the markers of the
  variations: libfaketime loaded, `LANG`, `LC_ALL`, `TZ`, and whether `PATH`
  ends in `/i_capture_the_path`. Rider's own MSBuild processes are left out.

What reprotest does, read from its source (0.7.32):

- It applies every axis to every build, varied or fixed. Fixed means `HOME` is
  the build directory, `LANG=C.UTF-8` with `LANGUAGE=en_US:en`, `TZ=GMT+12`,
  and umask 0022 `[V]` `build.py` 288-291, 382-384, 407-418, 451-453;
  `__init__.py` 175-182. Every reprotest build so far, 15/9 and 23/9, ran with
  these values, not with Leo's `da_DK.UTF-8` and Europe/Copenhagen.
- The variations `[V]` `build.py`:
  - `+time` puts `faketime +398days+<h>hours+<m>minutes` in front of the
    command, with `NO_FAKE_STAT=1`, so file timestamps are not faked (421-449).
    It is only applied when the newest source file is less than 398 days old.
    Here that is the commit time, 23/9 17:24.
  - `+locales` sets `LANG` and `LC_ALL` to `et_EE.UTF-8` (382-392). Estonian
    sorts z between s and t.
  - `+umask` sets 0002 (451-457).
  - `+exec_path` appends `:/i_capture_the_path` to `PATH` (394-399).
- diffoscope runs with `--exclude-directory-metadata=yes` by default
  `[V]` `__init__.py` 615-619. The verdict compares contents, not modes.
- The NuGet cache is `/tmp/dch/.nuget/packages`, not `~/.nuget/packages`. The
  command sets `DOTNET_CLI_HOME=/tmp/dch` because reprotest points `HOME` into
  the build directory, and `DOTNET_CLI_HOME` moves NuGet's global packages
  folder with it `[V]` `dotnet nuget locals global-packages --list`.

### Protocol change: build servers, written before run 0

.NET keeps two kinds of process alive after a build: the compiler server
`VBCSCompiler`, and MSBuild's worker nodes (node reuse). reprotest builds
the control first and the experiment right after, as the same user with the
same SDK. The experiment then connects to the servers the control started
`[I]`. Those servers keep the control's process state: no libfaketime, umask
0022, the control's `PATH`. The variation reaches only the processes the
experiment starts itself. If this holds, it also applies to 15/9's runs 5-8.

- Run 0 measures this with the 23/9 protocol unchanged, on `+umask`.
- Runs 1-4 start every build with `dotnet build-server shutdown`. Each build
  then begins without servers, as on a fresh CI runner, and every process it
  uses starts inside its variation. The release's own commands are unchanged.

## Expectation, written before the runs

Run 0, `+umask`, no shutdown:

1. Reproduction successful. Both builds' `release.sha256` are identical to run
   7 on 23/9 (1237 files, manifest `9283b29e…`).
2. The experiment starts no compiler server of its own. The one that compiles
   it was started by the control build and runs with umask 0022, and so do the
   worker nodes. Only the experiment's main processes run with 0002.
3. Modes: the own DLLs, PDBs and `WebAPI.xml` are 0644 in both builds, because
   the control's compiler server writes them. `release.sha256` is 0664 in the
   experiment; its shell writes it.

Runs 1-4, with shutdown:

4. Every dotnet process in an experiment build carries its variation, and none
   survives from the control build.
5. All four green. Every build's `release.sha256` is identical to run 7 on 23/9.
   - `+time`: nothing in the release reads the clock. The 311 `Last-Modified`
     headers in `WebAPI.staticwebassets.endpoints.json` stay at "Tue, 29 Oct
     2024 13:06:48 GMT". They are the file times of the Identity UI package in
     the NuGet cache, which faketime does not change `[I]`.
   - `+locales`: nothing sorts or formats with the current culture. Weakly
     held for `deps.json` and the endpoints manifest, whose writers I have not
     read.
   - `+umask`: contents identical, modes not. The files the build creates
     itself are 0664 in the experiment and 0644 in the control: our DLLs, PDBs
     and `WebAPI.xml`, the `deps.json`, `runtimeconfig.json` and endpoints
     files, and `release.sha256`. Files copied from the runtime packs and
     packages keep their mode from the cache. The launchers stay 0755.
   - `+exec_path`: the command puts `~/.dotnet` first on `PATH`, so a
     directory added at the end changes nothing.
6. libfaketime in every .NET process, the compiler server included, does not
   hang the build. Weakly held.

### Runs 5-6: two fixes for W26, expectation written before the run

Added 24/9 at 13:55, after run 2 and after the minimal reproduction in
[roslyn-locale-repro](2026-09-24-roslyn-locale-repro.md). Both fixes are an
environment variable on every dotnet command of the build. That is where the
release job would set them, so the lab stays `2570034b` (checked again, 0
differing). `+locales` with the shutdown, as run 2.

- Run 5: `LC_ALL=C.UTF-8` on every dotnet command.
- Run 6: `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` on every dotnet command.

7. Run 5 green: the command's own `LC_ALL` overrides reprotest's Estonian one,
   and `LC_ALL` comes first when .NET picks its culture. Both builds'
   `release.sha256` identical to run 7 on 23/9.
8. Run 6 green: invariant globalization ignores the locale, as in the
   reproduction.
9. Run 6's release is identical to run 7 too, weakly held. Phoenix sorts many
   more generated names than the reproduction, and ordinal order can differ
   from the invariant culture's for some of them.

## Commands

Verbatim in `kommando.txt`, verdicts and log hashes in `logs.md`, manifests in
`manifest-hash.txt`. The analysis scripts are in `experiments/`:
`analyze-samples.py` for the process samples, `modes-compare.py` for the mode
lists, `pe-diff-regions.py` and `md-strings.py` for the DLL differences, and
`collate.fsx` for the culture check. The DLL metadata was dumped with
`ildasm -METADATA=RAW -NOIL`; the dumps stay locally with Leo.

## Result

### Found while running: reprotest builds on one CPU

reprotest's log opens with "The control build runs on 1 CPU by default, give
`--min-cpus` to increase this". With `num_cpus` fixed, both builds run under
`taskset` on one CPU, `--min-cpus` defaulting to 1 `[V]` `build.py` 341-368,
`__init__.py` 807-809. Every reprotest build since 15/9 was a one-CPU build.
MSBuild then builds everything in its main process: no worker node ran in any
of today's runs `[V]` samples. The lab runs on 23/9 had all 16 cores, and
reprotest's one-CPU builds matched them byte for byte `[V]` 23/9 cross-run
check. The number of CPUs does not reach the release either.

### Run 0: `+umask`, protocol of 23/9

10:32-10:39, "Reproduction successful". Both builds' `release.sha256` are
identical to run 7 on 23/9: 1237 files, manifest `9283b29e…` `[V]`.

The processes, from the samples `[V]` `samples-0-umask.txt` (local),
`experiments/analyze-samples.py`:

| Process | Started | umask | CPU in control build | CPU in experiment build |
| --- | --- | --- | --- | --- |
| compiler server | 10:32:07, control build | 0022 | 286 s | 125 s |
| static web assets tool, child of the control's WebAPI publish | 10:36:57 | 0022 | 12 s | 0 |
| the same, child of the experiment's WebAPI publish | 10:39:31 | 0002 | 0 | 11 s |

The tool's command line was not recorded in run 0. It is named from runs 1-4,
where the sampler recorded it: same parent, same point in the build, same CPU
time `[I]`.

One compiler server ran for the whole run. The experiment started none of its
own, and the control's server did its compiling.

Modes `[V]` mode lists (local). 1237 files in each build, 129 differ, all
0644 against 0664:

- the five json files: both `deps.json`, both `runtimeconfig.json` and
  `WebAPI.staticwebassets.endpoints.json`;
- 124 compressed Identity UI assets, `wwwroot/Identity/**/*.br` and `*.gz`.

Unchanged: our 13 compiler outputs (DLLs, PDBs, `WebAPI.xml`) and the two
`appsettings.json` at 0644, 1091 files at 0744, and the two launchers at 0755.
0744 is the mode of every DLL in both NuGet caches on `arch`, 4656 in
`/tmp/dch` and 9043 in `~/.nuget/packages` `[V]` `find -printf %m`.

Per expectation:

1. Held.
2. Held for the compiler server. There were no worker nodes to reuse, because
   of the single CPU; not predicted.
3. Held for our DLLs, PDBs and `WebAPI.xml`: 0644 in the experiment too. The
   mode of `release.sha256` was not recorded; for an identical experiment the
   store keeps only a link to the control. Not predicted: the 124 compressed
   assets, which the build generates.

### Run 1: `+time`, with shutdown

10:49-11:12, "Reproduction successful". Both builds' `release.sha256` are
identical to run 7 on 23/9 `[V]`. The experiment ran under `faketime
+398days+22hours+56minutes`, `FAKETIME=+34469760` in the processes'
environment `[V]` log, samples.

Every dotnet process of the experiment build had libfaketime loaded: the
build-server shutdown, the restore, both publishes, the compiler server that
did the compiling, and a static web assets tool the WebAPI publish starts
(`Sdks/Microsoft.NET.Sdk.StaticWebAssets/tools/net9.0/`). The control's
compiler server was last seen at 10:54:28, when the experiment's shutdown ran,
and did no work in the experiment `[V]` samples.

The shifted clock made the build slower, and reprotest waited:

| | control | experiment |
| --- | --- | --- |
| whole build | 10:49:42-10:54:25, 4 min 43 s | 10:54:28-11:02:12, 7 min 44 s |
| WebAPI publish | 4 min 35 s | 7 min 22 s |
| compiler server CPU | 256 s | 404 s |

After its last publish at 11:02:12, the experiment's compiler server stayed
alive, idle. reprotest carried on only at 11:12:08, when the server exited on
its own, and the run ended at 11:12:11 `[V]` samples, `.time` file. After the
control builds, reprotest carried on within seconds while the control's server
was still alive. Why the experiment waits under faketime is not established.

### Run 2: `+locales`, with shutdown

11:12-11:22, reprotest exit 1: **the two builds differ**. The experiment ran
with `LANG` and `LC_ALL` set to `et_EE.UTF-8` `[V]` log. Every dotnet process
of the experiment had `LC_ALL=et_EE.UTF-8`, the compiler server that did the
compiling included `[V]` samples.

The control's `release.sha256` is identical to run 7. The experiment's,
manifest `67d6d044…`, differs in 10 of 1237 files, all of them our own
assemblies `[V]`:

| File | Folder | Differing bytes, same size |
| --- | --- | --- |
| `ApplicationCore.dll` | both | 320 |
| `Infrastructure.dll`, `Infrastructure.pdb` | both | 497, 40 |
| `WebAPI.dll`, `WebAPI.pdb` | WebAPI | 356, 59 |
| `BackgroundJobExecutor.dll`, `BackgroundJobExecutor.pdb` | job worker | 72, 59 |

`ApplicationCore.pdb` is identical, and so is everything else: the json files,
`WebAPI.xml`, the runtime and every package file.

What differs, from `ildasm -METADATA=RAW` of both builds `[V]` (dumps local):

- In `ApplicationCore.dll`, 281 of the 320 bytes are in the metadata tables.
  The rest are the MVID, a few blob bytes and the PE timestamp. The tables hold
  the same rows in a different order. Two type definitions have swapped
  places: `<>y__InlineArray4`1` and `<>z__ReadOnlySingleElementList`1`, types
  the compiler generates for C# 12 collection expressions. Their fields,
  interface rows, and the type and member references they bring in move with
  them.
- `Infrastructure.dll` swaps `<>y__InlineArray2`1` and `<>y__InlineArray5`1`
  against `<>z__ReadOnlyArray`1` and `<>z__ReadOnlySingleElementList`1`.
  `WebAPI.dll` swaps `<>y__InlineArray5`1` against `<>z__ReadOnlyArray`1`.
- In the control, every `<>y__` type comes before every `<>z__` type. In the
  Estonian build, it is the other way round.
- `BackgroundJobExecutor.dll` has no such types. Its 72 bytes are the five
  identity fields. The PDBs of the assemblies that reference a changed assembly
  differ in 40-59 bytes. Both fit the reference MVIDs a PDB records `[I]`.

The cause is in the compiler `[V]`:

- Roslyn 4.12, `4.12.0-3.25609.5+fc52718e`, the compiler in SDK 9.0.120,
  collects these types in `PrivateImplementationDetails`. `Freeze()` orders
  them with `_synthesizedTopLevelTypes.OrderBy(kvp => kvp.Key)`:
  `src/Compilers/Core/Portable/CodeGen/PrivateImplementationDetails.cs` line
  176 at commit `fc52718e`, and the same in the decompiled
  `Microsoft.CodeAnalysis.dll` of the SDK. `OrderBy` on a string key without a
  comparer compares with the current culture.
- .NET's collation puts `<>z__` before `<>y__` under `et-EE` only.
  Invariant, `da-DK`, `en-US`, `sv-SE`, `fi-FI`, `lv-LV`, `lt-LT`, `hu-HU`,
  `cs-CZ` and `tr-TR` put `<>y__` first, as does ordinal comparison `[V]`
  `CompareInfo.Compare`, .NET 10 on `arch`'s ICU.
- Roslyn's `main` sorts these types with `StringComparer.Ordinal`, in
  `GetAdditionalTopLevelTypes` of the C# `PEModuleBuilder` `[V]` source on
  `main`, read 24/9. Every SDK on `arch` still orders by culture: 9.0.120,
  and the Arch packages 9.0.121 and 10.0.112 `[V]` decompiled `Freeze()`.
- The same class orders its generated methods with `OrderBy(kvp => kvp.Key)`
  and its generated fields with `Name.CompareTo`, both by culture, at
  `fc52718e` and still on `main` `[V]` source. Nothing there differed in run
  2. Other names under other cultures could `[I]`.

The C# code is the same as on 15/9: no `.cs`, `.cshtml` or `.razor` file
changed between `e6e92423` and `2570034b` `[V]` `git diff --stat`.

### Run 3: `+umask`, with shutdown

11:22-11:32, "Reproduction successful". Both builds are identical to run 7
`[V]`. The experiment's compiler server ran with umask 0002 and did all its
compiling. The control's did none in the experiment `[V]` samples.

Modes `[V]` mode lists: 142 files differ, all 0644 against 0664. They are the
13 compiler outputs, the five json files and the 124 compressed assets.
Unchanged: the two `appsettings.json` at 0644, the 1091 files at 0744, the
launchers at 0755. Against run 0, the difference is the 13 compiler outputs.
In run 0 the control's compiler server wrote them, and they stayed 0644. Here
they are 0664.

### Run 4: `+exec_path`, with shutdown

11:32-11:42, "Reproduction successful". Both builds are identical to run 7
`[V]`. Every dotnet process of the experiment had `PATH` ending in
`/i_capture_the_path`, the compiler server included `[V]` samples. Modes are
identical.

### Runs 5-6: two fixes for W26

| Run | Fix on every dotnet command | Time | reprotest | Both builds against run 7 |
| --- | --- | --- | --- | --- |
| 5 | `LC_ALL=C.UTF-8` | 13:54-14:03 | successful | identical |
| 6 | `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` | 14:03-14:15 | successful | identical |

`[V]` logs, `release.sha256` against `publish7.sha256`. In run 5's experiment
every dotnet process had reprotest's `LANG=et_EE.UTF-8` and the command's
`LC_ALL=C.UTF-8` `[V]` samples. The release came out as run 7, so `LC_ALL`
wins over `LANG`. Run 6 changed no byte of the release either, in the control
or under Estonian.

Per expectation: 7, 8 and 9 held.

### All runs

| Run | Axis | Shutdown | reprotest | Control against run 7 | Experiment |
| --- | --- | --- | --- | --- | --- |
| 0 | `+umask` | no | successful | identical | = control |
| 1 | `+time` | yes | successful | identical | = control |
| 2 | `+locales` | yes | **differences** | identical | 10 files differ, `67d6d044…` |
| 3 | `+umask` | yes | successful | identical | = control |
| 4 | `+exec_path` | yes | successful | identical | = control |
| 5 | `+locales`, `LC_ALL=C.UTF-8` | yes | successful | identical | = control |
| 6 | `+locales`, invariant globalization | yes | successful | identical | identical to run 7 |

### Per expectation, runs 1-4

4. Held in all four. Every dotnet process of each experiment carried its
   variation, and the control's compiler server did no work in the experiment.
5. Held for `+time`, `+umask` and `+exec_path`. **Wrong for `+locales`**:
   under Estonian the compiler reorders the types it generates, in three of
   our four assemblies, and the fourth changes through its references.
   - `+time`: the endpoints manifest is among the artefacts and is identical,
     so the 311 `Last-Modified` headers did not move.
   - `+umask`: as predicted, plus the 124 compressed assets. The mode of
     `release.sha256` was not recorded.
6. Held: no hang. But the compiler took about 60% longer under libfaketime,
   and reprotest waited 10 minutes for the experiment's compiler server to exit
   (run 1).

## Interpretation

**The release depends on the build machine's locale.** The release's own
publish commands give different DLLs when the build runs under a culture that
sorts z before y. It takes one environment variable, read by the compiler when
it orders the types it generates for collection expressions. That is a
compiler defect, fixed on Roslyn's `main` and still in every SDK we have,
.NET 10 included. For Phoenix the exposure is narrow: of eleven cultures only
Estonian changes the order of these names. The invariant culture, which
GitHub's runners use `[I]`, and Danish agree. But nothing in the build pins the locale, so
agreement is luck, not design. Pinning the build culture fixes it without
changing a byte: `LC_ALL=C.UTF-8` or invariant globalization on the dotnet
commands both give run 7's release under Estonian (runs 5-6). A compiler that
sorts ordinally is not tested.

**A reprotest verdict is only as good as the processes the variation reaches.**
With .NET's build servers alive, the experiment's compiling is done by the
compiler server the control build started (run 0). The variation reaches
MSBuild's main process and the tools it starts, but not the compiler. The same
code with the same compiler was green for `+locales` on 15/9 and is red today,
so the 15/9 run cannot have varied the compiler `[I]`. `+time`, `+umask` and
`+exec_path` are green today with the compiler inside the variation, so their
verdicts hold for the code. On 15/9 they were not measured for the compiler.
`dotnet build-server shutdown` at the start of each build closes the gap,
without touching the release's commands.

**reprotest fixes more than it varies.** Every reprotest build so far ran on
one CPU, with `TZ=GMT+12`, `LANG=C.UTF-8`, and a NuGet cache of its own. The
lab builds of 23/9 had 16 cores, Europe/Copenhagen and `da_DK.UTF-8`, and
matched reprotest's builds byte for byte. So CPU count, time zone, and Danish
against invariant culture do not reach the release, on this code and SDK.

**File modes follow whoever writes the file.** A file's mode in the release
folder depends on the umask of the process that created it: 0644 or 0664 for
what the build writes, 0744 for anything NuGet extracted, 0755 for the
launchers. With reused build servers, one build even mixes two umasks (run 0).
reprotest compares contents only. The release job zips the folders with
`zip -r`, which stores Unix modes, so this reaches layer 4 `[I]`.

## Caveats and not tested

- `arch` only. File order needs `disorderfs`, which `arch` does not have.
- One varied locale, Estonian. Other cultures could reorder other names, for
  example the generated methods and fields that the same class sorts by
  culture. Not tested.
- The fixes are measured in reprotest, not in the release job: the workflow
  does not set either variable yet. On Windows, `LC_ALL` has no effect, and
  invariant globalization is not measured there. A compiler with the ordinal
  sort is not tested.
- 15/9's runs 5-8 were not rerun on layer 1 with the shutdown. Their
  reading here rests on run 0's mechanism and the unchanged code `[I]`.
- For an identical experiment, reprotest's store keeps only a link to the
  control, so the experiment's `release.sha256` mode was never recorded.
- Why reprotest waits for the compiler server under faketime is not
  established.
- `ildasm` 10.0.12 and `ilspycmd` 11.0 were used to read the DLLs and the
  compiler. The collation check ran on .NET 10 with `arch`'s ICU. The build's
  compiler ran on .NET 9.0.19, which loads the same system ICU `[I]`.
