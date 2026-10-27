# Nupkg test, release-only method: batch 2 again under version 3

Planning note, 27 October 2026, 13:05, written before the run. The same
59 third-party packages as [batch 2](2026-10-26-nupkg-release-only-batch2.md)
(method version 2, 26 October), now under method version 3 as defined in
[the batch-3 note](2026-10-27-nupkg-release-only-batch3-microsoft.md).
Nothing else changes: same list, same runners, same scripts as batch 3.

## Question

What did version 3 buy? Batch 2 is the version-2 baseline; this run is the
version-3 measurement of the same packages. The difference per package
(skipped to derived, level 4 to 1 or 2, or nothing) is the value of the
four rule changes, read off the two `results.tsv`.

## Expectation (written before the run)

`[I]` all of it.

1. Derived: 50 to 55 of 59 (47 before). Rule 3's wider candidates reach
   the preview compilers of ShimSkiaSharp and the Svg packages (SDK
   10.0.300 has csc `5.6.0-2.26230.102`); the three .NET Framework
   compilers and ImageSharp (no project) stay skipped.
2. Of the 15 level-4 packages that differed only in version attributes,
   7 to 9 move to level 1 or 2: CsvHelper, the four Quartz packages,
   Serilog.Settings.Configuration, MediatR.Contracts, YamlDotNet. The
   five Swashbuckle packages and Stateless stay at level 4: the copyright
   year is the build year, which rule 8 does not touch. FluentModbus stays
   (a Company attribute from its CI).
3. Everything that was level 1, 2 or 3 stays where it was: the new
   properties repeat what those builds already produced.
4. The three Nerdbank packages still pack under another version; the
   three build failures (Hangfire ×2, SixLabors.Fonts) stay.
5. A equals A2 for every build that packs.

## Commands

See `dependencies/data/2026-10-27-nupkg-release-only-batch2-v3/kommando.txt`.

## Result

Run 27 October 13:05 to 13:55 on arch (16 Linux builds), GitHub
windows-2022 (36) and ubuntu-24.04 (2). Two local builds lost the network
(Bogus: DNS; SixLabors.Fonts: SDK download) and were run again by hand at
13:57 (`run.log` has both). Numbers `[V]` from the two `results.tsv`.

Derived: 54 of 59 (47 under version 2). The five skips: ClosedXML,
Newtonsoft.Json 13.0.3 and 13.0.4, System.Reactive (all .NET Framework
compilers, rule 3) and SixLabors.ImageSharp (no project, rule 7).

| state (publisher match) | version 2 | version 3 |
|---|---|---|
| level 1 | 13 | 14 |
| level 2 | 3 | 3 |
| level 3 | 5 | 9 |
| level 4 | 20 | 16 |
| built, nothing to compare | 3 | 4 |
| did not build | 3 | 8 |
| skipped in derivation | 11 (12 rows) | 5 |

A equals A2 for all 41 builds that packed a package, as under version 2.

Per package, 13 rows moved and 46 stayed:

| package | version 2 | version 3 | why |
|---|---|---|---|
| CsvHelper 33.1.0 | 4 | 1 | rule 8: the assembly version was the only difference |
| Quartz ×4 (3.13.1) | 4 | 3 | rule 8 removed the version difference; what is left is MVID, timestamp and the PDB id, so the strong-name signature differs too |
| ShimSkiaSharp 5.1.1 | skipped | 4 | rule 3 now reaches the preview SDK (10.0.300); builds, metadata differs |
| Svg.Animation, Svg.Custom, Svg.Model, Svg.SceneGraph, Svg.Skia 5.1.1 | skipped | did not build | derived now, but `src/Svg.Custom` fails with CS0246 (`SvgAttributeAttribute` not found): the project pulls in sources from a sibling that the release-only checkout builds differently |
| Portable.BouncyCastle 1.9.0 | skipped | built, nothing to compare | derives now (rule 7 tie-break), builds, but packs no nupkg |
| Newtonsoft.Json 13.0.3 | no row | skipped | duplicate list entry now gets its own row (name-version keys) |

