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

## Result

(after the run)

## Caveats

- The packages were chosen for having a compiler record and a commit, so
  the skip rate here says nothing about packages without them.
- The Linux builds run on `arch`, with `/usr/bin` on PATH; the Windows runs
  on the runner image of the day. Both are recorded per build.
