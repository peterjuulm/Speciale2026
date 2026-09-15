# Findings table: measured causes of non-reproducibility in .NET builds

Living document. One row per fine-grained cause, grouped by experiment. Only
what has actually been run is in here. Expected or planned items live in
[2026-09-15-layer-plan.md](2026-09-15-layer-plan.md) until they are measured.
Modelled on the taxonomy in the Maven Central study (reason, root cause,
fine-grained cause, mitigation), with our experiments and layers as the first
two levels.

## Columns

- **Experiment**: the umbrella a run belongs to. `empty-class` is the baseline
  on a one-file library, three machines, 7 to 14 September 2026. `ws-pems`
  is the work on the real Phoenix tree from 15 September 2026 on.
- **Layer**: 1 build, 2 publish, 3 frontend, 4 zip, 5 container, M method
  (about how we measure, not about the artefact).
- **Root cause**: the category.
- **Fine-grained cause**: exactly what differed, or exactly what was shown
  not to.
- **Where**: file and field.
- **Written by**: who produces the bytes in question.
- **Mitigation**: *fix build* (change in the project), *fix rebuild* (change
  in how one rebuilds or measures), *upstream* (outside our control, can only
  be pinned), *none needed* (measured stable), *open*.
- **Fix**: the concrete change, if any.
- **Status**: green (measured, closed or stable), red (measured, open).
- **Measured**: date, note, run. `[V]` when repeated at least once.

## Table

One table per experiment. Row ids are prefixed with the experiment (`E` for
empty-class, `W` for ws-pems) so a row can be cited on its own.

### empty-class: baseline on a one-file library, 7 to 14 September 2026

