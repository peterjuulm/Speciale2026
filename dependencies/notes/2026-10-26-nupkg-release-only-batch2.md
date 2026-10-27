# Nupkg test, release-only method, batch 2: the third-party packages not tried before

Planning note, 26 October 2026, afternoon, written before the run. Follows
[the release-only note](2026-10-26-nupkg-release-only.md) of the same
morning, where the method was fixed and tried on five packages.

## Question

The same as this morning's: are the facts that come with a NuGet release,
plus the source at the declared commit and its standard .NET files, enough
to rebuild the DLL on nuget.org? Now on every ready third-party package in
Phoenix's dependency set that the pilot and the first run had not touched,
with the five from the first run added for the method's version 2.

## What runs

- The list: `recipes/release-only/batch-third-party.txt`, 59 packages: the
  54 third-party packages in census R and the symbol-server finds that have
  a compiler record and a source commit, less the five already tried, plus
  those five again. Microsoft's 139 packages are a later batch.
- The method of this morning, rules 1 to 8, with rule 8 at **version 2**:
  `dotnet build` then `dotnet pack --no-build`, so that a project with
  `GeneratePackageOnBuild` builds too. Nothing else changed. The five from
  the first run are in the list for that reason: the same method on all.
- `run-batch.py` drives it: `derive-batch.py` derives every recipe, the
  recipes are committed (the Windows runs read them from the repository),
  the Linux packages are built here on `arch` one after the other, the
  Windows ones on GitHub's `windows-2022` runner, one run each; then
  `level.py` reads the match level from `dllreport.cs` reports of
  nuget.org's DLL and ours, and `results.tsv` is written. `level.py` is new:
  it applies the four levels of the pilot note to the two reports, where
  before this the level was read by hand from the report diff.
- No tuning against nuget.org during the run. A script error (a crash, a
  wrong path, a wrong label) is fixed and the batch rerun; a package that
  the method fails on stays failed.

## Expectation (written before the run)

`[I]` all of it.

1. A third to a half of the 59 are **skipped** by a rule: no PDB with a
   compiler record (rule 1) and no project whose assembly name is the DLL's
   (rule 7) are the likely ones; a few will miss an SDK (rule 3) because the
   package was built with a preview or a compiler no public SDK bundles.
2. Of the derived ones, more than half reach level 1 or 2. Level 2 means a
   signed package; signing is common among the larger projects.
