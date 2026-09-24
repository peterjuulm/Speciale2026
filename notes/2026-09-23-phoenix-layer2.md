# Phoenix layer 2: `dotnet publish` with the release's own commands

Run 23 September 2026 on `arch`. The first measurement of layer 2 in the
[layer plan](2026-09-15-layer-plan.md). Layer 1 on the same tree and day:
[phoenix-cross-machine](2026-09-23-phoenix-cross-machine.md).
Data: `data/2026-09-23-phoenix-layer2/arch/`.

Phoenix is Weel-Sandvig's code and this repo is public. Hash lists, publish
logs and diffoscope output stay locally with Leo.

## Question

Is the release's publish step deterministic? Two clean runs of the release
workflow's own Linux publish commands for the two programs, first on the same
path, then on two paths with reprotest `+build_path`. Along the way: what does
publish add to layer 1's output, and do the two json files that carry the
build path ship?

## Setup

- Lab `/private/tmp/rb1-phoenix` on `arch`, branch
  `thesis/reproducible-builds` HEAD `e6e92423`, the same lab as
  phoenix-cross-machine.
- SDK: Microsoft's 9.0.120 in `~/.dotnet`, `csc.dll` `644a4d33…`, pinned by
  `global.json`. The real release job installs "9.0.x" instead; see Caveats.
- The two commands from job `publish-linux` in `.github/workflows/03-release.yml`,
  verbatim except that `REF_NAME` is fixed to `v0.0.0-thesis`:

      dotnet publish ./src/WebAPI/WebAPI.csproj -c Release -o ./release/ws-pems-linux-x64 -r linux-x64 --self-contained true /p:SkipSpaBuild=true /p:Version="${REF_NAME#v}" /p:InformationalVersion="${REF_NAME}"
      dotnet publish ./src/BackgroundJobExecutor/BackgroundJobExecutor.csproj -c Release -o ./release/ws-pems-job-worker-linux-x64 -r linux-x64 --self-contained true /p:Version="${REF_NAME#v}" /p:InformationalVersion="${REF_NAME}"

- No frontend. The release job downloads the static export into
  `src/WebAPI/ClientApp/out` before publishing. The lab has no `out/`, so the
  publish contains no SPA. That is layer 3.
- Self-contained: the runtime comes from the runtime packs, 9.0.19 for both
  `Microsoft.NETCore.App` and `Microsoft.AspNetCore.App`, the SDK's
  `LatestRuntimeFrameworkVersion` `[V]` `Microsoft.NETCoreSdk.BundledVersions.props`.
  The two packs were not in the `arch` NuGet cache, so the first publish
  downloads them from nuget.org.
- Run 1: one run = clean (`bin obj src/*/bin src/*/obj tests/bin tests/obj
  release`) + the two publish commands, twice. Publish restores implicitly, as
  in the workflow. Every file under `release/` is hashed.
- Run 2: reprotest `+build_path` around the same two commands. The artefacts
  are the hash list of `release/` plus the own assemblies in both publish
  directories.
- The own assemblies from run 1 are compared with today's layer 1 build of the
  same commit (phoenix-cross-machine, `arch`, lighter protocol).

## Expectation, written before the run

Run 1, same path twice:

1. **0 differing files.** Publish copies layer 1's deterministic output and
   packs that do not change between runs.
2. `spa.proxy.json` does not ship: the SpaProxy targets mark it
   `CopyToPublishDirectory="Never"` `[V]` targets file.
   `WebAPI.staticwebassets.runtime.json` does not ship either, because it is a
   development manifest `[I]`.
3. New relative to layer 1: the runtime, a few hundred files from the two
   runtime packs, and a native launcher (apphost) per program `[I]`.
4. `ApplicationCore.dll` and `Infrastructure.dll` in the publish output are
   **identical** to layer 1's. The SDK builds referenced libraries without the
   runtime identifier. `WebAPI.dll` and `BackgroundJobExecutor.dll` **differ**
   from layer 1's. They are compiled into `obj/Release/net9.0/linux-x64/`, and
   that path, mapped by PathMap, is the PDB path stored in the DLL's debug
   directory `[I]`. If this holds, a release DLL cannot be checked against a
   `dotnet build` DLL; only the same publish command reproduces it.

Run 2, `+build_path`:

5. **Green** for everything in both publish directories. The own assemblies
   follow PathMap, and neither json file that carries the path ships `[I]`. If
   so, the path channel that layer 1 left open (W8, W9) closes in layer 2
   because the files are not part of the release.

Expectations 1-5 were written before a dry run by Claude at 12:13-12:17
(run 1 plus a version probe; the reprotest run was stopped unfinished). Its
data stays locally with Leo as `arch-dryrun`. The runs below are Leo's.

