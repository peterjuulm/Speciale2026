# Determinism experiment, Benedetti style: plan

Planning note, 28 October 2026, 15:30, written before the run. For
discussion with Peter before the weekend run. Scripts land under
`dependencies/experiments/nupkg/` (`reprotest-run.py` extended, a batch
driver next to it), data under `dependencies/data/2026-10-3x-determinism/`
named after the day each run starts.

## Two experiments, stated once

The thesis has two experiments on the packages Phoenix uses, and they ask
different questions:

1. **Rebuild against the publisher** (everything run 21 to 28 October:
   release-only, repository build, Windows). Question: can the bytes on
   nuget.org be produced again from what the release names? Answer by
   four levels against the shipped DLL. This is the part Benedetti et al.
   (2025, section III-C) put out of scope on purpose.
2. **Determinism in a fixed environment** (this plan). Question: given
   the same source and one fixed build environment, does the build give
   the same bytes, and which variations break it? Benedetti's question,
   their tool (reprotest), their shape of result (their Figure 4), on the
   .NET ecosystem they did not study. No comparison with nuget.org at
   all: both sides of every comparison are our own builds.

Experiment 1 found the inputs a release record does not name.
Experiment 2 measures whether the build is stable once every input is
held, which is the precondition for any such record to be checkable.

## Population and the exclusion rule

Start: the 310 package-versions of the census (`2026-10-13-dependency-census`)
that name a repository and a commit (341 minus 31 with no repository or
no commit). The experiment needs no PDB, no compiler record and no
publisher SDK, because nothing is compared with the shipped bytes; so the
41 packages excluded from experiment 1 as "not derivable" (no public SDK
holds their compiler) come back in here.

Inclusion rule, applied by the build-ability screen (step 1 below):
**a package is in when its project packs with the ecosystem default
command under the fixed SDK, from a clean clone at the declared commit.**
This is Benedetti's rule: a package whose build fails under the default
command is "reported as missing and discarded from the analysis since it
does not offer information on its build reproducibility" (section III-C).
Every exclusion is logged with the first error line.

Expected exclusions, from batch 3's logs (27 October):

| class | packages | why the default command cannot build them |
| --- | --- | --- |
| library projects of dotnet/runtime, dotnet/aspnetcore, dotnet/efcore, standalone or inside the VMR (dotnet/dotnet) | 37 | restore stops with "The shared framework must be built before the local targeting pack can be consumed": the project compiles against reference assemblies and a targeting pack produced earlier in the same tree by the repository's own build (Arcade). There is no project-level build of these packages; the repository build is the only build they have |
| aspnetcore 9.0.0 projects | 4 | restore reads an internal Azure DevOps feed (`dnceng/internal`) the public cannot reach |
| SkiaSharp, HarfBuzzSharp | 5 | need SDK workloads (ios, android) |
| Razor 6.0.24 | 2 | a `Directory.Build.props` the repository script generates |

**The 37 are a finding, stated as one:** for the core of the .NET
platform the unit "package" has no build of its own; determinism can only
be measured per repository build, which experiment 1 ran once (A = A2 on
Linux, see the repository-build notes) and this experiment does not vary.
The VMR on free runners and the VMR under eight variations are both cost
decisions, closed here as out of scope.

Expected population after the screen: about 90 known to build (48
Microsoft and 42 third-party from batches 2 and 3), plus whatever part of
the 41 returning packages builds; the screen gives the exact number
before any variation runs.

Packages whose single project still pulls the repository's Arcade logic
through `Directory.Build.props` (Roslyn, msbuild, symreader, EF Core's
Sqlite) stay in; the result table carries a column `build_logic` =
`sdk` or `arcade-in-tree`, so they can be read apart.

## The fixed build environment, and how it is fixed

One machine, Leo's desktop `arch`, as Benedetti used one machine. Nothing
is varied except by reprotest.

