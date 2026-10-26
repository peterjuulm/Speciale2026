# Nupkg test: the release-only method

Planning note, 26 October 2026, before any run. Follows the
[pilot](2026-10-21-nupkg-pilot-serilog-runners.md) of 21 October, where
five packages were rebuilt with recipes read from their CI files, and the
[short plan](2026-10-21-nupkg-test-plan.md). Phoenix commit `79cb67a7`.

## Question

The pilot showed that nuget.org's bytes can be reached, but each recipe used
facts from the package's CI pipeline: the build script, its variables, the
runner. A consumer of a package does not have that. The question becomes:

**Are the build facts that come with a NuGet release, plus the source at the
declared commit and its standard .NET project files, enough to rebuild the
DLL that is on nuget.org?**

CI files and build scripts are not inputs. They may explain a failure
afterwards, in a separate section. A failure means "not reproduced by this
method", never "not reproducible".

## Allowed inputs

- The `.nupkg` from nuget.org: its `.nuspec`, the shipped DLL's attributes,
  its PDB (from the package, the `.snupkg`, or the NuGet symbol server).
- The source at the declared commit, cloned from GitHub.
- The repository's standard .NET files, read by MSBuild as usual: `.csproj`
  and what it imports, `Directory.Build.*`, `global.json`, lock files,
  `NuGet.Config`.
- Our census list of which file each package ships (`census.files.csv`).

## The rules

One procedure for every package, `dependencies/experiments/nupkg/derive.py`.
Each value gets a mark: **read** (and from where), **inferred** (a rule
turned an observation into a choice), or **default** (and why).

| # | Value | Rule | If not available |
| --- | --- | --- | --- |
| 1 | Package, PDB | `.nupkg` from nuget.org; PDB from the package, else the `.snupkg`, else the symbol server by the DLL's CodeView key | No PDB with a compiler record: **skipped** |
| 2 | Source | The `.nuspec`'s commit. Clone URL from the PDB's Source Link. A branch or tag only if the `.nuspec` names one; else the bare commit, depth 1 | No commit: skipped. No Source Link: the `.nuspec` URL, **default** |
| 3 | SDK | Among the public SDKs that bundle the PDB's runtime version, the lowest whose `csc.dll` has the PDB's compiler version; installed and read. Several SDKs can share a compiler; taking the lowest is **inferred**, and the ones not read are listed | No such SDK: **skipped** |
| 4 | OS | Windows when the PDB's embedded SDK-generated files have CRLF, else Linux (**inferred**: macOS would look like Linux). Windows builds run on GitHub's `windows-2022` runner, Linux ones on `arch` | No generated file embedded: Linux, **default** |
| 5 | Build folder, NuGet cache | From the PDB's absolute document paths: a path minus the tracked file it ends with; the cache likewise. Mapped `/_/` paths: any folder | No path ends in a tracked file: any folder, **default** |
| 6 | Checkout line endings | As stored in git, or converted to CRLF (`core.autocrlf=true`), whichever reproduces the PDB's source checksums; set explicitly, since GitHub's Windows runners convert by default. Checksums that match no form are counted and reported | PDB has LF where git stores CRLF (git does not convert to LF at checkout), or nothing decides: as stored, **default** |
| 7 | Project | The one `.csproj` whose assembly name is the DLL's | None or several: **skipped** |
| 8 | Command | `dotnet pack <project> -c Release`, with `ContinuousIntegrationBuild=true` when the PDB's paths are mapped (**inferred**), `VersionPrefix` and `VersionSuffix` from the DLL's informational version (**inferred**; a project that sets `Version` itself, or MinVer, keeps its own), `PackageVersion` from the `.nuspec`; NuGet's audit off. **Version 2** (afternoon of 26/10, after GuardClauses): `dotnet build <project> -c Release` with the same properties, then `dotnet pack <project> -c Release --no-build`; batch 2 runs under it | No informational version: no version properties, **default** |