Three machines (`arch`, `ubuntu-vm`, Peter's `mac`), `minlib.dll` from one
`.cs` file, no packages. Notes `2026-09-07` to `2026-09-14`.

| # | Layer | Root cause | Fine-grained cause | Where | Written by | Mitigation | Fix | Status | Measured |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E1 | 1 | Baseline | Two clean builds, same path, same machine, same SDK: identical DLL and PDB | `minlib.dll`, `minlib.pdb` | csc | none needed | | green `[V]` | 7/9, 8/9 empty-class, -v2; `arch` `541bed82…`, `ubuntu-vm` and `mac` `4b3808d1…` |
| E2 | 1 | Tool identity | `arch` and `ubuntu-vm` gave different DLLs from the same source. Cause: two different `csc.dll` binaries both called 9.0.120 (Arch package `1b7543aa…`, Microsoft `644a4d33…`). Microsoft's SDK on `arch` reproduced the VM's bytes | `csc.dll`; `minlib.dll` | SDK vendor | fix rebuild | Fetch the SDK from the same source on every machine; record the `csc.dll` hash in the environment block | green | 8/9 compiler-identity, empty-class-v2 |
| E3 | 1 | Tool identity | The two compilers are the same Roslyn code (12 differing metadata lines out of 1672) and emit identical IL, yet the output differs in 70 of 4096 bytes: PE `TimeDateStamp`, MVID, debug-directory timestamp, PDB id, PDB checksum. The compiler's commit string is in the PDB, and the DLL carries a hash of the PDB | DLL debug directory, PDB `CompilationOptions` | csc | upstream | Bit-identity needs the vendor's own compiler binary, pinned by content. Same code is not enough | green | 8/9 compiler-identity, 9/9 findings |
| E4 | 1 | Tool identity | Microsoft's `csc.dll` is ReadyToRun and platform-specific: osx-arm64 `18245697…`, linux-x64 `644a4d33…`. Peter's Mac still produced the VM's `4b3808d1…`, because both carry the same Roslyn commit `fc52718e…`. Output identity follows the compiler's declared commit, not its bytes | `csc.dll`, `minlib.dll` | Microsoft | none needed for cross-platform; record platform + commit | | green | 9/9 empty-class-macos, 9/9 findings |
| E5 | 1 | Timestamp | PE `TimeDateStamp` is four bytes of a content hash written into a field labelled as seconds since 1970. Two thirds of values point into the future. It changes only when content does | DLL, PE header | csc | none needed | The build time is not in the artefact; it has to come from an attestation | green | 8/9 findings |
| E6 | 1 | Build path | reprotest `+build_path` red on `arch` and `ubuntu-vm`: absolute PDB path in the DLL's debug directory, absolute source paths in the PDB | `minlib.dll`, `minlib.pdb` | csc | fix build | `PathMap` | green | 14/9 environment-axes (red), environment-axes-pathmap (19 runs, all green, one hash per SDK) `[V]` |
| E7 | 1 | Environment | `+umask`, `+locales`, `+exec_path`, `+time` green on both Linux machines; `+fileordering` green on `ubuntu-vm` (`disorderfs`) | all build output | | none needed | | green `[V]` | 14/9 environment-axes, -pathmap |
| E8 | M | Method | `PathMap` given on the command line must use the shell's `$PWD`; `$(MSBuildProjectDirectory)` is not expanded in global properties and is silently ignored | csc `/pathmap` | MSBuild | fix rebuild | `-p:PathMap=$PWD/=/_/`; check with `strings minlib.dll \| grep pdb` | green | 14/9 environment-axes-pathmap |
| E9 | M | Method | Sorting the same file list under `da_DK.UTF-8` and `C.UTF-8` gives two different manifest hashes | our own hash lists | os | fix rebuild | `LC_ALL=C` in everything that sorts | green | 8/9 findings |
| E10 | M | Method | `bin/` is a copy of `obj/`. Deleting only `bin` makes MSBuild copy again without calling csc | `bin/*.dll` | MSBuild | fix rebuild | `rm -rf bin obj` | green | 8/9 findings |

### ws-pems: the real Phoenix tree, from 15 September 2026

Four own assemblies, ~300 copied dependencies, built from the worktree on
`thesis/reproducible-builds` in a lab without `.git`. Notes `2026-09-15-*`.

| # | Layer | Root cause | Fine-grained cause | Where | Written by | Mitigation | Fix | Status | Measured |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| W1 | 1 | Baseline | Two clean builds of the whole solution, same path, Microsoft SDK 9.0.120: 1610 files under `bin/Release`, 0 differ, including the generated `deps.json` and `runtimeconfig.json` | all of `src/*/bin`, `tests/bin` | csc, MSBuild | none needed | | green | 15/9 phoenix-layer1 |
| W2 | M | Method | Restore output (`project.assets.json`) lives in `obj/`. Deleting `obj/` between builds discards the resolved graph; both builds failed with NETSDK1004 | `obj/project.assets.json` | NuGet | fix rebuild | One run = clean + restore + build. A green result implicitly claims the graph resolves the same twice | green | 15/9 phoenix-layer1 |
| W3 | 1 | Build path | Absolute source paths in all four PDBs | PDB document table | csc | fix build | `PathMap` in `Directory.Build.props` | green | 15/9 phoenix-reprotest run 1 (red), run 3 (green) |
| W4 | 1 | Build path | The PDB path as a string in the DLL's debug directory. reprotest's two paths differ in length by 2, so every RVA behind the string shifts. Two paths of different length therefore change far more than the five identity fields | DLL, CodeView entry, `AddressOfEntryPoint`, import table | csc | fix build | `PathMap` | green | 15/9 run 1, run 3 |
| W5 | 1 | Build path | Four generated types named `<RegexGenerator_g>F<64 hex>__…`; the hex is a hash of the source file's path. The path became part of the type system | `ApplicationCore.dll`, `#Strings` heap | csc, on behalf of the regex source generator | fix build | `PathMap`; Roslyn hashes the mapped path, so the names became stable | green | 15/9 run 1, run 3 |
| W6 | 1 | Build configuration | `ContinuousIntegrationBuild=true` alone changed nothing. It takes the source root from Source Link, which finds it with git. In a tree without `.git`, csc received only `/pathmap:"~/.nuget/packages/=/_/"` | csc command line | SDK Source Link targets | fix build | Explicit `<PathMap>$(MSBuildThisFileDirectory)=/_/</PathMap>`, works with or without git | green | 15/9 run 2 (red), `dotnet build -v:n`, run 3 |
| W7 | 1 | Build path | The Razor source generator writes the absolute `.cshtml` path into `#pragma checksum` and `#line` lines of generated C#. Roslyn embeds that text in the PDB and hashes it. PathMap does not reach it. Two paths differing by 2 characters gave PDBs differing by 4 bytes, both in the two generated Razor documents | `WebAPI.pdb`, EmbeddedSource and document hash for `Pages_Error_cshtml.g.cs`, `Pages__ViewImports_cshtml.g.cs` | Razor source generator | fix build (Phoenix); open (any project using Razor) | Deleted `src/WebAPI/Pages/`, two template leftovers never registered in `Program.cs` | green for Phoenix, open in general | 15/9 run 3 (red), pdbdump, run 4 (green) |
| W8 | 1 | Build path | `WorkingDirectory` to `ClientApp/` in plain text | `spa.proxy.json` in `bin/` | MSBuild target from `Microsoft.AspNetCore.SpaProxy` | open | Dev-only file, only read when `launchSettings.json` sets `ASPNETCORE_HOSTINGSTARTUPASSEMBLIES`. Whether it is in publish is a layer-2 question | red | 15/9 runs 1 to 4 |
| W9 | 1 | Build path | Paths to `obj/…/compressed/` and to the NuGet cache in plain text | `WebAPI.staticwebassets.runtime.json` in `bin/` | MSBuild target from the SDK | open | Dev-only map of static assets. Whether it is in publish is a layer-2 question | red | 15/9 runs 1 to 4 |
| W10 | 1 | Environment | `+time`, `+locales`, `+umask`, `+exec_path` all green on Phoenix after the path fixes. The two json files were identical on these axes too | all four assemblies, PDBs, json | | none needed | | green | 15/9 runs 5 to 8 |

## Counts

Kept by hand when the table changes.

| | empty-class (E) | ws-pems (W) | total |
| --- | --- | --- | --- |
| rows | 10 | 10 | 20 |
| green | 10 | 8 | 18 |
| red | 0 | 2 | 2 |

## How the table is used

- A new experiment note adds its rows and points to itself in **Measured**.
  The note is the source, the table is the index.
- A row is green only with a measurement before and after the fix. A fix on
  its own is not enough.
- Nothing goes in here before it has been run. Planned axes and layers stay
  in the layer plan.
- Rows are never deleted. A cause that turns out wrong gets the status
  "rejected" and a note on why.
- `[V]` on a row means the measurement was repeated on another day or another
  machine and gave the same answer.
