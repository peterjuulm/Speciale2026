# Findings table: measured causes of non-reproducibility in .NET builds

Living document. One row per measured fine-grained cause, grouped by
experiment. Expected and planned items stay in
[2026-09-15-layer-plan.md](2026-09-15-layer-plan.md) until measured. The
structure follows the Maven Central taxonomy: reason, root cause,
fine-grained cause and mitigation. Experiments and layers are the first two
levels.

## Columns

- **Experiment**: the run group. `empty-class` covers the one-file library
  baseline on three machines from 7 to 14 September 2026. `ws-pems` covers
  the real Phoenix tree from 15 September 2026. - **Layer**: 1 build, 2
  publish, 3 frontend, 4 zip, 5 container, M method. Method rows are about
  measurement, not the artefact. - **Root cause**: the cause category. -
  **Fine-grained cause**: what differed, or what was shown not to differ. -
  **Where**: the affected file and field. - **Written by**: the component
  that produced the bytes. - **Mitigation**: *fix build* changes the
  project; *fix rebuild* changes the rebuild or measurement process;
  *upstream* is outside our control and can only be pinned; *none needed*
  means measured stable; *open* means unresolved. - **Fix**: the concrete
  change, if any. - **Status**: green means measured and closed or stable;
  red means measured and open. - **Measured**: date, note and run. `[V]`
  marks a measurement repeated at least once.

## Table

Each experiment has one table. Row ids use the experiment prefix (`E` for
empty-class, `W` for ws-pems), so rows can be cited independently.

### empty-class: baseline on a one-file library, 7 to 14 September 2026

The experiment built `minlib.dll` from one `.cs` file with no packages on
three machines: `arch`, `ubuntu-vm` and Peter's `mac`. See notes
`2026-09-07` to `2026-09-14`.

| # | Layer | Root cause | Fine-grained cause | Where | Written by | Mitigation | Fix | Status | Measured |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E1 | 1 | Baseline | Two clean builds with the same path, machine and SDK produced identical DLL and PDB files | `minlib.dll`, `minlib.pdb` | csc | none needed | | green `[V]` | 7/9, 8/9 empty-class, -v2; `arch` `541bed82…`, `ubuntu-vm` and `mac` `4b3808d1…` |
| E2 | 1 | Tool identity | `arch` and `ubuntu-vm` produced different DLLs from the same source. They used different `csc.dll` binaries, both called 9.0.120: Arch package `1b7543aa…` and Microsoft `644a4d33…`. Microsoft's SDK on `arch` reproduced the VM's bytes | `csc.dll`; `minlib.dll` | SDK vendor | fix rebuild | Fetch the SDK from the same source on every machine; record the `csc.dll` hash in the environment block | green | 8/9 compiler-identity, empty-class-v2 |
| E3 | 1 | Tool identity | The compilers contain the same Roslyn code, with 12 differing metadata lines out of 1672, and emit identical IL. Their output still differs in 70 of 4096 bytes: PE `TimeDateStamp`, MVID, debug-directory timestamp, PDB id and PDB checksum. The PDB contains the compiler's commit string, and the DLL contains a hash of the PDB | DLL debug directory, PDB `CompilationOptions` | csc | upstream | Bit-identity requires the vendor's compiler binary, pinned by content. The same code is insufficient | green | 8/9 compiler-identity, 9/9 findings |
| E4 | 1 | Tool identity | Microsoft's `csc.dll` is ReadyToRun and platform-specific: osx-arm64 `18245697…`, linux-x64 `644a4d33…`. Peter's Mac still produced the VM's `4b3808d1…` because both compilers carry the same Roslyn commit `fc52718e…`. Output identity follows the compiler's declared commit, not its bytes | `csc.dll`, `minlib.dll` | Microsoft | none needed for cross-platform; record platform + commit | | green | 9/9 empty-class-macos, 9/9 findings |
| E5 | 1 | Timestamp | PE `TimeDateStamp` contains four bytes of a content hash in a field labelled as seconds since 1970. Two thirds of values point into the future. The value changes only when the content changes | DLL, PE header | csc | none needed | The artefact contains no build time; an attestation must provide it | green | 8/9 findings |
| E6 | 1 | Build path | reprotest `+build_path` was red on `arch` and `ubuntu-vm`. The DLL's debug directory contained an absolute PDB path, and the PDB contained absolute source paths | `minlib.dll`, `minlib.pdb` | csc | fix build | `PathMap` | green | 14/9 environment-axes (red), environment-axes-pathmap (19 runs, all green, one hash per SDK) `[V]` |
| E7 | 1 | Environment | `+umask`, `+locales`, `+exec_path` and `+time` were green on both Linux machines. `+fileordering` was green on `ubuntu-vm` with `disorderfs` | all build output | | none needed | | green `[V]` | 14/9 environment-axes, -pathmap |
| E8 | M | Method | Command-line `PathMap` must use the shell's `$PWD`. `$(MSBuildProjectDirectory)` is not expanded in global properties and is silently ignored | csc `/pathmap` | MSBuild | fix rebuild | `-p:PathMap=$PWD/=/_/`; check with `strings minlib.dll \| grep pdb` | green | 14/9 environment-axes-pathmap |
| E9 | M | Method | Sorting the same file list under `da_DK.UTF-8` and `C.UTF-8` produces different manifest hashes | our own hash lists | os | fix rebuild | `LC_ALL=C` in everything that sorts | green | 8/9 findings |
| E10 | M | Method | `bin/` copies `obj/`. Deleting only `bin` makes MSBuild copy the files again without calling csc | `bin/*.dll` | MSBuild | fix rebuild | `rm -rf bin obj` | green | 8/9 findings |

