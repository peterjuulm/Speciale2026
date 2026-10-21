# Nupkg test: pilot

Run 21 October 2026 on `arch`. The pilot of step 3 in the
[dependency plan](2026-10-12-dependency-plan.md), after the
[short plan](2026-10-21-nupkg-test-plan.md). Phoenix commit `79cb67a7`
(.NET 10). Run while Leo and Peter were away, at Leo's request
("try out some pilots first").

Data: `dependencies/data/2026-10-21-nupkg-pilot/arch/`. Scripts:
`dependencies/experiments/nupkg/`. Lab: `/private/tmp/nupkg-pilot`, outside
every repository of ours. The builds run inside clones of the declared
commits, as the plan says they must.

## Question

For a package that Phoenix ships: when we build it from its declared commit
with its declared toolchain, do we get the bytes of the DLL on nuget.org? If
not, how close do we get, and what is the first cause? Are our own two builds
the same?

## Which packages

Leo and Peter asked for the Microsoft packages and the transitive packages
that most of Phoenix's graph depends on, not small leaf packages (21/10). The
count of dependents comes from the three programs' lock files at `79cb67a7`
(packages in them that list the package as a dependency) `[V]`:

| Package | Dependents in Phoenix's graph | Who | Built on (see below) |
| --- | ---: | --- | --- |
| Microsoft.Extensions.Logging.Abstractions 10.0.12 | 23 | Microsoft, `dotnet/dotnet` | Windows |
| Newtonsoft.Json 13.0.4 | 13 | third party | Windows, on .NET Framework |
| Serilog 4.2.0 | 13 | third party | Windows |
| Microsoft.Extensions.DependencyModel 10.0.12 | 12 | Microsoft, `dotnet/dotnet` | Windows |
| Microsoft.EntityFrameworkCore 10.0.12 | 8 | Microsoft, `dotnet/dotnet` | Windows |
| Azure.Core 1.50.0 | 6 | Microsoft, `Azure/azure-sdk-for-net` | Windows |

Two things were found while choosing, before any build:

- **The framework packages do not ship their own DLL** `[V]`. In the
  reference release's `WebAPI.deps.json`,
  `Microsoft.Extensions.Logging.Abstractions.dll` (and `Logging`, `Options`,
  `Primitives`) comes from `runtimepack.Microsoft.AspNetCore.App.Runtime.linux-x64/10.0.12`,
  not from the package. The shipped file is 142,672 bytes; the package's
  `lib/net10.0` DLL is 66,856 bytes. A self-contained publish takes the
  runtime pack's copy, so for these packages the thing to rebuild is the
  runtime pack. `Microsoft.Extensions.DependencyModel` and EF Core are not in
  the shared framework and ship their package DLL.
- **The PDB tells which operating system built a package** `[V]` on known
  cases. The SDK writes `<name>.AssemblyInfo.cs` with the platform's line
  endings, and most packages embed that file in the PDB. RBush 4.0.0, built
  by its Ubuntu workflow, has it with LF only; Ardalis.GuardClauses 5.0.0
  (`D:\a\…` paths, a GitHub Windows runner) and Cronos 0.9.0 (`C:\projects\…`,
  AppVeyor) with CRLF only. By that sign, all six packages above were built on
  Windows; FluentValidation 11.11.0, built on its maintainer's machine, on
  Linux or macOS. Newtonsoft.Json's compiler record also says its compiler ran
  on .NET Framework 4.8 (`runtime-version: 4.8.9315.0`), so on Windows with
  MSBuild from Visual Studio or Build Tools `[I]`.

A Windows build cannot give the same DLL on Linux `[I]`: the generated files
differ in line endings, their checksums are in the PDB, and the DLL carries
the PDB's ID and checksum. What a Linux build can show is whether the code is
the same. Hence the levels below.

## Levels of a match

Each build is compared with nuget.org's DLL and gets the first level that
holds:

