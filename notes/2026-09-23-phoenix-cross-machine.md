# Phoenix layer 1 across machines: arch and ubuntu-vm

Run 23 September 2026 on `arch` and `ubuntu-vm`. Continues
[phoenix-layer1](2026-09-15-phoenix-layer1.md) and
[phoenix-reprotest](2026-09-15-phoenix-reprotest.md), which closed layer 1 on
one machine.
Data: `data/2026-09-23-phoenix-cross-machine/`, with `arch-solution/` and
`arch/` for the two `arch` protocols, and `ubuntu-vm-aborted/` and
`ubuntu-vm-aborted-light/` for the two VM attempts.

Phoenix is Weel-Sandvig's code and this repo is public. The data directories
hold environment blocks, commands and manifest hashes. Full hash lists, build
logs and probe output stay locally with Leo.

## Question

Do two machines produce the same bytes from the same Phoenix source? Same
commit, same Microsoft SDK 9.0.120 with the same `csc.dll`, same lab path, two
clean `dotnet build -c Release` runs on each machine.

reprotest varied the build environment on one machine. A second machine varies
what reprotest could not vary on `arch`:

- Who builds. `root` on the VM, `leos` on `arch`, so the NuGet cache sits in a
  different home directory.
- The package cache. Empty on the VM, so every package is downloaded again,
  eight days after the `arch` cache was last filled.
- The filesystem. Both are ext4, but each filesystem lists large directories
  in its own hash order. ApplicationCore has 1569 `.cs` files.
- Distribution, kernel, glibc, ICU.

## Setup

- Source: worktree `WS.Phoenix-repro`, branch `thesis/reproducible-builds`,
  HEAD `e6e92423`. The `arch` lab was re-synced and checked against the branch
  on 23/9, see the 23/9 caveat in
  [phoenix-reprotest](2026-09-15-phoenix-reprotest.md).
- Lab: `/private/tmp/rb1-phoenix` on both machines. The VM lab is an rsync of
  the `arch` lab without `.git`, `bin`, `obj`, `node_modules`, `.claude`,
  `.next`, `out`. A source-tree hash on both machines checks that the input is
  the same.
- SDK: Microsoft's 9.0.120, `~/.dotnet` on `arch`, `/root/.dotnet` on the VM.
  Runtime 9.0.19 on both. `csc.dll` hash in the environment blocks.
- NuGet cache: warm on `arch` (`~/.nuget/packages`), empty on the VM
  (`/root/.nuget/packages` did not exist before the run).
- Machines: `arch` 16 cores; `ubuntu-vm` 1 vCPU, 961 MB RAM, 2 GB swap.
- One run = clean + restore + build of `WS.Phoenix.sln`, twice per machine, as
  on 15/9. The clean step now also removes `tests/bin`, `tests/obj` and the
  top-level `bin` and `obj` (see Caveats).
- Frontend skipped with `-p:SkipSpaBuild=true`, as on 15/9.
- Two probes after the builds, on both machines:
  1. the raw directory order (`ls -U`) of the largest source directories;
  2. the order of the `Compile` items MSBuild evaluates for ApplicationCore
     (`dotnet msbuild -getItem:Compile`), compared with the directory order
     and with sorted order.

## Expectation, written before the run

1. Each machine agrees with itself: 0 differing files between build 1 and
   build 2, as on `arch` 15/9.
2. `arch` against `ubuntu-vm`:
   - The four own assemblies and their PDBs are **identical**. The compiler
     is the same binary and `PathMap` covers the source root. Weakly held:
     this assumes MSBuild hands csc the source files in an order that does
     not depend on the filesystem, which I have not verified. If MSBuild
     passes them in directory order, `ApplicationCore.dll`,
     `Infrastructure.dll` and `WebAPI.dll` differ, with reordered metadata.
     The difference would then also reach every assembly that references
     them, because a PDB records the MVID of each reference and the DLL
     carries the PDB's checksum.
   - Copied package files are identical: the same bytes from nuget.org.
   - `*.deps.json` and `*.runtimeconfig.json` are identical. No paths, same
     graph.
   - `spa.proxy.json` is identical, because the lab path is the same.
   - `WebAPI.staticwebassets.runtime.json` **differs**. It contains the NuGet
     cache path, `/home/leos/.nuget/packages/` against
     `/root/.nuget/packages/`.
   - The test assemblies follow the own assemblies.
3. The cold restore on the VM resolves the same graph as `arch`: the same
   packages, versions and `sha512` values in `project.assets.json`.
4. Probes: the directory order of the large directories differs between the
   machines. Whether the `Compile` order follows it decides point 2.

## Protocol change, written before the lighter runs

Added 23/9 at 12:00, before any VM build had finished.

- The first VM attempt used the solution protocol above and did not fit in
  1 GB of RAM. After 45 minutes of build 1, only ApplicationCore had compiled.
  79% of CPU time went to waiting on swap, with 2 GB of swap in use. A second,
  temporary 2 GB swapfile was added at 11:25. The attempt was stopped at 11:58.
  Its environment block and timing are in `data/.../ubuntu-vm-aborted/`.
- Its restore was genuinely cold. `/root/.nuget/packages` did not exist, and
  the restore fetched 483 package ids from nuget.org in 2 min 11 s. The five
  `project.assets.json` it produced are kept.