### ws-pems: the real Phoenix tree, from 15 September 2026

The experiment builds four own assemblies and ~300 copied dependencies from
the `thesis/reproducible-builds` worktree, in a lab without `.git`. See
notes `2026-09-15-*` and `2026-09-23-*`. From 23/9 the lab is a `git archive`
export of the measured commit.

| # | Layer | Root cause | Fine-grained cause | Where | Written by | Mitigation | Fix | Status | Measured |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| W1 | 1 | Baseline | Two clean builds of the whole solution used the same path and Microsoft SDK 9.0.120. Of 1610 files under `bin/Release`, 0 differed, including the generated `deps.json` and `runtimeconfig.json` | all of `src/*/bin`, `tests/bin` | csc, MSBuild | none needed | | green | 15/9 phoenix-layer1 |
| W2 | M | Method | Restore output (`project.assets.json`) lives in `obj/`. Deleting `obj/` between builds removed the resolved graph, so both builds failed with NETSDK1004 | `obj/project.assets.json` | NuGet | fix rebuild | One run = clean + restore + build. A green result implicitly claims the graph resolves the same twice | green | 15/9 phoenix-layer1 |
| W3 | 1 | Build path | All four PDBs contained absolute source paths | PDB document table | csc | fix build | `PathMap` in `Directory.Build.props` | green | 15/9 phoenix-reprotest run 1 (red), run 3 (green) |
| W4 | 1 | Build path | The DLL's debug directory contains the PDB path as a string. reprotest's two paths differ in length by 2, shifting every RVA after the string. Paths of different lengths therefore change far more than the five identity fields | DLL, CodeView entry, `AddressOfEntryPoint`, import table | csc | fix build | `PathMap` | green | 15/9 run 1, run 3 |
| W5 | 1 | Build path | Four generated types are named `<RegexGenerator_g>F<64 hex>__…`. The hex is a hash of the source file's path, making the path part of the type system | `ApplicationCore.dll`, `#Strings` heap | csc, on behalf of the regex source generator | fix build | `PathMap`; Roslyn hashes the mapped path, so the names became stable | green | 15/9 run 1, run 3 |
| W6 | 1 | Build configuration | `ContinuousIntegrationBuild=true` alone changed nothing. It gets the source root from Source Link, which uses git. Without `.git`, csc received only `/pathmap:"~/.nuget/packages/=/_/"` | csc command line | SDK Source Link targets | fix build | Explicit `<PathMap>$(MSBuildThisFileDirectory)=/_/</PathMap>`, works with or without git | green | 15/9 run 2 (red), `dotnet build -v:n`, run 3 |
| W7 | 1 | Build path | The Razor source generator writes the absolute `.cshtml` path into generated C# `#pragma checksum` and `#line` lines. Roslyn embeds and hashes this text in the PDB. PathMap does not affect it. Two paths differing by 2 characters produced PDBs differing by 4 bytes, both in the two generated Razor documents | `WebAPI.pdb`, EmbeddedSource and document hash for `Pages_Error_cshtml.g.cs`, `Pages__ViewImports_cshtml.g.cs` | Razor source generator | fix build (Phoenix); open (any project using Razor) | Deleted `src/WebAPI/Pages/`, two template leftovers never registered in `Program.cs` | green for Phoenix, open in general | 15/9 run 3 (red), pdbdump, run 4 (green) |
| W8 | 1 | Build path | `WorkingDirectory` contains the plain-text path to `ClientApp/` | `spa.proxy.json` in `bin/` | MSBuild target from `Microsoft.AspNetCore.SpaProxy` | open | Dev-only file, read only when `launchSettings.json` sets `ASPNETCORE_HOSTINGSTARTUPASSEMBLIES`. Layer 2 determines whether publish includes it | red | 15/9 runs 1 to 4; not in the release, W17 |
| W9 | 1 | Build path | Plain-text paths point to `obj/…/compressed/` and the NuGet cache | `WebAPI.staticwebassets.runtime.json` in `bin/` | MSBuild target from the SDK | open | Dev-only static-asset map. Layer 2 determines whether publish includes it | red | 15/9 runs 1 to 4; not in the release, W17 |
| W10 | 1 | Environment | `+time`, `+locales`, `+umask` and `+exec_path` were green on Phoenix after the path fixes. The two json files were also identical across these axes | all four assemblies, PDBs, json | | none needed | | green | 15/9 runs 5 to 8 |
| W11 | M | Method | The 15/9 clean step `tests/*/bin tests/*/obj` missed the single test project in `tests/`. It still recompiled in 15/9's build 2, with 4660 warnings in both logs, so W1 holds | `tests/bin`, `tests/obj` | our script | fix rebuild | Clean `tests/bin tests/obj` | green | 23/9 cross-machine |
| W12 | 1 | File order | MSBuild sorts wildcard results with `StringComparer.OrdinalIgnoreCase` before the compiler sees them. ApplicationCore's 1567 and Infrastructure's 674 `Compile` items follow that order, not the directory order | csc source order | MSBuild, `EngineFileUtilities.cs` 337-341 | none needed | | green on `arch`; across machines and under disorderfs not measured | 23/9 cross-machine probes |
| W13 | 1 | Build invocation | Building the two programs with `UseSharedCompilation=false` gave the same 639 files as the solution build with the compiler server | `src/*/bin/Release` | MSBuild, csc | none needed | | green | 23/9 cross-machine, `arch` |
| W14 | M | Machine resources | `ubuntu-vm` (1 vCPU, 961 MB, up to 4 GB swap) could not compile Phoenix: Infrastructure ran 3 h without finishing. A verifier needs a machine with several GB of RAM | csc memory | | open | A bigger VM | red | 23/9 cross-machine, two attempts |
| W15 | 1 | Dependency resolution | A cold restore on `ubuntu-vm`, empty cache, resolved the same versions and `sha512` as `arch` for all four `src` projects: 95, 213, 336 and 221 packages | `project.assets.json` | NuGet | none needed; pinned since, W22 | | green, one observation | 23/9 cross-machine |
| W16 | 2 | Baseline | Two clean publishes with the release's own commands gave 1238 identical files, and so did a dry run four hours earlier | `release/` | SDK, csc | none needed | | green `[V]` | 23/9 layer2 runs 1-2 |
| W17 | 2 | Build path | `spa.proxy.json` and `WebAPI.staticwebassets.runtime.json` do not ship. `WebAPI.staticwebassets.endpoints.json` does, without paths. W8 and W9 do not reach the release | publish folder | SpaProxy targets, SDK | none needed | | green | 23/9 layer2 runs 1-8 |
| W18 | 2 | Stray content | An empty npm `package-lock.json` in `src/WebAPI`, committed by accident, shipped: the Web SDK copies `.json` files in the project folder into publish | `release/ws-pems-linux-x64/package-lock.json` | Web SDK content glob | fix build | Deleted, `b0a21823` | green | 23/9 layer2 runs 1-2 (red), 5-8 (green) |
| W19 | 2 | Version | The release's `/p:Version` and `/p:InformationalVersion` reach every assembly, the libraries included. ApplicationCore built with the same two properties is byte-identical to the published one | FileVersion, ProductVersion, AssemblyVersion | SDK | none needed | A verifier must know the version string | green | 23/9 layer2, dry-run probe |
| W20 | 2 | Runtime identifier | The programs published with `-r linux-x64` carry the RID in the PDB path, `obj/Release/net9.0/linux-x64/`, and PE Machine `0x8664` instead of `0x014c`. They are still IL only | `WebAPI.dll`, `BackgroundJobExecutor.dll` | SDK | none needed | Check a release DLL only against the same publish command | green | 23/9 layer2 |
| W21 | 2 | Vendor binaries | 323 of WebAPI's 746 files are byte-identical copies from the runtime packs 9.0.19. 228 of them are ReadyToRun images for Linux x64, PE Machine `0xfd1d` | runtime files | Microsoft | upstream | Pin the packs by hash | green | 23/9 layer2 run 1 |
| W22 | 2 | Dependency pinning | NuGet lock files record the direct and transitive graph with a content hash per package. Locked restore passes, and the release is byte-identical to the unlocked one apart from W18 | `packages.lock.json` | NuGet | fix build | `84d73a2f`, with `d0a817c9` and `2570034b` | green | 23/9 layer2 runs 7-8 |
| W23 | 2 | Build configuration | `RuntimeIdentifiers` on every project made the libraries platform-specific: they built into `…/linux-x64/`, 14 files changed, and the win-x64 `onnxruntime.dll` and `onnxruntime_providers_shared.dll` shipped in the Linux release | libraries, publish folder | SDK | fix build | `RuntimeIdentifiers` on the two programs only, `d0a817c9` | green | 23/9 layer2 run 3 (red), 5-6 (green) |
| W24 | 2 | Restore order | A separate restore without the version properties left both `deps.json` listing the libraries as `1.0.0` while their DLLs carried the release version | both `deps.json` | NuGet, SDK | fix build | The restore gets `/p:Version` and `/p:InformationalVersion`, `2570034b` | green | 23/9 layer2 runs 5-6 (red), 7-8 (green) |
| W25 | 2 | Build path | reprotest `+build_path` on the final tree: reproduction successful, and both reprotest builds match run 7 from the lab | whole release | | none needed | | green | 23/9 layer2 reprotest |

## Counts

Updated by hand when the table changes.

| | empty-class (E) | ws-pems (W) | total |
| --- | --- | --- | --- |
| rows | 10 | 25 | 35 |
| green | 10 | 22 | 32 |
| red | 0 | 3 | 3 |

## How the table is used

- Each experiment note adds rows and links itself in **Measured**. The note
  is the source; the table is the index. - A row turns green only after
  measurements before and after the fix. A fix alone is insufficient. - Only
  completed runs belong here. Planned axes and layers stay in the layer
  plan. - Rows are never deleted. If a cause proves wrong, its status
  becomes "rejected" and the note explains why. - `[V]` means the
  measurement was repeated on another day or machine with the same result.
