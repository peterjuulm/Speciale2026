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

(after the run)

## Caveats

- The list still names Newtonsoft.Json twice (13.0.3 and 13.0.4); with
  name-version keys both now get a row, both rule-3 skips.
