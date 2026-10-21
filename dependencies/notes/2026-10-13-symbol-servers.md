# The missing PDBs on the symbol servers

Run 13 October 2026 on `mac`. Online: Microsoft's symbol server
(`msdl.microsoft.com`) and nuget.org's (`symbols.nuget.org`), read only. Step 2
of the [dependency plan](2026-10-12-dependency-plan.md). Phoenix commit
`79cb67a7` (.NET 10). No build.

Data: `dependencies/data/2026-10-13-symbol-servers/mac/` (the lists stay out of git, as the
census lists do). The PDBs themselves are bytes and stay out too.

## Question

The census (13/10) found 181 packages in category C2b: the DLL points to a PDB
that is not in the package. For each of their shipped DLLs: is that exact PDB
on a public symbol server, and does it hold the compiler record? Every package
whose PDBs are all found with a compiler record moves to R ("ready to
rebuild").

A symbol server finds a PDB by the ID that the DLL carries in its CodeView
entry. The ID must match exactly, so a found PDB belongs to that DLL.

## Expectation (written before the run)

`[I]` all of it. The plan's draft said: "After step 2, most C2b packages move
to R. Microsoft and the large projects publish `.snupkg` files."

1. Microsoft's packages (141 of the 181): nearly all PDBs are on Microsoft's
   symbol server, with a compiler record. Microsoft's own .NET 10 builds use a
   recent Roslyn.
2. Third-party packages (40): about half publish a `.snupkg`, so about half are
   found on nuget.org's server.
3. A PDB found on one server is not also on the other.
4. Overall, more than 150 of the 181 move to R.

## Commands

From the root of Speciale2026, on `mac`, 13/10. `PDB_DIR` is a directory
outside git.

    python3 -I experiments/dep-census/census.py X ~/.nuget/packages data/2026-10-13-dependency-census/mac linux-x64 WebAPI BackgroundJobExecutor DbMigrator --tool dotnet-ef
    python3 -I experiments/dep-census/symbols.py probe data/2026-10-13-dependency-census/mac PDB_DIR data/2026-10-13-symbol-servers/mac
    python3 -I experiments/dep-census/symbols.py download data/2026-10-13-dependency-census/mac PDB_DIR data/2026-10-13-symbol-servers/mac

The commands are as run. On 21/10 `data/` and `experiments/` in them moved
to `dependencies/data/` and `dependencies/experiments/`.

The census was run again first, offline, to write `census.files.csv`: one row
per shipped DLL with its PDB name, GUID, age and PdbChecksum. Its
`census.csv` came out byte-identical to the run before.

`probe` asks both servers for each DLL's PDB by the Simple Symbol Query
Protocol key `<pdb>/<GUID>FFFFFFFF/<pdb>` (the age instead of `FFFFFFFF` for a
Windows-format PDB); nuget.org's server also wants the DLL's PdbChecksum in a
`SymbolChecksum` header. It downloads nothing. `download` fetches each found
PDB once, Microsoft's first, checks its PDB ID against the DLL, and reads the
compiler record and Source Link. Probe 85 s, download 49 s.

A first test by hand (8 requests) showed that nuget.org's server refuses `HEAD`
(405), so `probe` sends a `GET` and does not follow the redirect. One label in
the summary was reworded after the run (S1, see below); the numbers did not
change.

## Result

181 packages, 493 DLLs whose PDB is not in the package.

Per DLL:

| Microsoft's server | nuget.org's server | DLLs |
| --- | --- | ---: |
| found | not found | 407 |
| not found | found | 50 |
| found | refused (403) | 17 |
| not found | not found | 19 |

- 474 PDBs downloaded, 37.2 MB. 457 are portable PDBs; every one of them has
  the PDB ID of its DLL `[V]`. The other 17 are Windows-format PDBs (the 17
  that nuget.org refused); their ID was not checked.
- All 457 portable PDBs have a compiler record and Source Link `[V]`.
- No DLL's PDB was found on both servers.

Per package:

| Result | Meaning | Microsoft | Third-party | Total |
| --- | --- | ---: | ---: | ---: |
| R2 | All PDBs found, with compiler record: moves to R | 118 | 27 | 145 |
| S1 | All PDBs found, but in Windows format, which has no compiler record | 17 | 0 | 17 |
| S3 | No PDB on either server: stays C2b | 6 | 13 | 19 |

- **S1** is `NuGet.*` 6.12 (9 packages) and the ASP.NET scaffolding packages
  `Microsoft.VisualStudio.Web.CodeGeneration*` and
  `Microsoft.DotNet.Scaffolding.Shared` 10.0.2 (8).
- **S3** includes `DocumentFormat.OpenXml` 3.1.1, `Microsoft.FeatureManagement`
  4.5.0, `Hangfire.PostgreSql`, `PdfSharpCore`, `MigraDocCore`,
  `Workstation.UaClient` and six Serilog packages.
- **The compilers.** The 457 compiler records name 39 different Roslyn builds.
  367 DLLs come from one: `5.0.0-2.26373.116+e2f47b01`, the compiler of
  Microsoft's .NET 10.0.12 build `[I]`. The oldest is Roslyn 3.8.

The expectation, point by point:

1. **Held in part.** 135 of 141 Microsoft packages have all their PDBs on a
   server (424 DLLs on Microsoft's, 23 on nuget.org's), but only 118 with a
   compiler record: 17 publish Windows-format PDBs.
2. **Failed, for the better.** 27 of 40 third-party packages are found, not
   about half.
3. **Held.** No PDB is on both servers. For the 17 that nuget.org refused this
   is not known.
4. **Failed, narrowly.** 145 move to R, not more than 150.

## Interpretation

**The symbol servers more than double the packages that are ready to
rebuild.** With the census's 53, 198 of the 341 packages now declare both a
commit and a compiler record. The PDB is published; it is just not in the
package.

**A found PDB is trustworthy evidence.** Every portable PDB carries the ID of
its DLL, so it belongs to exactly that DLL; nuget.org also checks the DLL's
PdbChecksum before it serves the file `[I]`.

**The nupkg test needs many compilers, but one does most of the work.** 39 Roslyn
builds are named, yet 367 of the 457 DLLs need the same one, Microsoft's .NET
10.0.12 compiler `[I]`.

**The Windows PDB format is a dead end for our method.** It records no
compiler, so the 17 S1 packages stay without a declared compiler although
their PDBs are public.

## Caveats

- **Two servers only.** A publisher can host PDBs elsewhere; a package not
  found here may still have them.
- **nuget.org refused the 17 Windows-format PDBs (403)** `[V]`. I think it
  serves only portable PDBs `[I]`. They came from Microsoft's server.
- **The PDB checksum was not recomputed.** The match rests on the PDB ID, and
  for nuget.org also on the server's own checksum check.
- **The owner rule is crude.** `Serilog.AspNetCore` and
  `Serilog.Extensions.Hosting` count as Microsoft because their authors
  include Microsoft.
- **The lists and the PDBs are not in git.** `symbols.md` and `symbols.csv`
  name packages and versions; the PDBs are bytes. Make them again with
  `kommando.txt`. The 474 PDBs were kept in the session's scratch directory,
  which was emptied by 14/10; the nupkg test downloads them again.