### Runs 3-4 on `84d73a2f`, expectation written before the run

Added 23/9 after runs 1-2 on `e6e92423`, before run 3 (restore at 16:51). Two commits on
`thesis/reproducible-builds` in between: `b0a21823` removes an empty npm
`package-lock.json` from `src/WebAPI` that runs 1-2 showed shipping, and
`84d73a2f` adds NuGet lock files (`packages.lock.json` per project,
`RestorePackagesWithLockFile`, locked mode in GitHub Actions,
`RuntimeIdentifiers` linux-x64;win-x64). With `84d73a2f` the release job
restores the solution once and publishes with `--no-restore`, so runs 3-4 do
the same, with `--locked-mode` standing in for the `GITHUB_ACTIONS`
condition. From here the lab is an export of the commit (`git archive`),
not an rsync of the worktree; see Setup changes below.

6. Runs 3 and 4 are identical to each other.
7. `package-lock.json` is gone from the WebAPI publish folder.
8. `WebAPI`'s `packages.lock.json` ships in its place: the Web SDK copies
   every `.json` in the project folder into publish `[I]`.
9. `ApplicationCore.dll` and `Infrastructure.dll` change bytes. With
   `RuntimeIdentifiers` set, the SDK no longer treats the libraries as
   platform-neutral and builds them for linux-x64 too `[I]`.
10. Everything else, runtime and package files included, is identical to
    runs 1-2 `[I]`.

### Runs 5-6 on `d0a817c9`, expectation written before the run

Added 23/9 before run 5 (17:11). Run 3 on `84d73a2f` gave 1241 files: `package-lock.json`
gone, `packages.lock.json` not shipped, and four new files, the win-x64
`onnxruntime.dll` and `onnxruntime_providers_shared.dll` in both publish
folders. The libraries were built into `bin/Release/net9.0/linux-x64/`, and
14 files differed from run 1: our own DLLs and PDBs and both `deps.json`.
Run 4 on `84d73a2f` was not run; `d0a817c9` replaced it. It sets
`RuntimeIdentifiers` on the two programs only.

11. Runs 5 and 6 are identical to each other.
12. 1237 files: run 1's list without `package-lock.json`. The four win-x64
    onnxruntime files are gone.
13. The libraries are built into `bin/Release/net9.0/` again, and every file
    except `package-lock.json` is identical to run 1, our own DLLs, PDBs and
    `deps.json` included. The lock files record the graph but do not change
    it `[I]`.

### Runs 7-8 on `2570034b`, expectation written before the run

Added 23/9 before run 7 (17:25). Runs 5-6 on `d0a817c9` were identical to each other,
and every DLL and PDB matched run 1. The two `deps.json` did not: they listed
ApplicationCore and Infrastructure as `1.0.0` instead of `0.0.0-thesis`,
because the separate restore ran without the version properties.
`2570034b` gives the release job's restore step the same `/p:Version` and
`/p:InformationalVersion` as the publishes, and runs 7-8 do the same.

14. Runs 7 and 8 are identical to each other.
15. Against run 1, the only difference is the removed `package-lock.json`:
    all 1237 remaining files are byte-identical, both `deps.json` included.

### Reprotest `+build_path` on `2570034b`, expectation written before the run

Added 23/9 before the run (log finished 17:33). Expectation 5 carried over to the final tree. reprotest
copies the lab into two directories whose names differ in length and runs the
release job's sequence in each: locked restore, the two publishes with
`--no-restore`, a hash list of `release/`.

16. **Green.** Every file in both publish directories is identical across
    the two paths. PathMap covers our DLLs and PDBs, the two json files that
    carry the path do not ship, and nothing else in the release holds a path
    `[I]`.

## Commands

Verbatim in `kommando.txt`, fingerprints in `manifest-hash.txt`, the reprotest
log's size and hash in `logs.md`.

## Result

### Setup changes during the day

- The run numbering differs from Setup: runs 1 and 2 are the two clean
  publishes on `e6e92423`; reprotest came last, on `2570034b`.