1. **Identical**: the same bytes.
2. **Identical without signatures**: the same after removing the Authenticode
   certificate table, the strong-name signature and the PE checksum
   (decision 6).
3. **Same code**: the IL bodies, the metadata streams `#~`, `#Strings`, `#US`
   and `#Blob`, and the managed resources are the same; what differs is the
   debug identity (PDB ID, PDB checksum, MVID, PE timestamp) and what is
   computed from it (the signatures).
4. **Different code**: anything else.

Level 3 is read from `dllreport.cs`, which hashes each part separately.

## Method

The eight steps of the plan, per package:

1. Download the `.nupkg` (and `.snupkg`) from nuget.org; its SHA-512 must equal
   the `.nupkg.sha512` in the NuGet cache that Phoenix restored.
2. Report the published DLL with `dllreport.cs`; check its PDB documents
   against a clone of the declared commit with `srccheck.py` (LF or CRLF;
   generated files apart).
3. The SDK from the compiler record (Roslyn build and the runtime it ran on),
   mapped to an SDK release; installed alone with `install-sdk.py`, which
   checks the archive's SHA-512 against Microsoft's release metadata. After
   installing, read the SDK's own `csc.dll` and runtime versions.
4. The build command and environment from the repository's CI file or build
   script.
5. Build A with `build.sh`: a new directory, `env -i` with only HOME (empty),
   PATH (the SDK first), LANG=C.UTF-8, an empty NUGET_PACKAGES,
   DOTNET_CLI_TELEMETRY_OPTOUT, DOTNET_NOLOGO and the variables the
   repository declares; build servers shut down before and after.
6. Build B the same way in another directory.
7. `compare.py` on nuget.org's package, A's and B's.
8. `dllreport.cs` on all three DLLs; `diff` of the reports gives the level.

## Pilot 1: Serilog 4.2.0

**Declared.** `.nuspec`: `serilog/serilog` at `c00e17fd` (branch main).
Shipped file `lib/net9.0/Serilog.dll`. Compiler record: Roslyn
`4.12.0-3.24570.6+913fb4ec` on runtime `9.0.0`, which is SDK 9.0.101: 9.0.100
has `4.12.0-3.24523.4`, 9.0.102 has `4.12.0-3.24574.8` and runtime 9.0.1
`[I]`, checked after installing. CI (`.github/workflows/ci.yml` at the
commit): `windows-latest`, `setup-dotnet` `9.0.x`, `actions/checkout@v4`
(depth 1), runs `Build.ps1`, which restores with `--no-cache`, builds the
solution with `-c Release --version-suffix=<branch>-<short hash>
/p:ContinuousIntegrationBuild=true`, and packs each `src/` project with
`--no-build`. On `main` the package gets no suffix; the DLL keeps the build's
suffix, `4.2.0-main-c00e17f+c00e17fd…` in the published DLL `[V]`. Strong
name with `assets/Serilog.snk`, which is in the repository; no Authenticode.

Read before the build `[V]`: the nuget.org package is the file Phoenix
restored (SHA-512 equal); its PDB has 117 documents, 5 of them embedded
generated files, and the three the SDK wrote (`AssemblyInfo.cs`,
`AssemblyAttributes.cs`, `GlobalUsings.g.cs`) have CRLF line endings only.
The tag `v4.2.0` points at `0e316b7c`, not at the declared `c00e17fd`.

Builds, all with SDK 9.0.101, the script's commands run directly (PowerShell
is not installed on `arch`), and a depth-1 fetch of the declared commit as
`actions/checkout` does, so the short hash has the same length:

- **A**: checkout with `core.autocrlf=true`, as Git for Windows does by
  default on a Windows runner, so tracked files get CRLF.
- **B**: the same as A, in another directory.
- **C**: a plain Linux checkout (LF), to see the line endings' own effect.

### Expectation (written 12:29, before the SDK install and any build)

