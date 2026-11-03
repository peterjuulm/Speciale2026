# Determinism in a fixed environment: the run of 1 November 2026

Result note for [2026-10-28-determinism-plan.md](2026-10-28-determinism-plan.md).
One machine (`arch`), one SDK, 157 package recipes, eight reprotest
variations, two build configurations. Everything measured is in
`dependencies/data/2026-11-01-determinism/arch/`: `results.tsv` (one
row per package, mode and axis), `packages.tsv` and `summary.md` (the
tables below, printed by `determinism-summary.py`), `run.log` and
`full.log` (every run with start and end time), `kommando.txt` (every
command and restart, with the reason), `environment.txt`, and per
package the build logs and the comparison of every run.

The per-axis reading covers all 90 built packages. The last four, the
heaviest Roslyn builds (Microsoft.CodeAnalysis.CSharp, CSharp.Features,
CSharp.Workspaces, Features; 30 minutes per axis), finished at 06:57 on
2 November and behaved like the other Roslyn packages: `build_path`
differs as is, identical under configuration. The note was drafted at 86
packages on the evening of 1 November and the numbers were brought to 90
on the morning of 2 November; no reading changed.

## Question and method, in one page

**Question.** Given the same source and one fixed build environment,
does the ecosystem's default build of a .NET package give the same
bytes, which variations of the environment break it, and does the
ecosystem's own deterministic-build configuration repair it? This is
Benedetti et al.'s question (2025) asked of NuGet, which they did not
study: their Figure 3 sorts builds into *reproducible as is*, *with
infrastructure configuration*, *with a patched package manager* and
*unreproducible*; their Figure 4 says which reprotest variation breaks
the build. We use the first two categories and the last; the patched
package manager is not tested (no patch to NuGet was tried). No
comparison with nuget.org: both sides of every comparison are our own
builds.

**Population.** The 157 package-versions of Phoenix's dependency census
for which experiment 1 derived a project path (54 third-party, 103
Microsoft). 51 were excluded before building on the causes batch 3
established on 27 October (43 platform libraries whose project only
builds inside the repository build, 4 needing SDK workloads, 3 reading
an internal feed, 1 with a generated props file); 16 did not build under
the default command and are listed with their first error; **90 built**
and were measured. The 41 census packages without a derived project
path are not in the run.

