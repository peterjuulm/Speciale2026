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

(after run 2)

## Caveats

- The packages were chosen for having a compiler record and a commit, so
  the skip rate here says nothing about packages without them.
- The Linux builds run on `arch`, with `/usr/bin` on PATH; the Windows runs
  on the runner image of the day. Both are recorded per build.