`[I]` all of it.

1. SDK 9.0.101's `csc.dll` is Roslyn `4.12.0-3.24570.6+913fb4ec` and its
   runtime is 9.0.0.
2. A's tracked source documents match the published PDB's checksums; C's do
   not (LF against CRLF).
3. A: level 3, same code. The three SDK-generated files get LF on Linux, so
   the PDB differs, and with it the PDB ID, the PDB checksum, the MVID, the
   PE timestamp and the strong-name signature. IL, metadata streams,
   resources, compiler record and references are the same as nuget.org's.
4. C: level 3 as well, unless a string literal in the source spans lines;
   then `#US` differs too and C is level 4.
5. A and B are identical (level 1 to each other).
6. Declared: not fully. The OS is declared (`windows-latest`) but is not the
   one we build on; the SDK only as `9.0.x`, made exact by the compiler
   record; the tag points elsewhere than the declared commit.

### Commands

Verbatim in `kommando.txt`; the build recipes in
`dependencies/experiments/nupkg/recipes/serilog-4.2.0-{crlf,lf}.sh`. Each
build's log starts with its environment, git configuration, `dotnet --info`
and the `csc.dll` hash. Builds A, B and C ran 12:30:40-12:31:35, about 18
seconds each, with warm network caches but empty package caches.

### Result

| Build | `Serilog.dll` against nuget.org | Level |
| --- | --- | --- |
| A, CRLF checkout | differs; IL, the four metadata streams, resources, compiler record and references are equal | 3, same code |
| B, as A in another directory | byte-identical to A | 3 |
| C, LF checkout | differs; IL and the four metadata streams are equal, one embedded resource is not | 4 |

Point by point `[V]` (reports and diffs in `data/…/serilog/`):

1. **Held.** SDK 9.0.101's `csc.dll` is `4.12.0-3.24570.6+913fb4ec`, its only
   runtime 9.0.0; our PDBs record the same compiler and
   `runtime-version: 9.0.0+9d5a6a9a…` as nuget.org's.
2. **Held.** All 112 tracked source documents have the published checksum in
   their CRLF form: as checked out in A, after conversion in C. The other 5
   documents are generated.
3. **Held.** Between nuget.org's DLL and A's, exactly these differ: the PE
   timestamp, the PE checksum, the strong-name signature, the `#GUID` stream
   (the MVID), the CodeView GUID and the PDB checksum; in the PDB, its ID and
   three documents, `Serilog.AssemblyInfo.cs` (26 lines), `GlobalUsings.g.cs`
   (7) and `AssemblyAttributes.cs`, which have CRLF in nuget.org's and LF in
   ours. The two PolySharp files are equal in both: that generator writes
   CRLF on every OS.
4. **Failed, in an unexpected place.** No string literal differs (`#US` is
   equal), but the managed resource `ILLink.Substitutions.xml`, an XML file
   for the trimmer, is 347 bytes with 7 CRLF in nuget.org's DLL and in A's,
   and 340 bytes with 7 LF in C's. So C is level 4 by the definition, with
   identical IL.
5. **Held.** A and B are byte-identical, DLL and PDB, although they were
   built in different directories.
6. As expected: the OS is declared but not the one we build on, the SDK is
   declared only as `9.0.x`, and the tag `v4.2.0` points at `0e316b7c`, not at
   the declared `c00e17fd` `[V]`.

The other files in the package differ as well, as expected: the XML
documentation (line endings), the `.nuspec`, and nuget.org's signature, which
only the published package has. The published package also has `net462` and
`net471` DLLs, which the project builds only on Windows.

### Interpretation

From Linux, Serilog 4.2.0 is as close as it can get: the compiler produced
the same code from the declared source with the declared compiler. The bytes
differ only through three files that the SDK itself writes during the build,
with the operating system's line endings. So the package is reproducible in
its code and not in its bytes, and the cause is the build OS, which the
package declares only in its CI file. A Windows build is the test that is
left.