| part | fixed to | how it is fixed and recorded |
| --- | --- | --- |
| SDK | .NET SDK 10.0.403 (NuGet 7.9.0-rc.2412) | `install-sdk.py` from the official tarball into the lab, SHA-512 of the tarball checked against Microsoft's published checksum and written to `environment.txt`; the SDK's `.version` file copied |
| why this SDK | the latest 10.0.4xx; fixed `nuget.psmdcp` (NuGet 7.9, PR 7503); timestamps opt-in (PR 7661), the same behaviour .NET 11 RC 3 shows; `SOURCE_DATE_EPOCH` ignored, so the timestamp is passed as a property where the configured run wants it (own measurement 28 October, four SDKs) | |
| package cache | one `NUGET_PACKAGES` folder filled by a single online restore per package before the variations; every build after that runs with the public feed removed (`--source` pointing at the cache) | the cache folder is listed (ids and versions) into `restore.txt`; a build that reaches the network fails the run |
| host | kernel 7.2.11-arch1-1, glibc 2.44, `pacman -Q` of the whole system, disorderfs 0.6.2, reprotest version, faketime version | `environment.txt` per run, as in the earlier batches |
| locale set | `C.UTF-8` default, `et_EE.UTF-8` generated for reprotest's `locales` axis | `locale -a` in `environment.txt` |
| clone | `git clone` at the declared commit, `core.autocrlf=false`, no checkout conversion; submodules as the repository declares | commit and `git status --porcelain` after the build logged |
| command, as is | `dotnet pack <project> -c Release --no-restore -o out/` | the recipe (`recipe.toml`) holds the project path from experiment 1's derivation |
| command, configured | the same plus `-p:ContinuousIntegrationBuild=true -p:Deterministic=true -p:DeterministicTimestamp=<commit time, unix seconds>` | mirrors Benedetti's "reproducible with infrastructure configuration"; the commit time is read with `git log -1 --format=%ct` and logged |

The SDK is one for all packages. Where a repository's `global.json` pins
a version the fixed SDK cannot satisfy, the harness removes `global.json`
from the clone before the build and the result row says so
(`global_json = removed`); otherwise the file stays and the SDK's own
roll-forward applies.

## Variations and comparison

Eight reprotest axes, one at a time, each against its own control build
(as reprotest does): `build_path`, `environment`, `locales`, `exec_path`,
`time`, `timezone`, `umask`, `fileordering` (disorderfs). Exactly
Benedetti's set (their Table I); `kernel`, `user_group` and `domain_host`
stay out as in their study (decided 28 October, 15:50).

Three comparison boundaries, computed from the two output folders of
every (package, axis) pair with `compare.py`:

| boundary | compares | what a difference means |
| --- | --- | --- |
| 1 nupkg | the whole `.nupkg` file, byte for byte | the ecosystem's artifact, as a consumer hashes it |
| 2 entries | every entry in the archive by bytes, except the packaging files (`nuget.psmdcp`, `_rels/.rels`, `[Content_Types].xml`) | the content NuGet packs, minus the packer's own metadata |
| 3 lib | the DLLs under `lib/` (and `ref/`, `runtimes/`) by bytes | the compiler's output |

Verdict per (package, axis, configuration): `same` or `differs` at each
boundary; `differs` carries the first differing entry and, for DLLs, the
section `dllreport.cs` names (identity, version string, resource, IL).
Per package, the Figure-4 shape: reproducible as is on all axes;
reproducible with configuration on all axes; unreproducible, with the
failing axes listed.

## Order of execution

Everything in sequence on one machine (one heavy run at a time). Leo or
Peter types each step; the harness prints the exact command it ran into
`kommando.txt`.

| step | what | when | cost |
| --- | --- | --- | --- |
| 0 | pilot: three packages, one per kind (a plain third-party, a standalone Microsoft, one `arcade-in-tree`), all eight axes, both configurations; read every verdict by hand | Friday evening, with Leo at the keyboard | about 1 h |
| 1 | build-ability screen: every candidate once, as is; in/out list with the first error line; `population.tsv` committed before step 2 | Friday night | 2 to 3 h |
| 2 | as-is run, all packages, eight axes | Saturday | about 2 builds x 8 axes x 1 to 3 min x ~100 packages: 25 to 80 h at worst, so the batch driver runs the axes in Benedetti's order and the note records how far it got; `time` and `build_path` first, because they are the axes expected to fail |
| 3 | configured run only for the (package, axis) pairs that differed in step 2; pairs that were `same` as is are not built again (decided 28 October, 15:55) | Sunday | a fraction of step 2 |
| 4 | classification, the per-package table, the result note | Sunday evening or Monday | reading, no builds |

If step 2 cannot finish by Sunday, the plan's fallback is written here
and now: reprotest's all-axes-at-once mode (one control, one build with
every variation applied) screens each package in two builds; packages
identical under all axes at once are `same` on all eight and need no
per-axis run, and the per-axis attribution runs only for the rest. The
result note says which packages took which route.

