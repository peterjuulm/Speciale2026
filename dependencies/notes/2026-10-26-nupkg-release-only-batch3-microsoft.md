# Nupkg test, release-only method, batch 3: the Microsoft-owned packages

Planning note, 26 October 2026, late afternoon, written before the run.
Follows [batch 2](2026-10-26-nupkg-release-only-batch2.md) (the
third-party packages) of the same day, same method, version 2.

## Question

The same question on the other half of Phoenix's dependency set: the 139
packages whose nuget.org owner is Microsoft and which have the inputs the
method needs (a PDB with a compiler record, a declared commit). The census
of 13 October counts 196 Microsoft-owned package-versions; 118 of these 139
had their PDB fetched from Microsoft's symbol server on 13 October, 21 ship
it in the package.

## What runs

- The list: `recipes/release-only/batch-microsoft.txt`, 139 packages from
  20 repositories: 56 from `dotnet/dotnet` (the VMR that builds .NET 10),
  22 from `dotnet/runtime`, 8 each from `dotnet/aspnetcore`, `dotnet/roslyn`
  and `Azure/azure-sdk-for-net`, 11 from the AzureAD identity-model
  repository, and a tail of one to six. Five packages declare a
  `go.microsoft.com/fwlink` URL as their repository and will fail rule 2.
- The method of batch 2, unchanged: rules 1 to 8, version 2. The scripts
  changed only in how they move bytes: `rebuild.py` fetches from a local
  mirror per repository, so that the VMR is not fetched 56 times, and
  `run-batch.py` deletes a local build's clone and SDK once its output is
  saved. Neither changes the checkout or the build.
- `run-batch.py` as in batch 2: derive, commit the recipes, Linux builds on
  `arch` one after the other (or on `ubuntu-24.04` when the recorded folder
  is a runner's), Windows builds on `windows-2022`, levels by `level.py`,
  `results.tsv`.

## Expectation (written before the run)

`[I]` all of it.

1. Rule 3 skips most of the `dotnet/dotnet` and `dotnet/runtime` packages:
   their compiler is the one built inside the same VMR build
   (`5.0.0-2.26373.116` for .NET 10.0.12), and whether a public SDK bundles
   exactly that csc is the question. If the matching SDK exists, the
   packages derive but fail to build: a project inside the VMR needs
   Arcade's bootstrapped toolset, which `dotnet build` of one `.csproj`
   does not have.
2. Rule 7 skips a good share: Microsoft's repositories hold several
   `.csproj` per assembly name (reference assemblies, `ref/` and `src/`
   projects), and the rule wants exactly one.
3. Of the packages that build, Azure SDK, identity-model and the smaller
   repositories (OpenAPI.NET, RecyclableMemoryStream, Serilog's logging
   extension, YARP) are the candidates for level 1 or 2; Microsoft signs
   everything, so level 2 is the ceiling where our build matches.
4. Overall: fewer than a quarter derive and build; fewer than ten reach
   level 1 or 2. The batch is mainly a measurement of how far Microsoft's
   release facts carry without the Arcade toolset.
5. A equals A2 for every build that packs.

## Commands

See `dependencies/data/2026-10-26-nupkg-release-only-batch3-microsoft/kommando.txt`.

## Result

**Stopped at 14:26, during the derivation step, by decision: the day ends
here, and the batch is rerun tomorrow with a clean slate.** 57 of 139
packages had been derived (no build started, nothing dispatched to the
runners). What the derivations showed so far, for tomorrow's planning:

- The Azure SDK packages (Azure.Core 1.50.0 and Azure.Identity derived;
  Azure.Communication.Email, the KeyVault and Storage packages skipped):
  their compiler is `csc 4.4.0-6.22565.8`, which no public .NET 7 SDK
  bundles. The Azure repository pins Roslyn through the
  `Microsoft.Net.Compilers.Toolset` package, so rule 3 (SDK-bundled
  compilers only) cannot place them. A version 3 of rule 3 could look the
  compiler up among that package's versions.
- Several ASP.NET Core 9 packages skip for the same reason (csc
  `4.12.0-2.24422.8` with runtime 9.0.0, no public SDK).
- The `dotnet/dotnet` (VMR) packages derive: a public .NET 10 SDK does
  bundle their compiler. Whether they build is tomorrow's question.
- The derivation's checkouts of the VMR take 2 to 3 GB each commit; the
  SDK cache grew to 36 GB over the day (66 SDK versions installed as rule
  3's candidates). Disk, not time, is the constraint on `arch`.

The 57 derivations stay in the lab (`/private/tmp/nupkg-batch3/derive`),
not in the data folder; tomorrow's run derives from scratch so that one
run holds the whole batch.

## Caveats

- The Microsoft list was made on 26 October from the 13 October census;
  the symbol-server PDBs are the ones fetched then.
- `arch` has 46 GB free at the start; the VMR mirror alone may take ten.
  The run log records any build that fails for lack of space.