3. The failures split in two: builds that fail (a project needing a
   solution-level build, a custom target, a tool the project restores, a
   package reference no longer on the feed), and level 4 from a version or
   branding property the release does not carry (rule 8's risk).
4. The five from the first run: RBush, FluentValidation and Serilog stay at
   level 1, Cronos at 2, and GuardClauses now builds and reaches level 1,
   if the build-then-pack sequence is what its CI does.
5. A equals A2 for every package that builds.

## Commands

See `dependencies/data/2026-10-26-nupkg-release-only-batch2/kommando.txt`.

## Run 1, stopped after 25 minutes (13:20)

The first run was stopped once its logs showed errors in the scripts, as
agreed: fix, then run the whole batch again. What it showed, and what
changed, before run 2 (the method's version 2 is now rules 1 to 8 with
these changes; nothing was changed to make a DLL match):

- 47 of 58 derived; 11 skipped by a rule, two of them (Newtonsoft.Json
  twice, ClosedXML) for a compiler that ran on .NET Framework 4.8, which
  `derive.py` crashed on at first and now records as a rule-3 skip.
- Bogus's informational version is `35.6.1 built on 2024-09-02 22:19:07Z`;
  rule 8 split it on the first hyphen and passed garbage to MSBuild
  (MSB1008). Rule 8 now passes version properties only for a semantic
  version; otherwise none, recorded as a default.
- ExCSS's `Directory.Build.targets` adds `$(NuGetPackageRoot)` as a
  SourceRoot, which must end in a separator; our `NUGET_PACKAGES` had none.
  `rebuild.py` adds it.
- Dapper, Humanizer.Core and Mono.TextTemplating use Nerdbank.GitVersioning,
  which reads the version height from the history and failed on the shallow
  clone; MediatR.Extensions.Microsoft.DependencyInjection uses MinVer, which
  found no tag and packed `0.0.0-alpha.0`. Rule 2 now clones the full
  history with tags. The depth was an implementation shortcut, not a fact
  read from the release.
- FluentModbus and Markdig record `/home/runner/work/...` as the build
  folder, a GitHub runner's, which this user cannot create on `arch`.
  Such Linux recipes now run on GitHub's `ubuntu-24.04` runner.
- Newtonsoft.Json is in the list twice (13.0.3 and 13.0.4, both shipped);
  the batch keeps one folder per package name, so the second is recorded as
  not derived. Both are rule-3 skips anyway.

Seen but **not** changed, since it is a method result and not a script
error: CsvHelper, Quartz (four packages) and Serilog.Settings.Configuration
reach level 4 with the same cause, the assembly and file versions
(`33.0.0.0` on nuget.org, `33.1.0.0` from us; `3.13.1` against `3.13.1.0`).
Both are attributes of the shipped DLL, so a version 3 of rule 8 could
pass `AssemblyVersion` and `FileVersion` as well. That is for a later run.
Hangfire (packages.config-era restore of RazorGenerator) and AutoMapper
(ApiCompat needs a binary the build script fetches) failed in ways the
method cannot cover. Run 1's text outputs are under `run1/` in the data
folder: `run1/windows-2022/runs.txt` lists the run ids.

## Result

Run 2, 13:27 to 13:41 on 26 October: 12 Linux builds on `arch` (one after
the other), 2 on `ubuntu-24.04`, 33 on `windows-2022`; the runner runs
finished in a few minutes each. `[V]` the table is `results.tsv` in the
data folder, every row backed by `derive/<package>/facts.txt` and
`<runner>/<package>/` (summary, build logs, the two reports, the recipe).

Of 58 packages, 47 derived (36 with every value read, 11 with a default),
11 skipped by a rule. Of the 47: 44 built, 3 failed; levels: 1 ×
13, 2 × 3, 3 × 5, 4 × 20; 3 built but packed under
another version and were not compared. A equals A2 for every build that
packed a package.

| Package | Category | Built on | Build | Level | A = A2 | What differs, or why not |
| --- | --- | --- | --- | --- | --- | --- |
| Ardalis.Specification 8.0.0 | derived | windows-2022 | ran | 3 | yes | same IL and metadata; MVID, timestamp and PDB identity differ |
| Ardalis.Specification.EntityFrameworkCore 8.0.0 | derived | windows-2022 | ran | 3 | yes | same IL and metadata; MVID, timestamp and PDB identity differ |
| AutoMapper 13.0.1 | derived | windows-2022 | ran | 3 | yes | builds now (ApiCompat failed in run 1 on a shallow clone) |
| Bogus 35.6.1 | with defaults (os, version) | arch | ran | 4 | yes | nuget.org's DLL is strong-name signed (cor flags StrongNameSigned); the key is not in the repository |
| CsvHelper 33.1.0 | derived | windows-2022 | ran | 4 | yes | AssemblyVersion 33.0.0.0 and FileVersion 33.1.0.26 on nuget.org; 33.1.0.0 from us |
| Dapper 2.0.123 | derived | windows-2022 | ran | - | - | built; packed as `Dapper.2.0.123-g2a837ad7d0` (Nerdbank.GitVersioning without PublicRelease), so `rebuild.py` found no package to compare |
| ExCSS 4.3.1 | derived | arch | ran | 4 | yes | GitVersion's informational version carries the branch name (`+Branch.release-4.3.1.Sha...`); ours carries the commit only |
| FluentModbus 5.3.2 | with defaults (checkout line endings) | ubuntu-24.04 | ran | 4 | yes | AssemblyVersion 5.0.0.0 and Company from the CI; 5.3.2.0 and the project name from us; IL differs too |
| FluentValidation.DependencyInjectionExtensions 11.11.0 | derived | arch | ran | 1 | yes |  |
| Google.Protobuf 3.21.9 | derived | windows-2022 | ran | 4 | yes | Authenticode-signed on nuget.org and the `#~` stream differs; the cause was not read |
| Hangfire.AspNetCore 1.8.25 | with defaults (version) | windows-2022 | **failed** | - | - | `Hangfire.Core`'s packages.config-era restore of RazorGenerator.MsBuild is missing (MSB4019) |
| Hangfire.InMemory 1.0.0 | with defaults (version) | windows-2022 | ran | 2 | yes | only the signature (Authenticode) and the PE checksum |
| Hangfire.NetCore 1.8.25 | with defaults (version) | windows-2022 | **failed** | - | - | as Hangfire.AspNetCore |
| Humanizer.Core 2.14.1 | derived | windows-2022 | ran | - | - | built; packed as `Humanizer.2.14.1-g3ebc38de58`, another id and a Nerdbank suffix; not compared |
| Markdig 1.2.0 | derived | ubuntu-24.04 | ran | 1 | yes |  |
| MediatR 12.4.1 | with defaults (build folder) | arch | ran | 3 | yes | same IL and metadata; MVID, timestamp and PDB identity differ |
| MediatR.Contracts 2.0.1 | derived | windows-2022 | ran | 4 | yes | AssemblyVersion 2.0.1.0, FileVersion, informational version and RepositoryUrl on nuget.org; 2.0.0.0 and none from us |
| MediatR.Extensions.Microsoft.DependencyInjection 11.1.0 | derived | windows-2022 | ran | 4 | yes | as SharpZipLib (.NET Standard 2.1) |
| Mono.TextTemplating 3.0.0 | with defaults (version) | windows-2022 | ran | - | - | built; packed as `Mono.TextTemplating.3.0.0-gcb559e2032`; not compared |
| NodaTime 3.2.0 | derived | windows-2022 | ran | 2 | yes | only the signature (Authenticode) and the PE checksum |
| Npgsql 10.0.3 | derived | arch | ran | 1 | yes |  |
| Npgsql.EntityFrameworkCore.PostgreSQL 10.0.3 | derived | arch | ran | 1 | yes |  |
| Quartz 3.13.1 | derived | windows-2022 | ran | 4 | yes | FileVersion 3.13.1 against 3.13.1.0 |
| Quartz.AspNetCore 3.13.1 | derived | windows-2022 | ran | 4 | yes | as Quartz |
| Quartz.Extensions.DependencyInjection 3.13.1 | derived | windows-2022 | ran | 4 | yes | as Quartz |
| Quartz.Extensions.Hosting 3.13.1 | derived | windows-2022 | ran | 4 | yes | as Quartz |
| ScottPlot 5.1.57 | derived | windows-2022 | ran | 1 | yes |  |
| SendGrid 9.29.3 | derived | windows-2022 | ran | 3 | yes | same IL and metadata; MVID, timestamp and PDB identity differ |
| Serilog.Settings.Configuration 8.0.4 | derived | windows-2022 | ran | 4 | yes | version attributes, as CsvHelper |
| Serilog.Sinks.File 6.0.0 | derived | windows-2022 | ran | 1 | yes |  |
| Serilog.Sinks.Seq 9.0.0 | derived | windows-2022 | ran | 1 | yes |  |
| SharpZipLib 1.4.2 | derived | windows-2022 | ran | 4 | yes | TargetFrameworkAttribute has an empty FrameworkDisplayName on nuget.org, ".NET 6.0" from us: a different SDK or targeting pack with the same compiler; IL differs too |
| SixLabors.Fonts 1.0.0 | derived | arch | **failed** | - | - | the repository's `NuGet.config` lists feedz.io only; System.Memory and others are not there (NU1101) |
| Stateless 5.16.0 | derived | windows-2022 | ran | 4 | yes | the copyright year is the build year (2009-2024 against 2009-2026) |
| Swashbuckle.AspNetCore.Annotations 7.2.0 | derived | windows-2022 | ran | 4 | yes | FileVersion 7.2.0.956 against 7.2.0.0, and the copyright year is the build year (2024 against 2026) |
| Swashbuckle.AspNetCore.ReDoc 7.2.0 | derived | windows-2022 | ran | 4 | yes | as Annotations |
| Swashbuckle.AspNetCore.Swagger 7.2.0 | derived | windows-2022 | ran | 4 | yes | as Annotations |
| Swashbuckle.AspNetCore.SwaggerGen 7.2.0 | derived | windows-2022 | ran | 4 | yes | as Annotations |
| Swashbuckle.AspNetCore.SwaggerUI 7.2.0 | derived | windows-2022 | ran | 4 | yes | as Annotations |
| TimeZoneConverter 7.0.0 | derived | arch | ran | 1 | yes |  |
| UnitsNet 6.0.0-pre012 | derived | windows-2022 | ran | 1 | yes |  |
| YamlDotNet 16.2.1 | derived | windows-2022 | ran (second run) | 4 | yes | AssemblyVersion 16.0.0.0, FileVersion and informational version on nuget.org; 0.0.0.0 and none from us. The first run failed on nuget.org itself (NETStandard.Library 2.0.3: "multiple attempts to download the nupkg have failed") and was dispatched once more, 40324799374 |
| RBush 4.0.0 | derived | arch | ran | 1 | yes |  |
| FluentValidation 11.11.0 | derived | arch | ran | 1 | yes |  |
| Serilog 4.2.0 | derived | windows-2022 | ran | 1 | yes |  |
| Ardalis.GuardClauses 5.0.0 | derived | windows-2022 | ran | 1 | yes |  |
| Cronos 0.9.0 | with defaults (version) | windows-2022 | ran | 2 | yes | only the signature (Authenticode) and the PE checksum |

Skipped by a rule:

- ClosedXML 0.104.2: skipped (sdk: the compiler ran on .NET Framework 4.8.4110.0 (Visual Studio or msbuild.exe); no dotnet SDK bundles it)
- Newtonsoft.Json 13.0.4: not derived: Newtonsoft.Json is already in the list with another version
- Portable.BouncyCastle 1.9.0: skipped (sdk: no public SDK with runtime 6.0.0 has csc 4.0.0-5.21501.19+8e1779e16298415843e85029d8b52a1ae9bb4c30 (tried 6.0.100))
- ShimSkiaSharp 5.1.1: skipped (sdk: no public SDK with runtime 10.0.9 has csc 5.6.0-2.26230.102+caa81fa4971f74880cdab61990cb1b11420939ec (tried 10.0.109, 10.0.301))
- SixLabors.ImageSharp 1.0.4: skipped (project: 0 .csproj with assembly name SixLabors.ImageSharp: [])
- Svg.Animation 5.1.1: skipped (sdk: no public SDK with runtime 10.0.9 has csc 5.6.0-2.26230.102+caa81fa4971f74880cdab61990cb1b11420939ec (tried 10.0.109, 10.0.301))
- Svg.Custom 5.1.1: skipped (sdk: no public SDK with runtime 10.0.9 has csc 5.6.0-2.26230.102+caa81fa4971f74880cdab61990cb1b11420939ec (tried 10.0.109, 10.0.301))
- Svg.Model 5.1.1: skipped (sdk: no public SDK with runtime 10.0.9 has csc 5.6.0-2.26230.102+caa81fa4971f74880cdab61990cb1b11420939ec (tried 10.0.109, 10.0.301))
- Svg.SceneGraph 5.1.1: skipped (sdk: no public SDK with runtime 10.0.9 has csc 5.6.0-2.26230.102+caa81fa4971f74880cdab61990cb1b11420939ec (tried 10.0.109, 10.0.301))
- Svg.Skia 5.1.1: skipped (sdk: no public SDK with runtime 10.0.9 has csc 5.6.0-2.26230.102+caa81fa4971f74880cdab61990cb1b11420939ec (tried 10.0.109, 10.0.301))
- System.Reactive 5.0.0: skipped (sdk: the compiler ran on .NET Framework 4.8.3928.0 (Visual Studio or msbuild.exe); no dotnet SDK bundles it)

Three runs (Google.Protobuf, Stateless, YamlDotNet) the script could not
find by id, since a queued run shows the workflow's name and not its
run-name; they were downloaded and classified by hand with the same
functions (`run.log` says so), and `run-batch.py` now looks again while
waiting.

## Interpretation

Against the expectation:

1. Fewer skipped than expected: 11 of 58, not a third. Rule 3 took 9 of
   them (three compiled on .NET Framework, six on a compiler no public SDK
   bundles: ShimSkiaSharp and the Svg packages on a preview, BouncyCastle
   on a 2021 preview), rule 7 one (ImageSharp: no `.csproj` carries its
   assembly name), one a duplicate in the list. Rule 1 skipped none: every
   package here had a PDB with a compiler record, by selection.
2. Level 1 or 2 for 16 of 47 derived (13 + 3), a third, not "more than
   half". Level 3 for 5: same code, only the debug identity differs, which
   the PDB diff will explain (not read in this note). Level 4 for 20.
3. The failures split as expected, but not evenly: only 3 builds failed,
   and 20 reached level 4. Of those 20, 15 differ in version or branding
   attributes that the release does carry (AssemblyVersion, FileVersion,
   the informational version's metadata) or in a value computed at build
   time (the copyright year in Swashbuckle and Stateless, from the build
   date), 2 in the FrameworkDisplayName (a different SDK or targeting pack
   with the same compiler, so rule 3's "lowest SDK" chose wrong, or the
   release was built outside a dotnet SDK), 1 in a strong-name signature
   (Bogus), 1 in GitVersion's branch name (ExCSS), 1 unread (Protobuf).
   So rule 8's risk (the version properties) is the main cause, and it
   points to a version 3: pass `AssemblyVersion` and `FileVersion` from
   the DLL's own attributes too. The copyright year and the branch name
   are not in the release in a usable form.
4. The five from the first run: RBush, FluentValidation, Serilog level 1,
   Cronos level 2 as before; GuardClauses builds under rule 8 version 2
   and reaches level 1. The expectation held.
5. A equals A2 for all 44 builds that packed. Held.

What the batch says about the method: the facts in a release are enough
for a third of these packages to the byte, and for most of the rest the
distance is one or two property values that the release also carries but
the rules do not yet pass. Three version tools (Nerdbank.GitVersioning,
MinVer, GitVersion) and one build-time value (the year) are the cases
where the project's own version logic, not the release, decides.

## Caveats

- The packages were chosen for having a compiler record and a commit, so
  the skip rate here says nothing about packages without them.
- The method changed between run 1 and run 2 (rule 2: full clone; rule 8:
  SemVer only; the NuGet cache separator). Run 1's numbers are not
  comparable and are kept only as the record of what was fixed.
- The levels are read by `level.py` from the DLL's report lines; the PDB
  is compared by the package comparison only (`compare-snupkg.txt`), and
  level 3's cause is not read in this note.
- Humanizer.Core's project packs as `Humanizer`; the census name and the
  package id differ, which `rebuild.py` does not map.
- Google.Protobuf's level-4 cause was not read.
- Three runs were classified by hand after the batch, with the same code.
- The Linux builds run on `arch`, with `/usr/bin` on PATH; the Windows runs
  on the runner image of the day. Both are recorded per build.

## Corrections, 27 October

- "A equals A2 for every build that packed a package" and "A equals A2 for
  all 44 builds that packed" (Result, Interpretation 5) overstate by
  three. `results.tsv` has 44 builds that ran and 41 with `a_eq_a2 = yes`;
  Dapper, Humanizer.Core and Mono.TextTemplating built but packed under
  another version or id, so `rebuild.py` found no `<id>.<version>.nupkg`
  and compared nothing, DLLs included. Correct statement: **A = A2 for 41
  of the 41 compared; 3 builds not compared.** The expectation above is
  left as written.
- The batch keyed derivations, recipes and result rows by package name;
  a package listed in two versions would have lost one. Here only
  Newtonsoft.Json was, both versions rule-3 skips. From 27 October the
  scripts key by name and version (`check-batch.py` verifies it).

Labs under `/private/tmp` (`nupkg-pilot`, `nupkg-release-only`, `nupkg-batch2`, `nupkg-batch3`) were removed on 27 October 2026 to free 60 GB; every text output named in this note is in the data folder.