The 11 packages that stayed at level 4, and what still differs
(`[V]` from the two dllreport files under `level/`):

| package | what differs |
|---|---|
| Swashbuckle ×5, Stateless | copyright year is the build year (2024 against 2026) |
| Bogus 35.6.1 | assembly version 0.0.0.0 and no strong name in our build: the project has `GenerateAssemblyInfo=false`, `Version 0.0.0-localbuild` and `SignAssembly=false`; the real values come from the CI build script, so the `-p:` properties of rule 8 have nothing to override |
| YamlDotNet 16.2.1 | same shape: `GenerateAssemblyInfo=false`, attributes written by the build script; also IL differs |
| MediatR.Contracts 2.0.1 | informational version 2.0.0 against 2.0.1 (MinVer computes it from git tags) and `RepositoryUrl` without `.git` |
| Serilog.Settings.Configuration 8.0.4 | only `RepositoryUrl`: `.git` suffix on nuget.org, none in ours (Source Link takes it from the clone's remote URL) |
| ExCSS, Google.Protobuf, FluentModbus, SharpZipLib, MediatR.Extensions.DI | unchanged from version 2 (see the batch-2 note) |

Against the expectation:

1. Derived 54: within the 50 to 55 guessed. Held.
2. Guessed 7 to 9 moves to level 1 or 2; got 1 (CsvHelper). The four
   Quartz packages moved, but to level 3, not 1 or 2. Serilog.Settings
   .Configuration, MediatR.Contracts and YamlDotNet did not move. Did not
   hold; the reasons are in the table above.
3. No level 1, 2 or 3 package moved. Held.
4. Dapper, Humanizer.Core and Mono.TextTemplating still pack under another
   version; Hangfire ×2 and SixLabors.Fonts still fail (Fonts now on
   NU1101 from its feedz-only `NuGet.config`, the same cause as under
   version 2). Held.
5. A equals A2 for every build that packed. Held.

## Interpretation

`[I]`. Version 3 bought derivation (47 to 54) more than it bought match
levels. Rule 8 fixed exactly the cases where the version was a plain
MSBuild property (CsvHelper, Quartz). It cannot reach a version that a
CI script writes into a generated `AssemblyInfo.cs` (Bogus, YamlDotNet)
or that a tool computes from git (MediatR.Contracts, MinVer). That is
the same boundary as in batch 3: the facts in the release name the
value, but the project does not take it as an input.

Quartz at level 3 is instructive: with the version fixed, the only
differences left are the ones a deterministic compiler writes from the
build's own identity (MVID, PDB id, timestamp), and because Quartz is
strong-named, the signature covers them. Level 3 is the ceiling for a
rebuild that is not byte-for-byte the publisher's PDB.

Two small, derivable causes are left for a version 4: the `.git` suffix
on `RepositoryUrl` (the .nuspec's repository URL says which form the
publisher used) and the explicit empty `VersionSuffix`. The build-year
copyright (Swashbuckle, Stateless) is not derivable from the release: it
needs a build date, and that is round B's question, not round A's.

## Caveats

- The list still names Newtonsoft.Json twice (13.0.3 and 13.0.4); with
  name-version keys both now get a row, both rule-3 skips.
- Two rows (Bogus, SixLabors.Fonts) are second runs after a network
  loss; the first attempts are in `run.log`. Bogus's second run built
  and compared; Fonts failed again on NU1101, which is the project's
  `NuGet.config`, not the network.
- The Svg failures were not investigated past the first error; "sibling
  sources" above is read from the error path, not from the project.
- The Linux builds ran on arch with the lab's git mirrors
  (`NUPKG_GIT_MIRRORS`); the origin URL in the clone is still the real
  one, so Source Link's `RepositoryUrl` is unaffected by the mirror.
- The lab `/private/tmp/nupkg-batch2v3` is kept for now; `build/`
  holds the Linux outputs, `src/` the checkouts.
