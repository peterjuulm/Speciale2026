# Determinism in a fixed environment: the run of 2 to 3 November 2026

Result note for the rerun of [2026-11-01-determinism.md](2026-11-01-determinism.md)
over the new population, with the method of
[2026-11-02-determinism-method.md](2026-11-02-determinism-method.md).
Same machine (`arch`), same SDK, same eight variations and two build
configurations. Two things changed. The population is 224 rows derived
by `population.py` from the 341 packages Phoenix ships, instead of 157
recipes from experiment 1. And every one of the eight axes was run in
both modes for every built package; the 1 November run made the
configured run only where content differed, plus `time`.

Everything measured is in `dependencies/data/2026-11-02-determinism/arch/`:
`results.tsv` (one row per package, mode and axis), `categories.tsv` and
`summary.md` (the tables below, printed by `summary.py`), `run.log`, the
slices `slice-?.tsv`, `roslyn-?.tsv`, `rerun-?.tsv`, `rerun2-?.tsv` and
`rerun3.tsv` with their logs `night-w*.log`, `rerun-w*.log`,
`rerun2-w*.log` and `rerun3-w1.log`, `kommando.txt` (every start and
restart, with the reason), `environment.txt`, `population.tsv`, per
package the state file, the build logs and the comparison of every run
(`out/`), and the 11 screens that failed on the full disk
(`retired-nospace/`). `export.sh` made this folder from the lab; no
package or DLL is copied, only text. The
driver and the tables are `build-and-compare.py` and `summary.py` in
the private working repository
(`dotnet-rebuild-experiments/2-dependencies/2a-determinism/`), whose
README carries the same numbers.

The 1 November verdicts that the new population still contains were
carried over `[V]`: the state files were reused, and `results.tsv` of
the 01 run joined with this one on package, version, mode and axis
(`asis` read as `default`) gives 1012 rows in common, all 1012 with the
same three verdicts. 1008 of them were not run again. The other 4 are
the Swashbuckle ReDoc and SwaggerUI `time` runs, which had failed, were
redone on 3 November and failed the same way. The rest was built in the
night of 2 November and, where the night's builds failed on a full
`/tmp`, again on 3 November (see "Driver faults"). No `same` or
`differs` verdict in the tables comes from a run where a build failed;
only `failed` verdicts were redone.

## Result

### Population

| outcome | packages |
|---|---|
| rows of `population.tsv` with repository, commit and project | 224 |
| built under the fixed SDK, measured | 127 (68 repositories) |
| did not build under the default command | 97 |

The 117 rows of the 341 that stop before this table are
`population.py`'s: 75 ship no assembly of the package's name under
`lib/` (27 no managed code, 45 Humanizer.Core satellite resource
packages, 3 with the assembly under `runtimes/` or `tools/`), 20 name no
commit, 11 no repository, 8 could not be fetched, 3 have no single
project with the assembly's name (the README of 2a has the list).

Did not build, by first error `[V]` (`summary.md` §1, `categories.tsv`
column `screen`):