- From here, both machines build **the two programs instead of the solution**:
  `WebAPI.csproj`, then `BackgroundJobExecutor.csproj`. That is how the 15/9
  reprotest runs built, and how the release workflow publishes. The test
  project is not built. 639 of the 1610 files remain in the comparison: the
  four own assemblies and everything copied next to the two programs.
- Both builds pass `-p:UseSharedCompilation=false`, so each project's
  compiler runs as its own process and exits, instead of one compiler server
  holding every compilation in memory.
- The VM rerun uses the NuGet cache filled by the aborted attempt's cold
  restore. A second cold restore would not fit on the VM's disk next to it:
  4.5 GB of packages and 1 GB of HTTP cache, with 5 GB free. Point 3 is
  therefore checked against the aborted attempt's cold restore.
- `arch` is rerun with the lighter protocol. The morning's solution run is
  kept as `data/.../arch-solution/`.

Expectation for the change: on `arch`, all 639 files under
`src/*/bin/Release` from the lighter build are identical to the same files
from the solution build. Neither the entry point (solution against project)
nor the compiler server reaches the bytes.

## Commands

Verbatim in `kommando.txt` in each data directory.

## Result

### arch

| Run | Files | Build 1 vs 2 | Manifest |
| --- | --- | --- | --- |
| solution build, 11:16 (`arch-solution/`) | 1610 | 0 differing | `87949700…` |
| lighter build, 12:01 (`arch/`) | 639 | 0 differing | `55c9ae48…` |

The lighter build's 639 files are identical to the `src/` part of the solution
build: neither the entry point nor the compiler server reaches the bytes
`[V]` `manifest-hash.txt`. The expectation for the protocol change held.

Probes, on `arch`:

- Directory order. In the two directories checked, `Data/Migrations` and
  `ReportingAPI/Interfaces`, `ls -U` does not list the files in sorted order
  `[V]` `probe-readdir.txt` (local).
- MSBuild's order. The `Compile` items of ApplicationCore (1567) and
  Infrastructure (674) are in `StringComparer.OrdinalIgnoreCase` order over the
  whole relative path, not in directory order `[V]` `probe-compile-*.json`
  (local). One directory settles which comparison it is: MSBuild puts
  `CelsiusCh4ModelSupport.cs` before `Celsius_AuxEngine_Ge1Ch4Model.cs`, which
  only an upper-case ordinal comparison does. A culture-aware sort would put the
  underscore first.
- The mechanism. MSBuild 17.12 sorts every wildcard result before returning it:
  `Array.Sort(fileList, StringComparer.OrdinalIgnoreCase)`, with a comment that
  the build should "behave in exactly the same way every time, and on every
  machine" `[V]` `src/Build/Utilities/EngineFileUtilities.cs` lines 337-341,
  branch `vs17.12` of dotnet/msbuild.

### ubuntu-vm

Neither attempt finished a build.

1. Solution build, 11:13-11:58 (`ubuntu-vm-aborted/`). After 45 minutes of
   build 1 only ApplicationCore had compiled. CPU time was 79% I/O wait, with
   2 GB of swap in use. A second 2 GB swapfile was added at 11:25. Stopped.
2. Lighter build, 12:00-15:20 (`ubuntu-vm-aborted-light/`). ApplicationCore
   compiled by 12:03. The compiler then ran for 3 h 13 min on Infrastructure
   with 33 minutes of CPU time, 4 GB of swap full and 29 MB of RAM left, and
   the build log did not move after 12:03. Stopped.

The first attempt's restore was genuinely cold: `/root/.nuget/packages` did not
exist, and restore fetched 483 package ids from nuget.org in 2 min 11 s. Its
`project.assets.json` files match `arch`'s for all four `src` projects: the
same packages, versions and `sha512`, 95, 213, 336 and 221 packages `[V]`.

## Interpretation

**Expectation 2, the cross-machine comparison, is not measured.** The
droplet, 1 vCPU and 961 MB, cannot compile Phoenix. Infrastructure alone
filled 4 GB of swap, most likely because of its 298 EF migration files `[I]`.
Verification has a hardware cost: rebuilding Phoenix takes a machine with
several GB of RAM.

**Point 4 is settled on `arch`, and it changes point 2's footing.** The order in
which the filesystem lists files does not reach the compiler, because MSBuild
sorts wildcard results with an ordinal, culture-independent comparison. The
locale difference between the machines (`da_DK.UTF-8` against `C.UTF-8`) does
not reach the order either. That leaves the file-order risk for anything that
enumerates directories outside MSBuild's wildcards, which the file-order run
would test.

**Expectation 3 held.** A clean machine eight days later resolved the same
graph. That is an observation about one day, not a guarantee; see the lock
files in [phoenix-layer2](2026-09-23-phoenix-layer2.md).

## Caveats and not tested

- **The VM runs are paused**, decided by Leo on 23/9. The cross-machine
  comparison and the file-order run wait for a machine with enough memory,
  such as the Azure VM Peter is setting up. The droplet keeps the aborted runs'
  data and a temporary 2 GB swapfile.
- The 15/9 clean step (`tests/*/bin tests/*/obj`) missed the test project,
  which sits directly in `tests/`. The test project still recompiled in 15/9's
  build 2, with 4660 compiler warnings in both logs, so W1 holds `[V]`.
  Today's clean step removes `tests/bin` and `tests/obj`.
- The `arch` lab held five Rider `.idea` files that are not in the commit. The
  build never reads them `[I]`.
- The branch has moved on since these runs, see phoenix-layer2. These results
  are for `e6e92423`.