Then `rebuild.py` builds A, and A2 in exactly A's paths again with
everything deleted first, so that A against A2 measures repeatability with
nothing varied. Varied builds (the folder, time, locale and the rest) are
left to the reprotest test, a later step, so that it is done once and
completely, as Benedetti et al. and the Phoenix runs did it (decided 26/10).
`rebuild.py` records the runner image and the resolved dependencies
(`project.assets.json`). Each package ends in exactly one category:

- **derived**: every value read; **derived with defaults**: which ones;
  **skipped**: which rule.
- For derived packages: the match level of the shipped DLL against
  nuget.org (1 identical; 2 identical without signatures; 3 same code; 4
  different; did not build, with the step), and whether A equals A2.

Nothing is tuned after a run. A recipe that fails stays a failure in the
main result; what CI would have added goes in a follow-up section.

Reviewed before the run by a second model (26/10), which added: the
inferred mark; that `core.autocrlf=input` converts at commit only, so a
checkout cannot be converted to LF; a repeat in the same paths (A2) before
any varied build; the record of the runner image and dependencies; and the
caveats below on the five development cases and on project-level packing.

## Expectation (written before the runs)

`[I]` all of it. Against the pilot's CI-informed results (four at level 1,
Cronos at 2):

1. All five derive without skipping. Cronos derives with one default (no
   version properties, since the DLL has no informational version).
2. RBush, Serilog, GuardClauses and FluentValidation reach level 1 again;
   Cronos reaches level 2. The release carries every fact the pilot had to
   take from CI, except the build command, which the fixed `dotnet pack`
   replaces.
3. The one risk is the version rule (8): a global `VersionPrefix` could
   collide with MinVer (RBush) or a project's own `<Version>`
   (GuardClauses). If it does, the DLL differs in its version attributes
   and level 4 follows, with the cause visible in the report diff.
4. A equals A2 for all five.

## Round B: the reprotest test

After round A, on the packages that built on Linux, with the same recipes:
`reprotest-run.py RECIPE WORKDIR`. It installs the SDK alone, clones as
round A did, fills the package cache with one restore, then runs reprotest
once per axis with the same `dotnet pack` command, `--vary=-all,+AXIS`:
`build_path` (the folder, which Benedetti et al. left out), then their eight,
`environment`, `kernel`, `locales`, `exec_path`, `time`, `timezone`,
`umask`, `fileordering`. The artefact is the `lib/` folder taken out of the
`.nupkg` (every DLL and PDB), not the `.nupkg`, whose core-properties file
gets a new id at every pack. Every build starts with `dotnet build-server
shutdown` (W27). `fileordering` needs `disorderfs`, which `arch` lacks; it
is recorded as not run unless the run moves to the VM.

Result per package: which axes are reproducible; per axis: how many packages
fail. That table is the one comparable with Benedetti et al.'s Figure 4.
Windows-built packages are not covered and are listed as such.

Expectation (from the plan, `[I]`): reproducible on every axis wherever
round A reached level 1, except `build_path` for packages without
`ContinuousIntegrationBuild`, and `locales` for packages compiled with
Roslyn 4.12 under `et_EE` (W26; RBush and FluentValidation use 4.11 and
4.8, so not these two).

## Commands

Verbatim in `dependencies/data/2026-10-26-nupkg-release-only/kommando.txt`,
with the run ids and the commits. The scripts ran at `f1284ad`; the
workflow needed one fix for a slash in the artifact name (`8add058`), and
rule 6's implementation one fix after Cronos's first run (`699539b`, below).
Run on 26/10 12:25-12:35 at Leo's request, while Leo and Peter were at
lunch. Derivation on `arch`:

    E=dependencies/experiments/nupkg; C=dependencies/data/2026-10-13-dependency-census/mac/census.files.csv; L=/private/tmp/nupkg-release-only
    python3 -I $E/derive.py <Package> <Version> $C $L $L/derive/<Package>

Then the derived `recipe.toml` goes to `$E/recipes/release-only/`, and:

    python3 -I $E/rebuild.py $E/recipes/release-only/<package>.toml $L/build/<package>      # Linux, on arch
    gh workflow run nupkg-rebuild.yml -R peterjuulm/Speciale2026 -f recipe=release-only/<package>.toml -f runner=windows-2022