- 50 dotnet/runtime libraries (Microsoft.Extensions.*, System.*,
  Microsoft.Bcl.*) whose project reads the targeting pack from the
  repository build ("The shared framework must be built before the local
  targeting pack can be consumed").
- 10 ASP.NET Core 10.0.12 packages whose restore wants prune-package
  data the SDK does not have (NETSDK1226).
- 7 ASP.NET Core 6 to 9 packages that import a generated
  `Directory.Build.props` (MSB4019).
- 6 that do not compile at the commit (CS0234): Svg 5.1.1, five
  packages; System.IO.Hashing 6.0.0.
- 4 IdentityModel 8.7.0 (CS7035, the clock-derived build number, as on
  1 November).
- 2 that fail in an MSBuild task (MSB4018): Dapper 2.0.123 in
  Nerdbank.GitVersioning's version task; System.IO.Hashing 7.0.0 in
  package validation, which reads `PortableRuntimeIdentifierGraph.json`,
  a file the repository build generates.
- 2 that fail on a compiler warning the repository makes an error
  (CS8625): DocumentFormat.OpenXml 3.1.1 and DocumentFormat.OpenXml.Framework 3.1.1.
- 2 that fail a formatting analyzer set to error (IDE0055):
  NuGet.DependencyResolver.Core, NuGet.ProjectModel 6.12.1.
- 2 that read a feed that is gone or internal (NU1301): JwtBearer 9.0.0,
  DependencyInjection.Abstractions 2.1.0.
- 2 whose task host wants a newer SDK: Microsoft.Extensions.Logging.Abstractions,
  System.Text.Json 10.0.12.
- One each: AutoMapper 13.0.1 (a pre-build command, MSB3073),
  Microsoft.Build 17.11.48 (IDE0370), Microsoft.CodeAnalysis.Workspaces.MSBuild
  5.0.0 (NETSDK1085, with the right project this time),
  Microsoft.Identity.Client.Extensions.Msal 4.78.0 (CS9336),
  Microsoft.ML.OnnxRuntime.Managed 1.20.1 (workloads, NETSDK1147),
  Newtonsoft.Json 13.0.3 (its own API-compatibility gate),
  SixLabors.ImageSharp 1.0.4 (the commit is not in the repository),
  System.CodeDom 6.0.0 (CS0246), System.Reactive 5.0.0 (Windows
  targeting, NETSDK1100), System.Reflection.MetadataLoadContext 8.0.0
  (CS1929).

Of the 51 packages the 1 November run excluded before building on batch
3's causes, 47 are in the new population and all 47 did not build `[V]`
(the 01 run's `packages.tsv`, `screen` = `excluded`, against this run's
`categories.tsv`); the other 4 (SkiaSharp 3.119.0 and 3.119.2,
SkiaSharp.HarfBuzz 3.119.0, HarfBuzzSharp 8.3.1.3) are rows
`population.py` could not fetch (dead `fwlink` URL). Reading `[I]`: the
exclusion is now a measurement. For 50 of the 224 rows the project file
is not a build unit outside the publisher's repository build, which is a
fact about the ecosystem's largest publisher, not about the method.

### Per axis, as is (127 packages)

`[V]` `summary.md` §2:

| axis | whole file | content | DLLs | build failed |
|---|---|---|---|---|
| build_path | 127 | 123 | 123 | 0 |
| time | 125 | 18 | 18 | 2 |
| environment, locales, exec_path, timezone, umask, fileordering (each) | 127 | 5 | 5 | 0 |

The same shape as on 1 November at 90 packages: level 1 never `same` as
is (NuGet's entry timestamps); the four as-is reproducible packages at
content and DLL are the same four (CsvHelper, FluentValidation,
FluentValidation.DependencyInjectionExtensions, ScottPlot), which set
`ContinuousIntegrationBuild` themselves; the five that differ on every
axis are IdentityModel 8.23.0; `time` reaches those five and 13 others
(8 Azure, 4 copyright year, Microsoft.Build.Framework). The 85 runs with
all eight variations at once are the 1 November ones (89, less the two
packages out of the population and the two failed Swashbuckle runs, not
redone); they were not run for the 39 new packages.

### Per package, Figure-3 category (127 packages)

`[V]` `summary.md` §3, `categories.tsv`:

| level | as is | with configuration | unreproducible |
|---|---|---|---|
| 1 whole file | 0 | 102 | 25 |
| 2 content | 4 | 98 | 25 |
| 3 DLLs | 4 | 98 | 25 |

Every configured axis was run, so the category needs no inference this
time `[V]` (`summary.py` has no stand-in branch; `results.tsv` has 16
rows per built package, plus the `all` rows). The 25 are the same
packages at all three levels. At the whole file: 0 % as is, 80 % with
configuration, 20 % unreproducible, against 73 % and 27 % at 90
packages on 1 November. The 39 packages new to the measured set are,
with one exception (ClosedXML), repaired by the three properties.

### The 25 the configuration does not fix, by cause

The 24 of 1 November, with the same evidence (that note's table), plus
one:

| cause | packages | axis | where the difference is |
|---|---|---|---|
| the PDB path unmapped | ClosedXML 0.104.2 | build_path | the DLL's debug directory names the PDB by its absolute path `[V]` |

`[V]` `strings` on `lib/netstandard2.0/ClosedXML.dll` and
`lib/netstandard2.1/ClosedXML.dll` of the two packages of the configured
`build_path` run (lab `out/closedxml-0.104.2/configured-build_path-store/`,
`control/` and `experiment-1/`; the data folder has their file lists;
the run is repeated by `build-and-compare.py build-twice population.tsv
ClosedXML <lab> configured build_path`):
`/tmp/reprotest.xZteBb/const_build_path/ClosedXML/obj/Release/netstandard2.1/ClosedXML.pdb`
against `.../build-experiment-1/...`, and the same for netstandard2.0.
`cmp -l` counts 69 differing bytes in each of the two DLLs. A repaired
package, Bogus, says `/_/Source/Bogus/obj/Release/netstandard2.0/Bogus.pdb`.

Candidate causes `[I]`, not isolated. The repository at the commit:

- runs Fody 6.3.0 with Janitor.Fody (`ClosedXML/ClosedXML.csproj` lines
  37 and 41), which rewrites the compiled DLL through Mono.Cecil; a
  rewrite that writes the debug directory again from the PDB's real file
  path would undo the compiler's PathMap. Its own `Directory.Build.props`
  (lines 31 to 34) blames Fody for a DLL/PDB checksum mismatch;
- pins `Microsoft.SourceLink.GitHub` 1.1.1 (`ClosedXML.csproj` line 42)
  over the SDK's own Source Link;
- declares `SourceRoot` as a property (`Directory.Build.props` line 4,
  `$(MSBuildThisFileDirectory)`), where the SDK derives PathMap from
  `SourceRoot` items.

Its own CI sets `ContinuousIntegrationBuild` only under AppVeyor
(`Directory.Build.props` lines 49 to 51). Which of the three defeats
the mapping needs one build with each removed; not done.

The 25 come from seven repositories (Azure SDK, IdentityModel,
Swashbuckle, Stateless, msbuild, Quartz.NET, ClosedXML).

### Also measured

62 of the 127 default builds produce a package whose file name does not
carry the release's version `[V]` (`nupkgs` in `out/*/state.json`
against `recipe.version`): `1.0.0` defaults (Hangfire, Humanizer,
CsvHelper, YamlDotNet, FluentModbus, ...), Arcade's `-dev` (EF Core,
Roslyn, DiaSymReader), `-rc.32767` (NuGet.*), `-alpha.<date>` (Azure),
the clock (IdentityModel), `-g<commit>` (SolutionPersistence,
Mono.TextTemplating), `4.9999.9999` (FeatureManagement), and three whose
version at the commit is an older release's (Identity.Client 4.84.2
builds as 4.61.0, Newtonsoft.Json 13.0.4 as 11.0.1-beta2,
Workstation.UaClient 3.2.3 as 3.2.2). `[I]` The version is an input of
the publisher's CI, not of the repository at the commit; 44 of 90 on 1
November, 62 of 127 now.