## Predictions, written before the run

1. **Boundary 1, as is: `differs` on `time` for every package.** The ZIP
   entries carry the mtime of the freshly built files, and the SDK no
   longer stamps them. Boundary 2 and 3 unaffected by `time` for packages
   whose version does not embed the clock.
2. **Version from the clock: IdentityModel (9 packages) and the Azure SDK
   date suffix (8)** differ at all three boundaries on `time`; experiment 1
   already saw A ≠ A2 for the nine.
3. **`build_path`: boundary 3 `differs` for packages that do not set
   `ContinuousIntegrationBuild` or `DeterministicSourcePaths`** (the path
   enters the PDB and the DLL's source-link and checksum data); `same`
   under the configured run.
4. **`locales`, `timezone`, `umask`, `exec_path`, `environment`:
   `same` at every boundary for nearly all.** csc is deterministic by
   default; NuGet writes no permissions and no host names. A failure here
   is a package with its own code generation.
5. **`fileordering`: `same` at boundary 3; a few `differs` at boundary 2**
   where a project packs a globbed folder (content files, satellite
   assemblies); NuGet sorts entries since 7.9 (`Ensure stable order of
   files`), so the prediction is zero differences, and any hit is a
   finding.
6. **Configured run: boundary 1 `same` on all axes except where the
   version embeds the clock**, that is predictions 1 and 3 close, 2 stays.
7. **`arcade-in-tree` packages behave like the rest except on `time`**,
   because Arcade's dev-build versioning is fixed (`42.42.42.42424`) but
   its informational version carries a date.

## Reservations and what is not tested

- One machine, one Linux: no host variation beyond what reprotest fakes.
- The 37 platform packages and the 11 others above are not measured;
  their determinism per repository build is known only as A = A2 from
  experiment 1.
- Windows is not in this experiment; reprotest is Linux-only.
- Only the default command; a repository's own CI switches are not read
  (that is experiment 1's rung P).
- The SDK choice fixes NuGet 7.9 behaviour; the same run on 10.0.1xx
  would fail boundary 1 everywhere on the psmdcp GUID. Stated, not
  measured.

## Revisions on the run day, 1 November

Written before the full run starts, after the driver's first pilot package.

- **Driver:** `experiments/nupkg/determinism.py` (prepare, screen, run,
  batch, classify, environment). Lab `/private/tmp/nupkg-determinism/`:
  `sdk/` (10.0.403 from the official tarball, SHA-512
  `b7b3d846…dc7b9c5`, checked against Microsoft's release metadata),
  `nuget/` (the one cache), `src/<id>/`, `out/<id>/` (logs, `state.json`,
  the two stored `.nupkg` per run).
- **Command:** `dotnet build PROJECT -c Release --no-restore` then
  `dotnet pack PROJECT -c Release --no-build -o out`, with
  `UseSharedCompilation=false` (no compiler server; the faketime axis hung on
  one in round B). The plan's one-step `dotnet pack` fails with NU5026 on
  multi-targeting projects that set `GeneratePackageOnBuild` (GuardClauses in
  the pilot); the two-step form packs the same bytes. Restore runs once per
  package, online, before any variation; every reprotest build then compiles
  from a clean tree with `--no-restore`.
- **global.json:** the `sdk` pin is removed from the clone when present
  (`msbuild-sdks` kept, so Arcade-in-tree projects still resolve);
  the result row records it.
- **Population as run:** the 157 recipes experiment 1 derived (54
  third-party, 103 Microsoft), copied to
  `recipes/determinism/2026-11-01-determinism/`. The 41 packages whose
  derivation stopped at the SDK step have no project path recorded and are
  not in this run; stated as not derived, not as excluded.
- **Order as run, given results are needed on Monday 2 November:** step 1
  screen and step 2 as the all-eight-axes-at-once run for every package
  (two builds each) today; per-axis attribution and the configured rerun
  for the packages that differed, as far as the night allows, `time` and
  `build_path` first. The result note says which packages got the per-axis
  reading.
- **Pilot:** GuardClauses 5.0.0 (third-party), Microsoft.OpenApi 1.6.22
  (standalone Microsoft), Microsoft.Build.Framework 18.0.2
  (arcade-in-tree); all steps including per-axis and configured, read by
  hand before the batch starts.
- **Arcade-in-tree packages under `time`, configured (decided 1 November
  after the pilot):** the remaining difference is Arcade's date-based
  build number in `AssemblyFileVersion` (Build.Framework: 18.0.2.55101
  against 18.0.2.60401). It is not removed by the three ecosystem
  properties and the category stays "not reproducible with
  infrastructure configuration". The result note says in one sentence
  that the difference is fully explained and disappears with Arcade's
  `OfficialBuildId`, as experiment 1's versions 3 and 5 showed; no fourth
  run is added, because that property is publisher configuration, not
  ecosystem configuration.

### Pilot read, 1 November 08:45 to 10:05

| package | as is, which axes touch what | configured |
| --- | --- | --- |
| Ardalis.GuardClauses 5.0.0 | `build_path`: DLL differs (boundary 3); the other seven: DLLs and content identical, whole file differs on entry timestamps only | identical on all eight, whole file included |
| Microsoft.OpenApi 1.6.22 | same pattern as GuardClauses | identical on all eight |
| Microsoft.Build.Framework 18.0.2 (arcade-in-tree) | `build_path` and `time`: DLL differs; the other six: timestamps only | seven identical; `time` still differs: `AssemblyFileVersion` 18.0.2.55101 against 18.0.2.60401, Arcade derives the build number from the date (44 bytes, read with `dllreport.cs`) |

Readings before the full run: (a) boundary 1 as is fails on every axis,
including the ones that do not touch the clock, because NuGet stamps each
entry with the build's own time; so "as is" is never byte-identical, not
even between two unvaried builds, which sharpens prediction 1; (b)
prediction 3 holds for all three (`build_path` through the PDB path, fixed
by `ContinuousIntegrationBuild`); (c) prediction 7 holds for the
Arcade-in-tree package, and the configuration cannot fix a date in the
version. The full run started 09:23 with the same driver.

### Restart, 1 November 09:58

The first batch run was stopped at 09:55 after ten packages: two driver
faults and one cost decision.

- `git checkout -- .` in the restore step put `global.json` back, so every
  repository with an SDK pin failed restore in two seconds (the seven Azure
  SDK packages). The pin is now removed after every checkout.
- The mirror setting was read from the wrong environment, so each Azure
  package cloned azure-sdk-for-net from GitHub (four to five minutes each).
  Mirrors are now used; the first clone of a repository fills them.
- The 55 packages batch 3 could not build are not cloned and screened
  again one by one: 51 are excluded before the screen
  (`recipes/determinism/2026-11-01-determinism/excluded.tsv`, each with
  batch 3's cause), and one package per cause class is screened again
  under the fixed SDK as a check (HarfBuzzSharp 8.3.1.1,
  Microsoft.AspNetCore.App.Runtime.linux-x64 10.0.12, JwtBearer 9.0.0,
  Razor.Language 6.0.24). The seven packages batch 3 lost to errors of
  their own are screened again in full.
- The seven Azure rows that failed on the first fault were deleted and run
  again; the three pilot packages and the three third-party rows before
  them stand.
- 10:06, second restart: the Azure SDK repository's build gate
  (`eng/Directory.Build.Common.targets`, target ValidateReleaseNotes) runs a
  PowerShell script, and `pwsh` was not on the host; batch 3 had it on the
  Windows runner. A missing host tool is an environment fault, not a
  package finding, so PowerShell 7.6.9 is added to the fixed environment as
  a dotnet tool under the lab (`tools/`, on the build PATH, in
  `environment.txt`), and the one row that failed on it runs again.
- 10:25, third restart: ExCSS failed Source Link's SourceRoot check
  because the lab's `NUGET_PACKAGES` path had no trailing slash; the
  variable now ends with one, the row runs again. The three re-screened
  controls failed under the fixed SDK with batch 3's codes (NETSDK1226,
  NU1301, MSB4019), so the exclusion list stands.
- 11:00, the disk filled: the driver had made a full clone of the
  repository per package (6.6 GB for each Azure SDK package, 106 GB after
  60 packages). Stopped at the EF Core rows; the four rows that hit the
  full disk had no result recorded and run again. Clones now share the
  mirror's objects (`git clone --shared`, working tree only) and are
  dropped after each package's builds. The order changes with it: pass A is
  screen plus all eight axes at once for every package, pass B is per axis
  and configured for what differed; each pass re-clones from the mirror in
  seconds. Restarted 11:06 with 41 screened packages' results kept.
- 11:10 to 12:15, pass A findings that changed the driver, not the plan:
  IdentityModel 8.23.0 puts the clock into the package version
  (`8.22.1-preview-71101104314`), so the two builds of one reprotest run
  produce differently named packages; the comparison now pairs packages by
  id, and a build that produces no package is a `failed` verdict, not a
  difference. IdentityModel 8.7.0 (five packages) does not build at all at
  this hour: its clock-derived build number exceeds 65535 (CS7035), so the
  default build succeeds or fails depending on the time of day. NodaTime's
  declared commit is on no branch or tag and had to be fetched on request;
  a commit the mirror cannot get is now a `clone failed` screen result.
- 14:50, pass B cost: one package per axis took 2 to 3 minutes per axis
  (two builds; SixLabors.Fonts 68 s a build under reprotest), so pass B
  sequential would run past Monday morning for the 90 built packages.
  Two measures, both recorded: (1) configured runs are made for every axis
  where content or a DLL differed or the build failed, plus one
  representative axis, `time`, for the axes where only the whole-file hash
  differed on entry timestamps, since the timestamp fix does not depend on
  the axis; the other timestamp-only axes can be added later with the same
  command; (2) pass B runs as four workers on disjoint package sets
  (`lab/workers/w1..w4`, symlinks to the recipes), the Arcade-in-tree
  repositories (Roslyn, EF Core from the VMR, msbuild, symreader) alone in
  worker 1 so that at most one large working tree is copied at a time. The
  machine has 16 cores and 61 GB; four builds at a time are within it.
- 16:10, pass B readings so far, for the result note: Azure SDK (date in
  the version) and Swashbuckle.Swagger (the copyright year, computed from
  the clock, in nuspec and AssemblyCopyright) stay different on `time`
  under configuration; IdentityModel 8.23.0 (clock in the version) differs
  on every axis under both modes; Quartz 3.13.1 still differs on
  `build_path` under configuration, through the PDB checksum only
  (CodeView path is mapped to `/_/`), so the path survives inside the PDB,
  which the package does not carry; the stored runs kept only `.nupkg`
  files until 16:10, so Quartz's symbol package has to be built again by
  hand to read it.
- 23:20, pass B closing readings, workers 2 to 4 done (20:32, 21:44,
  23:17), worker 1 on its last four Roslyn packages. The three `time`
  differences not explained before are read: Stateless 5.16.0 computes
  the copyright year from the clock in its project file
  (`src/Stateless/Stateless.csproj` line 9,
  `$([System.DateTime]::Now.ToString(yyyy))`), the Swashbuckle pattern;
  Microsoft.Build.Framework 18.0.2 is the pilot's Arcade build number
  (`Version.BeforeCommonTargets.targets` line 47 of Arcade
  10.0.0-beta.25469.2, `DateTime.Now yyyyMMdd` when `OfficialBuildId` is
  empty). Quartz 3.13.1 under `build_path`, configured, was rebuilt by hand
  twice in two different paths with the symbol package kept (the running
  workers had loaded the driver before the 16:10 change, so no stored run
  has one): the four PDBs differ in 36 bytes each, the PDB id and one
  document name, `obj/Release/net6.0/NuGet/9917C68F5A74CEA5/LibLog/5.0.8/
  ILog.cs` against `.../NuGet/37F2B1329D3E1CC3/...`. LibLog delivers its
  source as `.cs.pp` contentFiles, the SDK writes the preprocessed files
  under `$(IntermediateOutputPath)NuGet\` (Microsoft.PackageDependencyResolution.targets
  line 44) in a folder named by a hash of the project path; PathMap maps
  the prefix, not the hash, so the path survives in the PDB, and the DLL
  follows through its PDB id and PDB checksum. Not fixed by the three
  ecosystem properties; a publisher fix is to not consume source-shipping
  packages (LibLog is retired). The nupkg itself carries no PDB, so the
  symbol package is where the difference lives and the DLL only points at it.

### Run end, 2 November 06:57

Worker 1 finished its last four packages (Microsoft.CodeAnalysis.CSharp,
CSharp.Features, CSharp.Workspaces, Features) at 06:57: `build_path`
differs as is at every boundary, the six host axes on entry timestamps
only, identical under configuration. `finalize.sh` ran at 06:58:
recompare, classify (1103 rows), summary, text-only copy of every
package's state, logs, diffs and file lists into `data/.../arch/out/`.
The result note's numbers went from 86 to 90 packages; no reading
changed. The ZIP field check now covers 584 pairs, still `date_time` only.
