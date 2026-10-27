# Nupkg test, release-only method, batch 3 (Microsoft-owned packages), the complete run

Planning note, 27 October 2026, written before the run. The run of 26
October ([note](2026-10-26-nupkg-release-only-batch3-microsoft.md)) was
stopped during derivation; its question, list, method and expectation
carry over unchanged, with these corrections:

- Expectation 1 of 26 October was too pessimistic on the SDK: the pilot
  note of 21 October had already found `[V]` that SDK 10.0.111 bundles the
  compiler `5.0.0-2.26373.116` of the .NET 10.0.12 packages, and the 26
  October derivations confirmed that the `dotnet/dotnet` packages derive.
  The open question for them is whether `dotnet build` of one `.csproj`
  works without Arcade's bootstrap. Expected: no.
- The list has 139 package-version pairs but 129 names; ten packages come
  in two versions. The scripts now key everything by name and version, and
  `check-batch.py` verifies that all 139 pairs come through.

## What changed in the scripts (not in the method)

Keys by name and version; a disk guard (a local build does not start with
fewer than 8 GB free; the package is marked "not built: disk"); the local
build logs the kernel when not on a runner; `results.tsv` keeps the three
questions apart (`publisher_match`, `a_eq_a2`, `variation`, the last always
"not tested" in round A) and adds `sdk_alternatives` (the SDKs rule 3 did
not read because a lower one matched: an uncertainty, not a match),
`environment` and `differs` (the report lines that differ, as `level.py`
prints them; it changes no classification). The run is staged: derivation
and the local `arch` builds first with nothing committed; the runner-bound
packages ("awaiting push") follow once the recipes are on `main`.

## Expectation (written before the run)

As on 26 October, items 2 to 5, with item 1 replaced by: the `dotnet/dotnet`
and `dotnet/runtime` packages derive, but their single-project builds fail
on Arcade's missing toolset; the Azure SDK and ASP.NET Core 9 packages skip
on rule 3 (compiler from the `Microsoft.Net.Compilers.Toolset` package, not
from an SDK), as the 26 October derivations showed `[V]`.

## Run 1 under method version 2, stopped after the derivation (10:03 to 10:36)

The derivation of all 139 pairs under version 2 gave: 49 derived, 90
skipped. `[V]` `v2-derive/batch.txt` in the data folder, one `facts.txt` per
pair. The skips by rule:

| Rule | Skips | What was behind it |
| --- | --- | --- |
| 3, no public SDK with the recorded runtime has the compiler | 44 | The compiler record's runtime is the runtime the compiler ran on, which the SDK host rolls forward to the newest patch installed; it does not name the SDK's bundled runtime. Azure.Storage.Blobs 12.20.0: csc `4.4.0-6.22565.8` is SDK 7.0.101's, recorded on runtime 7.0.18. And Microsoft builds GA releases with the preceding preview SDK: ASP.NET Core 9.0.0's `global.json` pins `9.0.100-rc.1.24452.12`; the rule excluded previews |
| 7, several `.csproj` with the assembly name | 38 | The .NET repositories hold a `ref/` project (reference assembly) beside the `src/` project, and `source-build-assets/referencePackages/` holds old copies; `Microsoft.Data.Sqlite.Core` and `Microsoft.Data.Sqlite` share an assembly name |
| 3, compiler ran on .NET Framework | 6 | MSBuild, Visual Studio's toolchain |
| 1, no compiler record | 1 | Microsoft.Data.SqlClient |
| crash in rule 2 | 1 | A PDB with two Source Link entries; the first (a code generator's repository) was taken |

One local build ran before the stop: `Microsoft.AspNetCore.App.Runtime.linux-x64`
failed with NETSDK1226 (a project inside the VMR needs the repository's
bootstrap), as expected. The run was stopped because 82 of the 90 skips
measured the rules, not the packages, and the rules could be made right
from allowed inputs. Those changes are method **version 3**, below; the
batch is run again from a clean lab under it, and the version-2 derivation
record stays as the measurement that motivated the change.

## Method version 3 (27 October, before run 2)

Every change reads only allowed inputs; each is marked in `facts.txt`.

- **Rule 2.** Of several Source Link entries, the one whose commit is the
  manifest's (read). A commit not reachable at the URL: skipped, not a
  crash.
- **Rule 3.** `global.json`, a standard file of the source, is read first:
  if it pins an SDK whose `csc.dll` has the PDB's compiler, that SDK (read).
  Else the candidates are every public SDK of the channel, previews
  included, whose bundled runtime is not newer than the recorded one; the
  lowest with the compiler is taken (inferred) and the ones not read are
  listed as the uncertainty. A project that references the
  `Microsoft.Net.Compilers.Toolset` package by a concrete version compiles
  with that package's `csc`, verified the same way; a reference through an
  MSBuild property (Arcade) is noted and left to the SDK rules. `csc.dll`
  is read out of the SDK archive without installing (`sdk-csc.json`, one
  line per SDK ever read).
- **Rule 7.** Of several projects with the assembly name, those under
  `ref/` or `referencePackages/` are dropped (the package ships `lib/`);
  of the rest, the one named like the package id wins (inferred). Still
  several: skipped.
- **Rule 8.** `AssemblyVersion` and `FileVersion` from the shipped DLL's
  attributes are passed as well (read): batch 2 reached level 4 on these
  two values in 15 of 20 cases.

Tested before the run on Azure.Storage.Blobs (now SDK 7.0.101 by
`global.json`), Microsoft.AspNetCore.DataProtection 9.0.0 (the rc.1 SDK),
Microsoft.Extensions.Logging.Abstractions and Microsoft.Data.Sqlite.Core
(rule 7's two tie-breaks), all derived `[V]` (facts in the data folder
after the run).

## Expectation for run 2, version 3 (written before the run)

`[I]` all of it.

1. Derived: 120 or more of 139. Remaining skips: the 6 .NET Framework
   compilers, SqlClient, and a few whose SDK no public release bundles.
2. The 56 `dotnet/dotnet` and the `dotnet/runtime` packages derive but
   fail to build (Arcade's bootstrap missing: NETSDK1226 or similar).
   Likewise roslyn, msbuild, aspnetcore (Arcade too).
3. Azure SDK, the identity-model packages, Microsoft.Identity.Web and the
   small repositories (OpenAPI.NET, RecyclableMemoryStream, YARP) build;
   Microsoft signs, so level 2 is their ceiling; a few reach it.
4. Overall: 25 to 40 build, fewer than 15 at level 1 or 2; the batch
   measures how far the single-project method carries without Arcade.
5. A equals A2 for every build that packs.

## Commands

See `dependencies/data/2026-10-27-nupkg-release-only-batch3-microsoft/kommando.txt`.

## Result

(after the run)

## Caveats

- Run 2 starts from a clean lab: every `/private/tmp/nupkg-*` lab of 21 to
  27 October was removed on 27 October (60 GB), their text outputs having
  been copied into the data folders. Round B's binary artefact stores went
  with them; reprotest's diffs are in the kept logs.