- Before run 1, a warm-up publish at 13:37 started without a clean, after an
  attempt with an empty `REF_NAME` had stopped with MSB4044 ("GetAssemblyVersion
  was not given a value for NuGetVersion"). Its log is kept as
  `warmup-webapi.log`. A first attempt at run 2 was stopped with Ctrl+C; the lab
  was cleaned and run 2 started over.
- Runs 1-3 and reprotest were typed by Leo, runs 1-3 in fish. Runs 5-8 were run
  by Claude at Leo's request. In fish the version strings are plain text, which
  is what bash makes of `"${REF_NAME#v}"`.
- From run 3 the lab is an export of the commit, `git archive <commit> -- .
  ':(exclude).claude'`, checked file by file against the commit (0 missing,
  0 differing, 0 extra). Runs 1-2 used the rsync lab, which also held five
  Rider `.idea` files.
- From run 3 the sequence is the release job's new one: `dotnet restore
  ./WS.Phoenix.sln --locked-mode`, then both publishes with `--no-restore`.
  From run 7 the restore also gets the version properties.

### Runs

| Run | Lab | Files | Manifest | Against run 1 |
| --- | --- | --- | --- | --- |
| dry run (Claude, 12:13) | `e6e92423` | 1238 | `b2902b24…` | identical |
| 1 (15:34) | `e6e92423` | 1238 | `b2902b24…` | |
| 2 (16:19) | `e6e92423` | 1238 | `b2902b24…` | identical |
| 3 (16:51) | `84d73a2f` | 1241 | `694bc0a4…` | `package-lock.json` gone; 4 win-x64 files added; 14 of 1237 differ |
| 5 (17:11) | `d0a817c9` | 1237 | `8d1f33b7…` | `package-lock.json` gone; 2 of 1237 differ (`deps.json`) |
| 6 | `d0a817c9` | 1237 | `8d1f33b7…` | as run 5 |
| 7 (17:25) | `2570034b` | 1237 | `9283b29e…` | `package-lock.json` gone; 0 differ |
| 8 | `2570034b` | 1237 | `9283b29e…` | as run 7 |
| reprotest `+build_path` | `2570034b` | 1237 ×2 | `9283b29e…` | reproduction successful |

### Per expectation

1. Held. Runs 1 and 2 are identical, and so is the dry run four hours earlier,
   typed in bash instead of fish `[V]`.
2. Held. Neither `spa.proxy.json` nor `WebAPI.staticwebassets.runtime.json`
   is in the publish folder; both are still in `bin/` `[V]`. A third file ships,
   `WebAPI.staticwebassets.endpoints.json`: web routes for the Identity UI
   files, no absolute paths `[V]` grep. Not predicted:
   `src/WebAPI/package-lock.json` ships. It is an empty npm lock file, 85
   bytes, `"packages": {}`, with no `package.json` beside it, committed by
   accident in `a6208f0f`. The Web SDK copies `.json` files in the project
   folder into publish `[V]`.
3. Held. 323 of WebAPI's 746 files come from the two runtime packs 9.0.19 and
   are byte-identical to the pack's files: 184 from `Microsoft.NETCore.App`
   (169 DLLs, 14 native `.so`, `createdump`) and 139 DLLs from
   `Microsoft.AspNetCore.App` `[V]`. The native files and the two launchers are
   ELF x86-64 `[V]` `file`. 89 of the 169 base DLLs and all 139 ASP.NET Core DLLs
   are ReadyToRun images for Linux x64, PE Machine `0xfd1d` (x64 `0x8664`
   combined with Linux's `0x7b79`); the other 80 are IL only `[V]`.
4. Wrong for the libraries. All four own DLLs differ from layer 1's.
   - The libraries differ only in the version stamp. The release's
     `/p:Version` and `/p:InformationalVersion` reach every project in the build:
     `ApplicationCore.dll` carries FileVersion `0.0.0.0` and ProductVersion
     `v0.0.0-thesis` instead of `1.0.0.0` and `1.0.0`. Building ApplicationCore
     with the same two properties reproduces the published DLL exactly,
     `119f4831…` `[V]` dry-run probe.
   - The programs differ in two more ways. The PDB path in the DLL is
     `/_/src/WebAPI/obj/Release/net9.0/linux-x64/WebAPI.pdb`, and the PE Machine
     field is `0x8664` (x64) instead of `0x014c` (any CPU). The DLL is still IL
     only `[V]` header fields.
5. Not measured on `e6e92423`; the dry run's reprotest was stopped. See 16.
6. Not run: `d0a817c9` replaced run 4.
7. Held.
8. Wrong. `packages.lock.json` does not ship `[V]`.
9. Held, and further than predicted. The libraries were built into
   `bin/Release/net9.0/linux-x64/`, and 14 of 1237 shared files differed from
   run 1: every own DLL and PDB in both folders and both `deps.json`. The
   programs changed with the libraries `[I]`, most likely through the reference
   MVIDs a PDB records. Not predicted: four new files, `onnxruntime.dll` and
   `onnxruntime_providers_shared.dll` in both folders. They are Windows DLLs
   (PE32+ for MS Windows), byte-identical to
   `microsoft.ml.onnxruntime/1.20.1/runtimes/win-x64/native/` `[V]`. The Linux
   release shipped the Windows ONNX Runtime next to `libonnxruntime.so`.
10. Held: the other 1223 files, runtime and packages included `[V]`.
11. Held.
12. Held.
13. Wrong for two files. Every DLL and PDB is back to run 1's bytes, and the
    libraries are built into `bin/Release/net9.0/` again `[V]`. The two
    `deps.json` differ in nine lines, all version strings: they list
    ApplicationCore and Infrastructure as `1.0.0` while the DLLs beside them
    say `0.0.0-thesis` `[V]`. The separate restore ran without the version
    properties, and `deps.json` takes project versions from restore's
    `project.assets.json`.
14. Held.
15. Held. All 1237 files are identical to run 1, both `deps.json` included
    `[V]`.
16. Held. "Reproduction successful" (log 9696 lines). Both reprotest builds,
    in `const_build_path` and `build-experiment-1`, produced a hash list
    identical to run 7's from the lab: three build paths, one release `[V]`.

## Interpretation

**The release's publish step is deterministic, on one path and across
paths.** After PathMap nothing in the shipped release depends on where it was
built. Layer 1's two open path channels, W8 and W9, close in layer 2 because the
files are not part of the release, not because anyone fixed them.

**A release DLL cannot be checked against `dotnet build`.** The version stamp,
the RID in the PDB path and the x64 flag all differ. Only the release's own
command reproduces the release. The version string is itself a build input to
every own assembly: the tag name, declared by whoever pushes it, ends up in all
four DLLs.

**What ships is decided by defaults, not by a list.** An empty npm file shipped
because of a glob, and a setting meant for the lock files put Windows binaries
into the Linux release. Both builds were deterministic, so a reprotest would not
have caught either. A byte comparison against the previous release did, within
an hour, and so did the `deps.json` versions after the next change. That is a
use of reproducibility the plan did not have: every build change shows up as a
diff, whether or not the build succeeds.

**The lock files pin the dependencies without changing the release.** They
record the direct and transitive graph, 334 packages for WebAPI, with a content
hash per package, and in locked mode restore fails instead of drifting. With
the two follow-up fixes the release is byte-identical to the unlocked one from
run 1, except the removed stray file. This moves the dependencies from
"resolved the same so far" to "pinned by hash", a precondition for reproducible
builds. It does not show that the packages themselves can be rebuilt from
source; that is the dependency part.

## Caveats and not tested

- `arch` only.
- The SDK is not the release's. The release job runs `actions/setup-dotnet`
  with `dotnet-version: '9.0.x'`, the newest 9.0 SDK on the day, and
  `global.json` on `main` accepts any SDK from 9.0.0 up, previews and newer
  majors included (`rollForward: latestMajor`, `allowPrerelease: true`)
  `[V]` `03-release.yml`, `global.json` at `a2dc1d5b`. The branch's exact pin
  would probably fail in that job as it stands `[I]`.
- No `.git` in the lab. The release is built in a git checkout, where the SDK
  appends the commit to `InformationalVersion` and Source Link writes the
  repository URL and commit into the PDB. A rebuild from a copied tree cannot
  match those bytes without supplying the same commit `[I]`, not measured.
  Phoenix's `SystemInfoService` cuts the `+commit` off before displaying the
  version.
- `--locked-mode` stands in for CI's `GITHUB_ACTIONS` condition. The locked
  restore in CI itself has not run.
- How `RuntimeIdentifiers` on the libraries pulled win-x64 native files into a
  linux-x64 publish is not established `[I]`.
- Only `+build_path` on layer 2. Time, locale, umask, exec_path and file order
  were not run on publish.
  Added 24/9: time, locale, umask and exec_path ran in
  [phoenix-layer2-reprotest](2026-09-24-phoenix-layer2-reprotest.md). Locale is
  red (W26). The same note shows that reprotest's builds run on one CPU with
  `TZ=GMT+12` and `LANG=C.UTF-8`, and restore from `/tmp/dch/.nuget/packages`
  (W28), which also held for the `+build_path` run here.
- No frontend (layer 3), no zip (layer 4). The `win-x64` publish runs on a
  Windows runner with Authenticode signing and is not measured. The release
  also ships an EF migration bundle, a self-contained single-file executable,
  which is not measured.
- `WebAPI.csproj` lines 38-44 copy `libnlopt.dylib` from `/opt/homebrew/lib` or
  `/usr/local/lib` into the output when the build machine has it. A build on a
  Mac with Homebrew's nlopt ships a native library that a Linux build does not
  `[I]`, not measured.
- Clock times in the expectation headings were corrected the same evening
  from the log files; the order of expectation and run is unchanged.