**Fixed environment.** .NET SDK 10.0.403 (NuGet 7.9.0-rc.2412) installed
from the official tarball with its SHA-512 checked; one package cache
filled by a single online restore per package; every measured build runs
with `--no-restore` from a clean clone at the declared commit
(`core.autocrlf=false`, submodules initialised); `global.json`'s `sdk`
pin removed where the fixed SDK cannot satisfy it (60 of 90, the row
says which version was pinned; 29 have no pin, DiaSymReader's is kept), `msbuild-sdks` kept so the Arcade-in-tree
repositories still resolve. Host: kernel 7.2.11-arch1-1, glibc 2.44,
reprotest from pipx, disorderfs 0.6.2, faketime 0.9.13, PowerShell 7.6.9
as a dotnet tool (the Azure SDK's build gate runs a script). Full record
in `environment.txt`.

**Two commands.**

| mode | command |
|---|---|
| as is | `dotnet build PROJECT -c Release --no-restore -p:UseSharedCompilation=false && dotnet pack PROJECT -c Release --no-build -o out -p:UseSharedCompilation=false` |
| configured | the same plus `-p:ContinuousIntegrationBuild=true -p:Deterministic=true -p:DeterministicTimestamp=<commit time, unix seconds>` |

"As is" is what a consumer who clones the repository and packs gets.
"Configured" is Benedetti's "reproducible with infrastructure
configuration": the three properties the .NET ecosystem itself offers
for deterministic output (source paths mapped to `/_/`, deterministic
compilation, fixed ZIP entry timestamps), nothing from the publisher's
own CI. `UseSharedCompilation=false` keeps the compiler out of a server
process, which the `time` axis hung on in the pilot.

**Eight variations**, one at a time, each against its own control build,
as reprotest does: `build_path`, `environment`, `locales`, `exec_path`,
`time` (the clock set about a year ahead), `timezone`, `umask`,
`fileordering` (disorderfs). Not varied: `kernel` (Benedetti's Figure 4
includes it; it needs a second kernel on the host), `user_group` and
`domain_host` (root). Benedetti reduced the range of the `time` variation
because a registry handshake failed under a far-off clock (their section
III-E); we kept reprotest's default, and the two Node failures below are
that effect.

**Three levels** per pair of builds:

| level | compares |
|---|---|
| 1 whole file | the `.nupkg` byte for byte |
| 2 content | every archive entry by bytes, except NuGet's packaging files (`nuget.psmdcp`, `_rels/.rels`, `[Content_Types].xml`) |
| 3 DLLs | the assemblies (`.dll`, `.exe`) under `lib/`, `ref/`, `runtimes/` by bytes; nothing else in the archive and no symbol package |

Verdict per (package, mode, axis): `same`, `differs` (with the first
differing entry) or `failed` (a build under the variation produced no
package). Two builds of one run are paired by package id, because two
packages put the clock into the version and so the file name; where the
produced package does not carry the recipe's id, the one produced is
compared and the row says so (two cases: Humanizer.Core's project packs
`Humanizer`, Workspaces.MSBuild's packs
`Microsoft.CodeAnalysis.ExternalAccess.RazorCompiler`). Symbol packages
(`.snupkg`) are not compared.

**Per-package category** at each level, Benedetti's Figure 3:
*as is* when every as-is run is `same`; *with configuration* when every
as-is difference has a configured run that is `same`; *unreproducible*
when a configured run still differs or fails. One inference inside
"with configuration", stated here because it carries 60 of the 62
packages: the configured run was made per axis only where content or a
DLL differed (nearly always `build_path`) plus `time`; for the six other
axes, where the as-is difference was ZIP entry timestamps only, the
verdict is taken from the configured `time` run, on the reasoning that
`DeterministicTimestamp` fixes the entry time whatever else is varied.
Two packages were configured on all eight axes (GuardClauses,
Microsoft.OpenApi, the pilot) and SixLabors.Fonts on five; all identical.
"Entry timestamps only" is verified, not assumed: for all stored as-is
pairs with that verdict, every ZIP entry was compared field by
field (name order, method, CRC, sizes, attributes, flags, extra,
comment) and only the entry date differs `[V]` (584 pairs; check
script and output in the data folder's `causes/`).

**How it ran.** Pass A (09:23 to 14:30, with the restarts `kommando.txt`
records): screen every recipe once, then one run with all eight
variations applied at once. Pass B (14:42 to 23:17 for workers 2 to 4;
worker 1 to 06:57 on 2 November): the eight axes one
by one for every built package, as is; a configured run for every axis
where content or a DLL differed or the build failed, plus `time` as the
one representative for the axes where only the whole-file hash differed
(entry timestamps; the fix does not depend on the axis). Pass B ran as
four workers on disjoint package sets, the Arcade-in-tree repositories
(Roslyn, msbuild, EF Core, symreader) alone in worker 1. Pilot (three
packages, all axes, both modes, read by hand) 08:45 to 10:05.

## Result

### Population

| outcome | packages |
|---|---|
| built under the fixed SDK, measured | 90 |
| excluded before the screen (batch 3's causes) | 51 |
| did not build under the default command | 16 |

Did not build `[V]` (`summary.md`, first error line): AutoMapper 13.0.1
(a pre-build command), Dapper 2.0.123 (Nerdbank.GitVersioning task fails
to load), dotnet-ef 10.0.12 (a path the pack target expects), the two
runtime packs (framework reference resolution; task host version), the
five IdentityModel 8.7.0 packages (CS7035: the clock-derived build number
exceeds 65535 at this hour, so the default build succeeds or fails with
the time of day), the five Svg 5.1.1 packages (CS0234, a missing
namespace), JwtBearer 9.0.0 and Razor.Language 6.0.24 (batch 3's errors
again, re-screened as samples).

### Per axis, as is (90 packages)

Packages whose two builds differ, of the 90 with all eight axes run:

| axis | whole file | content | DLLs | build failed |
|---|---|---|---|---|
| build_path | 90 | 86 | 86 | 0 |
| time | 88 | 18 | 18 | 2 |
| environment, locales, exec_path, timezone, umask, fileordering (each) | 90 | 5 | 5 | 0 |
| all eight at once (89 packages) | 87 | 83 | 83 | 2 |

Level 1 is never `same` as is: NuGet stamps every ZIP entry with the
build's own time, so two unvaried builds already differ there. The four
packages identical at content and DLL under every axis are CsvHelper
33.1.0, FluentValidation 11.11.0, FluentValidation.DependencyInjectionExtensions
11.11.0 and ScottPlot 5.1.57: they set `ContinuousIntegrationBuild` in
their own project files `[V]` (`CsvHelper.csproj` line 17,
`FluentValidation.csproj` line 15 for Release, `ScottPlot.csproj` line
35), so the default build already maps the path. The 5 packages that differ on every axis
are the IdentityModel 8.23.0 family.

### Per package, Figure-3 category (90 packages)

| level | as is | with configuration | unreproducible | not reached |
|---|---|---|---|---|
| 1 whole file | 0 | 66 | 24 | 0 |
| 2 content | 4 | 62 | 24 | 0 |
| 3 DLLs | 4 | 62 | 24 | 0 |

Reading: of the 90 packages (49 repositories), 66 produce identical
bytes, whole file included, once the
three ecosystem properties are set; 22 still differ, for five causes,
none of them in the compiler or the packer; 2 cannot be built under the
`time` variation at all (Node under faketime), which is a limit of the
measurement as much as of the package. The share is of this set, the
project-level, Linux-buildable part of Phoenix's dependencies, not of
NuGet.

### The 24 the configuration does not fix, by cause

| cause | packages | axis | where the difference is | candidate fix (not tested here) |
|---|---|---|---|---|
| date in the package version | Azure.Core 1.50.0, Azure.Identity 1.17.1, Azure.Storage.Blobs 12.20.0, Azure.Storage.Common 12.19.0, Azure.Security.KeyVault.Certificates 4.6.0, Azure.Security.KeyVault.Secrets 4.6.0, Azure.Communication.Email 1.0.1, System.ClientModel 1.8.0 | time | the version `X.Y.Z-alpha.<yyyymmdd>.1` in nuspec, file name and assembly attributes | the repository's release switch (`OfficialBuildId`-style publisher configuration), not an ecosystem property |
| clock in the package version | Microsoft.IdentityModel.Abstractions, JsonWebTokens, Logging, Tokens, System.IdentityModel.Tokens.Jwt, all 8.23.0 | every axis | the version `8.22.1-preview-<yMMddHHmmss>`: two builds a minute apart already differ, whatever is varied | the publisher's release build number; the default build is never reproducible |
| copyright year from the clock | Swashbuckle.AspNetCore.Swagger, SwaggerGen, Annotations 7.2.0; Stateless 5.16.0 | time | `<copyright>` in the nuspec and `AssemblyCopyright` in the DLL: `$([System.DateTime]::Now.ToString(yyyy))` in Swashbuckle's `Directory.Build.props` line 10 and `Stateless.csproj` line 9 `[V]` | a literal year in the project file |
| npm in the build | Swashbuckle.AspNetCore.ReDoc, SwaggerUI 7.2.0 | time (build fails) | the project runs `npm` to bundle its web assets; Node does not run under libfaketime (the npm check in the project fails) | a build that does not need Node, or a `time` variation Node survives; the as-is build fails the same way |
| Arcade's date-based build number | Microsoft.Build.Framework 18.0.2 | time | `AssemblyFileVersion` 18.0.2.55101 against 18.0.2.60401: Arcade computes the build number from `DateTime.Now` when `OfficialBuildId` is empty | `OfficialBuildId`, publisher configuration (experiment 1's versions 3 and 5 set it) |
| a hash of the project path inside the PDB | Quartz, Quartz.AspNetCore, Quartz.Extensions.DependencyInjection, Quartz.Extensions.Hosting 3.13.1 | build_path | LibLog ships its source as `.cs.pp` content files; the SDK writes the preprocessed files to `obj/.../NuGet/<hash of the project path>/LibLog/5.0.8/*.cs`; the folder name is a PDB document name, PathMap maps the prefix and not the hash; the DLL follows through its PDB id and PDB checksum (36 bytes per PDB, 201 per DLL) | a path-independent location for preprocessed content files (SDK or project), or not consuming source-shipping packages (LibLog is retired); the three tested properties do not map the hash |

## Readings, with the evidence

Each reading states what was measured `[V]` (file, run, bytes) before
what it means `[I]`.

### 1. `build_path` is the ecosystem's one systematic fault, and the configuration closes it

`[V]` 86 of 90 packages differ at the DLL under `build_path` as is;
under the configured run 77 of the 86 are identical at every level,
whole file included, the nine that are not being the five IdentityModel
(clock) and the four Quartz (reading 6) packages. The as-is difference is
the PDB path in the CodeView debug entry and the source paths in the
PDB, read in the pilot with `dllreport.cs`. `[I]` The default build of a
.NET library is not path-independent; `ContinuousIntegrationBuild=true`
(which turns on `DeterministicSourcePaths`, the `/_/` map) makes it so
for every package that has no other path leak. The four packages
identical as is are the ones that set the property themselves.

### 2. No other variation reached the bytes in these runs

`[V]` `environment`, `locales`, `exec_path`, `timezone`, `umask` and
`fileordering` change the DLL in exactly the five packages whose version
carries the clock, that is in none for a reason of their own; `[I]` in
these 90 packages csc and NuGet 7.9 showed no sensitivity to the host's
locale, timezone, umask, environment block, executable path or directory
order. One pair per axis and one offset per variation: this is "no
difference detected", not a proof of invariance. Prediction 4 holds and
prediction 5 (file ordering reaching content) found zero cases: NuGet's
sorted entries hold.

### 3. Level 1 as is is never reproducible, and the fix is one property

`[V]` no package is `same` at the whole file as is under any axis (88 differ and 2 fail under `time`, 90 differ under every other); on the
six axes that do not touch path or clock, 85 of the 90 differ on entry
timestamps only (the other five are IdentityModel); the configured
`time` run is identical at the whole file for 70 packages, every one
that is identical at content. `[I]` NuGet 7.9
stamps ZIP entries with the build time unless `DeterministicTimestamp`
is given (`SOURCE_DATE_EPOCH` is ignored by this SDK, own measurement 28
October). The artifact a consumer hashes is therefore never reproducible
by default, even when every byte of content is; the sharpened prediction
1 of the pilot holds for all 90.

### 4. `time` is where the publishers' own logic shows

`[V]` 18 packages differ at the DLL under `time`, 2 fail to build;
every one is explained by the table above: 13 by a date or clock in the
version, 4 by a copyright year, 1 by Arcade's build number, 2 by Node
under faketime. `[I]` None is a compiler or packer fault; each is a
decision in the repository's own build logic to read the clock. That
is the part of the build the ecosystem's three properties do not touch,
and it is where a release record would have to pin a value (the build
id, the year) rather than a tool.

### 5. Two packages are never reproducible, and one family cannot even be built at some hours

`[V]` IdentityModel 8.23.0 packs `8.22.1-preview-71101104314`,
`-71101160714`, and so on: the clock to the second in the version, so
the two builds of a single reprotest run produce differently named
packages on every axis; IdentityModel 8.7.0 fails with CS7035 because
the same scheme overflows the 16-bit build number at this time of day.
`[I]` The default build of this family is not a build of the release at
all; the release's version exists only with the publisher's build
number. Experiment 1 saw the same as A ≠ A2.

### 6. A path can hide where PathMap does not look (Quartz)

`[V]` Under `build_path`, configured, the four Quartz DLLs differ in
their PE timestamp, checksum, CodeView GUID and PDB checksum only (the
CodeView path is `/_/src/Quartz/obj/Release/net6.0/Quartz.pdb` on both
sides); rebuilt by hand twice in two paths with the symbol package kept,
the four PDBs differ in 36 bytes: the PDB id and the document name
`obj/Release/net6.0/NuGet/9917C68F5A74CEA5/LibLog/5.0.8/ILog.cs` against
`.../NuGet/37F2B1329D3E1CC3/...`. The folder is the SDK's
`ContentPreprocessorOutputDirectory`
(`Microsoft.PackageDependencyResolution.targets` line 44) and the hash
is NuGet's hash of the consuming project's path. `[I]` The DLL's bytes
depend on the path through a document name the compiler records for a
source file it was handed; `DeterministicSourcePaths` maps the directory
prefix, which is the same on both sides, and leaves the hash. A
reproducibility check at the DLL would flag Quartz as path-dependent
without the PDB ever being in the package; the symbol package is where
the cause is readable.

### 7. Arcade-in-tree packages behave like the rest, except on `time`

`[V]` Microsoft.Build.Framework, the eight Roslyn packages,
Microsoft.DiaSymReader and the EF Core 10.0.12 packages are
`build_path`-dependent as is and identical under configuration on every
axis but Build.Framework's `time`. `[I]` Prediction 7 holds; Arcade's
dev-build versioning is fixed except for the date-based file version,
which `OfficialBuildId` pins.

### 8. The default build is not a build of the release, for half the packages

`[V]` 44 of the 90 as-is builds produce a package whose file name does
not carry the release's version (`packages.tsv`, column `nupkgs` in the
state files): 8 pack `1.0.0` or `2.0.0`, the SDK's default when no version
is set outside CI (CsvHelper, ExCSS, YamlDotNet, Cronos, FluentModbus,
Hangfire.AspNetCore, Hangfire.NetCore, Humanizer, MediatR.Contracts);
Bogus packs `0.0.0-localbuild`, SixLabors.Fonts `0.0.1`; the 14
Arcade-in-tree packages pack `X.Y.Z-dev`; SolutionPersistence and
Mono.TextTemplating pack `-g<commit>` (a git-describe version); the 8
Azure packages `-alpha.<date>.1`; the 5 IdentityModel the clock;
Portable.BouncyCastle `1.9.0.1`. `[I]` For these the version is an input
of the publisher's CI (a pipeline variable, a tag, a build id), not of
the repository at the commit. A determinism result on such a package is
a result about the bytes of the code, not about the release; and a
release record that names only repository and commit does not name the
version the build will stamp. This is the same gap experiment 1 met as
"identity properties" (repository-build readings 1 and 7).

## Predictions of the plan, checked

| prediction | outcome |
|---|---|
| 1 whole file differs on `time` for every package | holds, and more: differs on every axis, on entry timestamps |
| 2 IdentityModel (9) and Azure (8) differ everywhere on `time` | holds for Azure (8) and IdentityModel 8.23.0 (5, on every axis); the four IdentityModel 8.7.0 did not build (CS7035), a stronger form of the same cause |
| 3 `build_path` differs at the DLL unless the project sets CI build; same under configuration | holds for 86 of 90 and 77 of the 86; the exceptions have a second cause (clock, PDB hash) |
| 4 the five host axes change nothing | holds (0 of 90 for a cause of their own) |
| 5 `fileordering` reaches content in a few | 0 cases; NuGet's sorted entries hold |
| 6 configured run: whole file same except where the version embeds the clock | holds, plus the copyright-year, npm and PDB-hash cases |
| 7 Arcade-in-tree like the rest except on `time` | holds |

## Driver faults during the day, all fixed and the affected rows run again

Recorded in `kommando.txt` and the plan note's run-day log: a full clone
per package filled the disk (106 GB at 60 packages; shared clones from
one mirror per repository since 11:05); the mirror path as `origin`
broke Arcade's `RepositoryUrl` (reset to the real URL); `pwsh` missing
for the Azure SDK's build gate (added to the lab); `NUGET_PACKAGES`
without a trailing slash failed Source Link's source-root check;
submodules not initialised (SixLabors.Fonts); NodaTime's commit on no
branch (fetched on request); packages paired by file name, which the
clock-in-version packages broke (paired by id since 11:10). Pass B's cost
(2 to 3 minutes per axis and package) forced the two measures above:
configured runs limited to content differences plus `time`, and four
parallel workers. The running workers had loaded the driver before the
16:10 change that keeps `.snupkg` files, so the stored runs carry
`.nupkg` only; Quartz's symbol package was rebuilt by hand (reading 6).

## Caveats and not tested

- One machine, one Linux, one SDK. Windows is out (reprotest is
  Linux-only); the result on 10.0.1xx would differ at level 1 on the
  `psmdcp` GUID, stated not measured.
- The configured run was made per axis only where content differed or
  the build failed; for the axes where only entry timestamps differed,
  `time` stands for all. The reasoning (the timestamp fix does not depend
  on the axis) is sound but the six other configured runs per package
  were not made; the same command adds them.
- Selection: the 90 measured packages are the part of Phoenix's census
  that has a project-level build under one Linux SDK. 310 census
  package-versions name a repository and commit; experiment 1 derived a
  project path for 157 of them (the recipes of this run); 51 of those
  were excluded on batch 3's causes (43 platform libraries with no
  project-level build, 4 workloads, 3 internal feed, 1 generated props)
  and 16 did not build. The 153 without a recipe, among them the 41 whose
  derivation stopped at the SDK step, are not measured. The 43 platform
  libraries' determinism is known only as A = A2 from experiment 1's
  repository builds. Packages from one repository are not independent
  observations: the 90 come from 49 repositories, and the five causes
  above are repository causes (Azure SDK, IdentityModel, Swashbuckle,
  Quartz, Arcade).
- Network: restore ran once per package online; every measured build ran
  with `--no-restore`, but the plan's rule that a build reaching the
  network fails the run was not enforced (no network namespace). A
  project step that fetches on its own (the Swashbuckle npm bundle) could
  reach the network in both builds of a pair; in this run it failed
  under `time` and succeeded on the other axes, so the question did not
  arise, but it is a deviation from the plan.
- One control per axis and one build per variation (reprotest's design):
  a difference is observed, an equality is "not detected". Repeated
  unvaried pairs were not run beyond the pilot.
- The candidate fixes in the table are diagnoses, not tested
  interventions; none was applied and rebuilt.
- The Node-under-faketime failure is a property of the measuring tool
  as much as of the package: the `time` axis cannot be applied to a
  build that runs Node. Reported as `failed`, not as a difference.
- `time` is one offset (about a year ahead). A build that reads the clock
  at finer granularity (IdentityModel) differs between two unvaried
  builds as well, which the control pair shows but the table does not
  count separately.

## Closed

Every item of the plan has a decision:

- Steps 0 to 4 done; step 2's fallback (all axes at once first) was used
  for every package and the per-axis reading reached 90 of 90 (worker 1's
  last four Roslyn packages at 06:57 on 2 November; `finalize.sh` then
  produced `results.tsv`, `summary.md` and the per-package copies).
- Review (1 November, Codex, nine findings): taken into the note are the
  Figure 3/4 references, the inference inside "with configuration" with
  its count, the field-by-field verification of "timestamps only", the
  failed/differs split, the two package-id exceptions, the selection and
  network caveats, "candidate fix" instead of "what removes it", and the
  softened invariance claims. Not done, proposed for decision with Peter
  on 2 November: repeated unvaried control pairs for a few packages, the
  six remaining configured axes for all packages (one command, about a
  night), and one tested fix per cause (a literal year, `OfficialBuildId`,
  a pinned IdentityModel build number, a path-independent content folder
  for Quartz).
- Kernel, user_group, domain_host: out, as planned.
- The six other configured runs for timestamp-only axes: not made,
  reasoned above; out of scope for this note.
- The VMR and platform libraries under variation: out of scope (cost),
  decided in the plan.
- Windows: not feasible with reprotest; out.