Round B, on `arch`, for each package that built on Linux:

    python3 -I $E/reprotest-run.py $E/recipes/release-only/<package>.toml $L/reprotest/<package>

## Result

### Round A

Step 1, the derivation, 12:25 `[V]` (`arch/derive/<Package>/facts.txt`):
all five derived, none skipped. Cronos with one default: its DLL has no
informational version, so no version properties were passed. Inferred
values: the SDK (4 of 5; FluentValidation's runtime 8.0.0 has only one
SDK), the OS (all), `ContinuousIntegrationBuild` (3), the version
properties (4). The SDKs: RBush 8.0.404, FluentValidation 8.0.100, Serilog
9.0.101, GuardClauses 8.0.400, Cronos 9.0.100, each verified in its
`csc.dll`; the same five the pilot had taken from CI and the compiler
record.

Steps 3 and 4 `[V]` (`summary.txt` and the report diffs in each run's
folder):

| Package | Category | Built on | Shipped DLL against nuget.org | A = A2 |
| --- | --- | --- | --- | --- |
| RBush 4.0.0 | derived | `arch` | level 1 | yes |
| FluentValidation 11.11.0 | derived | `arch` | level 1 | yes |
| Serilog 4.2.0 | derived | windows-2022 | level 1, DLL and PDB | yes |
| Ardalis.GuardClauses 5.0.0 | derived | windows-2022 | **did not build**: `dotnet pack` packed nothing | (no build) |
| Cronos 0.9.0 | derived with defaults | windows-2022 | run 1: level 3; run 2: level 2 | yes |

- **GuardClauses.** `dotnet pack` restored and then failed with NU5026, the
  DLL to pack "was not found on disk": no compile ran. The project sets
  `GeneratePackageOnBuild=true`, and with that property `dotnet pack` skips
  the build, since a build would pack by itself. Its CI runs `dotnet build`
  (which packs) and then `dotnet pack --no-build`. The fixed command of
  rule 8 cannot build such a project. Recorded as "did not build"; a
  changed rule 8 is a new version of the method, not a rerun.
- **Cronos, run 1.** Level 3 (written as 4 at first; `level.py`, written
  in the afternoon, applies the definition: the IL and the metadata streams
  are equal, the MVID, PDB checksum and `#GUID` are not). Every source
  checksum in the PDB differed: the checkout had CRLF although the recipe
  set `core.autocrlf=false`. The repository's `.gitattributes` says
  `* text=auto`, and for such files git writes `core.eol`, which is the
  platform's ending by default, CRLF on Windows. The derivation's own clone
  on Linux had LF, so rule 6 as written ("as stored") was right and its
  implementation was not. `699539b` pins `core.eol=lf` as well; the Cronos
  recipe was re-derived, identical apart from that line
  (`arch/derive-run2/Cronos/facts.txt`).
- **Cronos, run 2.** Level 2: only the Authenticode signature and the PE
  checksum differ. The unsigned DLL hashes to `adc6e8d7…`, the same bytes
  as the pilot's CI-informed build and as Peter's stripped copy of
  nuget.org's DLL.
- On Windows the runner image was `windows-2022`, version in each build
  log (`runner ImageVersion=…`).

Expectation 1 **held**. Expectation 2 **held for four**: RBush, Serilog and
FluentValidation at level 1, Cronos at 2 (after the rule-6 fix); **failed**
for GuardClauses, which did not build. Expectation 3 did not happen: the
version rule collided with nothing; RBush's MinVer and FluentValidation's
`VersionPrefix` gave the published values. Expectation 4 **held** for the
four that built.

### Round B

RBush 12:27-12:34 and FluentValidation 12:34-12:39 on `arch`, the Windows
three not covered `[V]` (`arch/reprotest/<package>/summary.txt`, one log
per axis):

