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
| 8 | Command | `dotnet pack <project> -c Release`, with `ContinuousIntegrationBuild=true` when the PDB's paths are mapped (**inferred**), `VersionPrefix` and `VersionSuffix` from the DLL's informational version (**inferred**; a project that sets `Version` itself, or MinVer, keeps its own), `PackageVersion` from the `.nuspec`; NuGet's audit off | No informational version: no version properties, **default** |

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

To be filled in from the runs. Derivation on `arch`:

    E=dependencies/experiments/nupkg; C=dependencies/data/2026-10-13-dependency-census/mac/census.files.csv; L=/private/tmp/nupkg-release-only
    python3 -I $E/derive.py <Package> <Version> $C $L $L/derive/<Package>

Then the derived `recipe.toml` goes to `$E/recipes/release-only/`, and:

    python3 -I $E/rebuild.py $E/recipes/release-only/<package>.toml $L/build/<package>      # Linux, on arch
    gh workflow run nupkg-rebuild.yml -R peterjuulm/Speciale2026 -f recipe=release-only/<package>.toml -f runner=windows-2022

Round B, on `arch`, for each package that built on Linux:

    python3 -I $E/reprotest-run.py $E/recipes/release-only/<package>.toml $L/reprotest/<package>

## Result

## Interpretation

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