The line endings of the checkout matter beyond the PDB: one resource, a text
file, carries them into the DLL itself (C). A rebuild of a Windows-built
package has to check out the way Windows does.

### Build D: Windows line endings in the generated files (diagnostic)

Leo asked for this test before any Windows build. Build D is build A plus
`dependencies/experiments/nupkg/windows-newlines.targets`, imported through
`CustomAfterMicrosoftCommonTargets` (an environment variable in the recipe
`serilog-4.2.0-crlf-generated.sh`). Just before the compiler runs, it gives the
three files the SDK generated CRLF line endings, as the SDK writes them on
Windows. It simulates one thing about Windows and nothing else; it is not a
way to build the package, only a test of the interpretation above.

#### Expectation (written 12:52, before build D)

`[I]` all of it.

1. D's `lib/net9.0/Serilog.dll` is byte-identical to nuget.org's (level 1),
   strong-name signature included, since the key is in the repository.
2. D's PDB is byte-identical to the one in nuget.org's `.snupkg`.
3. D's `net8.0`, `net6.0` and `netstandard2.0` DLLs are identical to nuget.org's
   as well; the XML documentation files still differ (the compiler writes them
   with the platform's line endings).
4. If 1 fails, the report diff names something else that a Windows build
   changes.

#### Result

## Next: the Microsoft packages

Not built yet; what was found while preparing them `[V]`:

- `dotnet/dotnet` at `95017c71` declares `tools.dotnet` 10.0.111. That SDK's
  `csc.dll` is `5.0.0-2.26373.116+e2f47b01`, the compiler in the PDBs of
  `Microsoft.Extensions.DependencyModel` and EF Core 10.0.12, and its only
  runtime calls itself `10.0.11-servicing.26373.116+e2f47b01`, the string in
  their `runtime-version`. So Microsoft's toolset for .NET 10.0.12 is a public
  SDK. (Public runtimes carry the `-servicing` label too: Phoenix's own PDBs,
  built with SDK 10.0.401, record `10.0.12-servicing.26422.108+95017c71`.)
- All 144 references in `Microsoft.Extensions.DependencyModel`'s compiler
  record are, by MVID, the DLLs of the public `Microsoft.NETCore.App.Ref`
  10.0.12. EF Core's 177: 167 there, the other 10 are other packages
  (`Microsoft.Extensions.*`, EF Core's own abstractions), not checked yet.
- Both were built on Windows (the fingerprint), with Authenticode and
  Microsoft's strong-name signature.

So every input of the compile step is public: the source on GitHub, the
compiler, the references, and the generated files, which are embedded in the
PDB. That makes a compile-step rebuild possible, as Roslyn's BuildValidator
does: compile the declared sources with the recorded options and compare.
Taking the generated files from the PDB removes the build OS from the
question. BuildValidator is not published as a package
(`Microsoft.CodeAnalysis.Rebuild` is not on nuget.org); it is built from the
Roslyn repository.

## Caveats

- The fingerprint reads the line endings of files the SDK generates. A
  package that does not embed them in its PDB (no `EmbedUntrackedSources`)
  needs another sign.
- Build A imitates a Windows checkout on Linux; it does not imitate anything
  else about Windows.
- Step 2 ran on the build clones after the builds, not before; the builds do
  not change tracked files.
- `Build.ps1` itself did not run (no PowerShell on `arch`). Its dotnet
  commands ran with the values it computes on `main` in CI: build suffix
  `main-` plus the short hash (7 characters at depth 1, as in CI), no package
  suffix.
- One machine, one run per build.

## Not tested

- A Windows build of Serilog (would test whether A's three differences are
  all there is).
- Any Microsoft package build; the compile-step rebuild above.
- Newtonsoft.Json, whose compiler ran on .NET Framework 4.8: that needs
  Windows with Visual Studio's MSBuild.
