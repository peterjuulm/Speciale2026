# Layer plan: what we test, and in what order

Planning note, 15 September 2026. Not an experiment. Each experiment gets its
own note, named after the day it is run.

The idea: a release is built in layers. Each layer adds its own sources of
non-determinism, and we measure each layer with the same method as
[empty-class](2026-09-07-empty-class.md): build twice, hash everything, diff,
classify the cause, fix, build again, write it down. The goal for each layer is
one row in the table at the bottom.

## The layers

| Layer | Command / artefact | What is compared | Expected first result | Known breakage and known fix |
| --- | --- | --- | --- | --- |
| 1 | `dotnet build -c Release` | DLL, PDB, `deps.json`, `runtimeconfig.json` | Green on the same path (measured 15/9: 1610 files, 0 differing). Red across paths | Absolute paths in the PDB. Fix: `PathMap` / `ContinuousIntegrationBuild` |
| 2 | `dotnet publish` | The whole publish directory, ~300 assemblies, native libs, possibly ReadyToRun | Copied dependencies identical; unknown for generated files and R2R | Unknown. This is where the dependency tree sits |
| 3 | Frontend `npm ci` + `next build` | `out/`: HTML, JS chunks, manifests | Red | Random `BUILD_ID`. Fix: `generateBuildId` not yet measured in this repo |
| 4 | Release zip | The archive's bytes | Red | File mtimes and order in the archive. Fix: normalised packing, `SOURCE_DATE_EPOCH` |
| 5 | Container image | OCI layers, image digest | Red | apt and NodeSource are fetched at build time, layer timestamps. Fix: digests, `rewrite-timestamp` |

Layers 1-3 are loose files. Layers 4-5 are archives. File permissions, order and
timestamps only bite there, because that is what an archive stores.

## Axes per layer

Each layer is first run on the same path and the same machine (determinism).
Then we vary one thing at a time (reproducibility from the description):

| Axis | How | Status |
| --- | --- | --- |
| Build path | reprotest `+build_path` | Measured on Phoenix 15/9: red, closed with PathMap + deletion of the Razor pages |
| Machine | `arch`, `ubuntu-vm`, Peter's `mac`, same declared environment | Not measured on Phoenix. 23/9: `ubuntu-vm` too small (W14), paused |
| SDK binary | Microsoft's versus the Arch package's 9.0.120 | Measured on empty-class 8/9, not on Phoenix |
| Time | reprotest `+time` | Phoenix 15/9: green |
| Locale, umask, exec_path | reprotest | Phoenix 15/9: green. File order requires `ubuntu-vm` |
| Network | Restore from a pinned cache, build with `--unshare-net` | Not measured. The dependency part's test. 23/9: NuGet lock files on the branch (W22) |

## The dependency tree (runs in parallel with layer 2)

- Count direct and transitive packages per project. The dependency-graph tool
  from 15/9 gives 94 direct and 408 transitive NuGet packages, max depth 7. -
  Generate `packages.lock.json`, build with `--locked-mode`. Does the resolved
  graph change between machines or over time? - Re-check the `.deps.json`
  finding: the packages' sha512 are in the file, but are not checked at load.
  Compare them with the actual `.nupkg` hashes. - How many copied assemblies can
  be traced to a source revision, and how many are sealed vendor bytes?

## Result table (filled in as we go)

| Layer | Differing files | Differing bytes | Cause | Fix | Verified |
| --- | --- | --- | --- | --- | --- |
| 1, same path, `arch` | 0 / 1610 | 0 | | none needed | 15/9, one run |
| 1, different path, without fix | 10 / 10 | PDBs entirely, DLLs 70-190 | path in PDB, PDB path in DLL, regex type names, Razor text, 2 json | | 15/9 |
| 1, different path, with fix | 2 / 10 | 2 json | `spa.proxy.json`, `staticwebassets.runtime.json` | PathMap + delete `Pages/` | 15/9, one project left for layer 2 |
| 1, time / locale / umask / exec_path | 0 | 0 | | none needed | 15/9 |
| 1, `ubuntu-vm` | not measured | | VM too small to compile Phoenix (W14) | | 23/9, paused |
| 2, same path, `e6e92423` | 0 / 1238 | 0 | stray `package-lock.json` ships (W18) | deleted, `b0a21823` | 23/9, runs 1-2 and dry run |
| 2, same path and `+build_path`, `2570034b` | 0 / 1237 | 0 | lock files (W22) first shipped win-x64 files (W23) and wrong `deps.json` versions (W24) | `d0a817c9`, `2570034b` | 23/9, runs 7-8, reprotest |
| 3 | | | | | |
| 4 | | | | | |
| 5 | | | | | |

## Rules that apply to every layer

- Write the note with the expectation before the run. - Put the environment
  block first, including the hash of `csc.dll`. Two SDKs can carry the same
  name. - One run = clean + restore + build. See
  [phoenix-layer1](2026-09-15-phoenix-layer1.md) for why. - One build at a time
  on the machine. Never parallel builds in the same lab. - Build outside git.
  The lab is an rsync without `.git`. - Commit fixes on
  `thesis/reproducible-builds` in Phoenix, never in the lab. - Phoenix source
  and build output do not land in this repo. Hash lists and logs stay with Leo
  until agreed otherwise.