`global.json` `[V]` (`categories.tsv` column `global_json`): the SDK pin
removed for 80 of the 127, no `global.json` for 46, DiaSymReader's pin
kept.

## Driver faults, all fixed and the affected rows run again

Recorded in `kommando.txt`:

- The night run (2 November 17:43 to 3 November 00:00, four slices)
  ran with `/tmp` 98 % full: 29 GB of clones left in a scratch
  directory by the population check at 11:40 the same day. reprotest
  builds under `/tmp`, so 442 runs (64 packages) and 11 screens failed
  with "No space left on device" or its symptoms (`reprotest exit 125`,
  CS1569, CS0041, CS8104, MSB3491). Found at 00:05; the scratch deleted,
  the failed runs removed from the state files (their logs kept as
  `*.nospace.log`), the 11 screens moved to `retired/*-nospace`, and the
  75 packages run again from 00:12 (`rerun-1..4.tsv`). The removal also
  took the 6 failed Swashbuckle runs of 1 November (Node under
  faketime): the 4 `time` runs were redone and failed the same way, the
  2 all-at-once runs were not.
- The rerun finished 06:49 with 38 runs in 13 packages (six from the
  Azure SDK, two from Roslyn, five from EF Core, Data.Sqlite among
  them) failed in reprotest's testbed again (exit 125: no space left, a
  broken pipe to the testbed, a copydown timeout): four parallel
  reprotest copies of these trees do not fit the 31 GB tmpfs. Removed again (`*.nospace2.log`) and run a
  third time from 06:51 with `TMPDIR=<lab>/tmp` (reprotest honours it;
  the build copies went to the disk), `rerun2-1..4.tsv`; finished 08:49.
- Two of those failed once more: Azure.Core configured `environment` on
  a copydown timeout (`*.nospace3.log`), and Azure.Security.KeyVault.Certificates
  configured `umask`, removed from the state after its worker had
  passed it. Both ran alone from 07:58 (`rerun3.tsv`), done 08:04.
- 8 state directories from the 1 November lab whose package is not in
  `population.tsv` (dotnet-ef, the two runtime packs, SkiaSharp and
  HarfBuzz) were moved to `retired/` before `results` was run, so the
  tables count the 224 rows and nothing else.

## Caveats and not tested

- Those of 1 November that still apply: one machine, one Linux, one SDK;
  one control per axis and one build per variation; restore online once
  per package, no network namespace; `time` at one offset; the Node
  under faketime failure as a property of the tool; the candidate fixes
  as diagnoses.
- The inference caveat of 1 November is closed: every configured axis
  is measured.
- Selection: the 127 are the part of Phoenix's shipped packages with a
  project-level build under one Linux SDK (224 rows, 97 did not build).
  Packages from one repository are not independent observations (68
  repositories; the 25 come from seven).
- The ClosedXML cause is the least certain diagnosis in the table.
- Nothing from the full-disk night is in a `same` or `differs` verdict:
  the comparison runs only after both builds have produced a package.
  A build that was slowed by the full disk but completed is a complete
  build.
- The all-at-once run exists for 85 of the 127 only; no reading rests
  on it.

## Closed

- The 1 November note's "proposed for decision": the six remaining
  configured axes for all packages are done (this run); repeated
  unvaried control pairs and one tested fix per cause remain not done,
  and are out of scope for 2a as it stands (decision 3 November).
- The 51 exclusions of 1 November: superseded; 47 built and failed,
  listed above, 4 out of the population.
- Workspaces.MSBuild with the right project: did not build (NETSDK1085);
  closed as a result.
- HarfBuzzSharp 8.3.1.1, built on 1 November: out of the population
  (dead repository URL today); its 1 November rows stay in that run's
  data.
- ClosedXML's cause: three candidates named, none isolated; closed as a
  diagnosis, like the other causes' fixes.
- The all-at-once run for the 39 new packages: not made; the per-axis
  runs answer every question it would.
