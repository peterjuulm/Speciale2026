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

### Result

### Interpretation

## Caveats

- The fingerprint reads the line endings of files the SDK generates. A
  package that does not embed them in its PDB (no `EmbedUntrackedSources`)
  needs another sign.
- Build A imitates a Windows checkout on Linux; it does not imitate anything
  else about Windows.

## Not tested