| Axis | RBush 4.0.0 | FluentValidation 11.11.0 |
| --- | --- | --- |
| build_path | reproducible | reproducible |
| environment | reproducible | reproducible |
| kernel | reproducible | reproducible |
| locales | **build failed** | reproducible (see caveats) |
| exec_path | reproducible | reproducible |
| time | reproducible | reproducible |
| timezone | reproducible | reproducible |
| umask | reproducible | reproducible |
| fileordering | not run | not run |

- **RBush, locales.** `et_EE.UTF-8` is not installed on `arch`, so every
  shell under the varied build prints `setlocale: LC_ALL: cannot change
  locale`. MinVer reads the version from the output of the `git` commands
  it runs, and the warning landed in it: `CS7035`, a version string that
  begins with the warning text. A build failure, not a difference in the
  artefact; the axis is untested for RBush until the locale is installed.
- **fileordering** needs `disorderfs`, which `arch` does not have; both
  runs recorded it as not run.
- **time** hung on RBush's first attempt: the compiler server that the
  build started outlived it, and the `faketime` wrapper waits for every
  process it started. The server was stopped by hand (12:33), the axis then
  compared and passed. The wrapper now shuts the build servers down at the
  end of every build as well; FluentValidation ran with that version.

Round B's expectation **held** where it could be tested: 7 of 9 axes for
RBush and 8 of 9 for FluentValidation reproducible, `build_path` included,
as both set `ContinuousIntegrationBuild`; no axis found a difference.

## Interpretation

For four of the five packages, what the release publishes was enough: the
compiler record named the SDK, the embedded generated files named the OS,
the document paths named the build folder and the checkout's line endings,
and Source Link named the clone URL. The one fact the release does not
carry, the build command, the fixed `dotnet pack` replaced for those four.
The pilot's CI-informed recipes gave the same bytes, so for these four the
CI files added nothing the release did not have.

The fifth, GuardClauses, failed on exactly that gap. A single fixed command
cannot fit every project: `GeneratePackageOnBuild` turns `dotnet pack`
into a no-op build. The failure is a limit of the method's rule 8, and it
says nothing about whether the package is reproducible; the pilot showed it
is, with `dotnet build` followed by `dotnet pack --no-build`, which is also
what a next version of rule 8 could use for every package.

The rule-6 fix is the kind of correction the method allows: the rule was
"as stored", the first implementation did not achieve it on Windows, and
the derivation data shows the intended value. It is not a value changed
to fit nuget.org.

Round B adds, for the two Linux packages, that the build is deterministic
under every condition reprotest could vary here, the folder included. That
is Benedetti et al.'s measure, and with it their expectation from the plan
held: a package that matches nuget.org was built deterministically once,
and here it stays so under variation.

## Caveats

- The derivation was run once on 26/10 while the script was written, to
  test it, and `rebuild.py` and `reprotest-run.py` (two axes, RBush) once
  each for the same reason; those runs are not the experiment. The recorded
  runs are below.
- The five packages are development cases: their CI-informed recipes were
  known when the rules were written, so a success here does not validate
  the method. Packages not seen before must follow, with the rules frozen
  as they are in this note.
- Rule 7 reads `AssemblyName` from the `.csproj` text, not through MSBuild
  evaluation; an imported or conditional assembly name is missed, and the
  package is then skipped.
- Rule 8 packs one project. A solution-level build can generate inputs that
  a project build omits; such a failure is a limit of the method, not
  evidence against the package.
- Rule 3 stops at the lowest SDK with the compiler; SDKs above it with the
  same compiler are listed, not tried.
- Round B's `locales` axis sets `LC_ALL=et_EE.UTF-8`, which `arch` lacks.
  glibc then falls back to C, and FluentValidation's "reproducible" on that
  axis says less than it seems: whether .NET, which reads the culture
  through ICU, still saw Estonian is not checked. W26 (Roslyn 4.12 orders
  generated types by culture) does not concern these two, built with Roslyn
  4.11 and 4.8.
- Round B used the lab's warm package cache (one restore before the runs),
  so the network was not varied.
- The wrapper's first version classified RBush's failed `locales` build as
  "not run"; the summary file carries the correction, the logs are as
  written.
