# Repository-build method: the overnight run, 27 to 28 October 2026

Result note for the run planned in
[2026-10-27-nupkg-repository-build-plan.md](2026-10-27-nupkg-repository-build-plan.md).
Twenty Arcade repository builds (99 packages in scope) ran on arch from
27 October 21:45 to 28 October 03:40, one at a time, unattended. The
plan's rules were amended four times during the night, each time as a
new version written into the plan note before its batch ran; the
version-1 rows were never changed. Everything measured is in
`dependencies/data/2026-10-27-nupkg-repository-build/` (version 1) and
`dependencies/data/2026-10-28-nupkg-repository-build-v{2,3,4}/`:
`results.tsv`, `run.log`, and per build the full build log (or an
excerpt), the toolchain record, the package comparison and the two DLL
reports every level was derived from.

The levels are the ones of the release-only method: 1 identical; 2 only
signature-related bytes differ; 3 same IL, metadata streams and managed
resources, build identity (MVID, timestamp, PDB) differs; 4 anything
else.

## What ran

| version | rule change (plan note section) | batch | recipes |
|---|---|---|---|
| 1 | the plan as written | `2026-10-27-nupkg-repository-build` | all 20 (two rerun after script fixes) |
| 2 | VMR identity properties; `EnableNgenOptimization=false` | `…-v2` | the 4 VMR inner builds, the 2 msbuild builds |
| 3 | runtime without the native shims, with `-allconfigurations`; aspnetcore 8.0 with Node 18 | `…-v3` | the 8 standalone runtime builds, aspnetcore 8.0 |
| 4 | sources as committed (`core.autocrlf=false`); invariant globalization only below .NET 6 | `…-v4` | VMR aspnetcore, runtime 8.0.0, 8.0.1, 8.0.10, 7.0.0, 6.0.0 |

Timeline `[V]` (`run.log`): version 1 21:47 to 23:51, its two reruns
(aspnetcore 9.0.0 after the submodule and exit-code fixes, Roslyn with
`-bl`) 23:51 to 00:10, version 2 00:10 to 01:08, version 3 01:08 to
02:32, two more version-1 reruns (aspnetcore 6.0 and 8.0 with the
exit-code fix) 02:32 to 02:36, version 4 02:36 to 03:40. Builds were
much faster than the plan's estimate (runtime libraries 8 to 20 min,
aspnetcore 5 to 9 min, Roslyn 20 min, msbuild 3 min).

## Result

Numbers `[V]` from the four `results.tsv` (tables printed from them).
"not compared": the build produced no package of that name. The `build`
column is the whole build script's exit: "did not build (exit 1)" with
measured rows means the packages were produced and a later step failed
(Roslyn: `NU5104` in packages outside the scope; runtime 6.0 to 8.0 under
version 3: the AsnXml check of reading 2). The version-1 rows of the four
recipes rerun after script fixes are the rerun's rows.

Across the versions, the best row per package `[V]` (computed from the
four files): of the 99 packages in scope, 3 were not derived (two
runtime packs, R8; Microsoft.NET.StringTools, rule 7), 4 never got a
package (symreader; the two aspnetcore 6.0.24 Razor packages: feed
retention; System.IO.Ports 5.0.0: the SDK), and 92 were compared. Level
1 and 2: none (every official build was signed and ran on Windows).
Level 3 in at least one version: 35. Level 4 in every version: 57, of
which 36 differ from the shipped bytes in nothing but the newline of a
generated resource (reading 2), 10 in that resource and, through its
length, the `FieldRVA` table (reading 2, read 28 October morning), 9 in
the order of their type table
(reading 3: the eight Roslyn packages and EFCore), 1 in a source-root
index (reading 4) and 1 in Razor positions (reading 5).

### Version 1, `2026-10-27-nupkg-repository-build`: 96 rows, levels -: 29, 3: 13, 4: 54
| recipe | products | level 3 | level 4 | not compared | build |
|---|---|---|---|---|---|
| symreader-27e5846 | 1 | 0 | 0 | 1 | did not build (exit 1) |
| dotnet-efcore-95017c7 | 9 | 8 | 1 | 0 | ran |
| dotnet-aspnetcore-95017c7 | 10 | 0 | 10 | 0 | ran |
| dotnet-runtime-95017c7 | 34 | 0 | 34 | 0 | ran |
| msbuild-995a3dc | 1 | 0 | 0 | 1 | did not build (exit 1) |
| reverse-proxy-77f78d4 | 1 | 1 | 0 | 0 | ran |
| runtime-9d5a6a9 | 8 | 0 | 0 | 8 | did not build (exit 1) |
| runtime-fa7cdde | 4 | 0 | 0 | 4 | ran |
| runtime-5535e31 | 2 | 0 | 0 | 2 | did not build (exit 1) |
| runtime-81cabf2 | 3 | 0 | 0 | 3 | did not build (exit 1) |
| runtime-bf5e279 | 1 | 0 | 0 | 1 | did not build (exit 1) |
| msbuild-02bf662 | 1 | 0 | 0 | 1 | did not build (exit 1) |
| dotnet-runtime-4452502 | 1 | 0 | 1 | 0 | ran |
| runtime-cf258a1 | 1 | 0 | 0 | 1 | did not build (exit 134) |
| runtime-4822e3c | 2 | 0 | 0 | 2 | did not build (exit 1) |
| runtime-d099f07 | 1 | 0 | 0 | 1 | did not build (exit 1) |
| aspnetcore-af22eff | 4 | 4 | 0 | 0 | ran |
| roslyn-6c4a46a | 8 | 0 | 8 | 0 | did not build (exit 1) |
| aspnetcore-2aa4015 | 2 | 0 | 0 | 2 | did not build (exit 1) |
| aspnetcore-3f1acb5 | 2 | 0 | 0 | 2 | did not build (exit 1) |

### Version 2, `…-v2`: 56 rows, levels 3: 26, 4: 30
| recipe | products | level 3 | level 4 | not compared | build |
|---|---|---|---|---|---|
| dotnet-aspnetcore-95017c7 | 10 | 9 | 1 | 0 | ran |
| dotnet-efcore-95017c7 | 9 | 8 | 1 | 0 | ran |
| dotnet-runtime-95017c7 | 34 | 7 | 27 | 0 | ran |
| msbuild-995a3dc | 1 | 0 | 1 | 0 | ran |
| msbuild-02bf662 | 1 | 1 | 0 | 0 | ran |
| dotnet-runtime-4452502 | 1 | 1 | 0 | 0 | ran |

### Version 3, `…-v3`: 24 rows, levels -: 1, 3: 4, 4: 19
| recipe | products | level 3 | level 4 | not compared | build |
|---|---|---|---|---|---|
| aspnetcore-3f1acb5 | 2 | 2 | 0 | 0 | ran |
| runtime-fa7cdde | 4 | 0 | 4 | 0 | ran |
| runtime-9d5a6a9 | 8 | 1 | 7 | 0 | ran |
| runtime-81cabf2 | 3 | 0 | 3 | 0 | did not build (exit 1) |
| runtime-bf5e279 | 1 | 0 | 1 | 0 | did not build (exit 1) |
| runtime-5535e31 | 2 | 1 | 1 | 0 | did not build (exit 1) |
| runtime-d099f07 | 1 | 0 | 1 | 0 | did not build (exit 1) |
| runtime-4822e3c | 2 | 0 | 2 | 0 | did not build (exit 1) |
| runtime-cf258a1 | 1 | 0 | 0 | 1 | did not build (exit 134) |

### Version 4, `…-v4`: 19 rows, levels 3: 7, 4: 12
| recipe | products | level 3 | level 4 | not compared | build |
|---|---|---|---|---|---|
| dotnet-aspnetcore-95017c7 | 10 | 7 | 3 | 0 | ran |
| runtime-81cabf2 | 3 | 0 | 3 | 0 | ran |
| runtime-bf5e279 | 1 | 0 | 1 | 0 | ran |
| runtime-5535e31 | 2 | 0 | 2 | 0 | ran |
| runtime-d099f07 | 1 | 0 | 1 | 0 | ran |
| runtime-4822e3c | 2 | 0 | 2 | 0 | ran |

## Readings

Each reading names what was measured (`[V]`, a file under the data
folder or a scratch comparison repeated below) and what it is taken to
mean (`[I]`).

### 1. The VMR identity attributes (version 1 to 2)

`[V]` Under version 1 the packages from the VMR inner builds came out at
level 4 with one exception: 46 of 54 (aspnetcore 10, runtime 34, Bcl.Cryptography 1, efcore 1 of 9; the other 8 efcore packages were level 3)
with `#Blob` and `#~` differing. The attributes differ: the shipped DLLs
say `RepositoryUrl=https://github.com/dotnet/dotnet` and carry
`OriginalRepoCommitHash`; ours said `dotnet/aspnetcore`, `dotnet/runtime`
and had no such attribute. Under version 2 (the two properties the VMR
passes, read from `src/source-manifest.json`), 18 of those rows moved to
level 3 and `#Blob`/`#~` stopped differing everywhere except the four
cases in readings 3 to 5.

`[I]` The VMR orchestration passes the inner build two identity values
that the inner repository's own build cannot know. A standalone build of
the inner repository at the same commit is therefore not the official
build's input; the plan's caveat on standalone VMR builds was right, and
the two properties are the whole of that difference for the attributes.

### 2. Line endings: where the checkout's newline ends up in the bytes

Version 1 set `core.autocrlf=true` (R6) as a model of a Windows
checkout. Version 4 tried the opposite (sources as committed, LF) after
a misreading of Identity.UI (reading 5) and made things worse; the
shipped bytes decided it:

- `[V]` 27 of the 34 runtime 10.0.12 packages, and every standalone
  runtime package with string resources (9.0.11, 9.0.0, 8.0.x, 7.0.0,
  6.0.0), embed `ILLink.Substitutions.xml`, generated by
  `eng/illink.targets` from a committed template through
  `WriteLinesToFile`. Shipped: CRLF (14 CR in 14 lines); ours: LF;
  identical otherwise (Logging 10.0.12: 876 against 862 bytes). The
  seven runtime packages without string resources have no such resource
  and sit at level 3.
- `[V]` The shipped Microsoft.Extensions.DependencyModel 8.0.2 and
  System.Memory.Data 8.0.1 carry CRLF inside the assembly description
  attribute and the version resource (748 characters with 2 CR against
  our 746 with 0 under version 4); the text is the multi-line
  `PackageDescription` of the csproj. Under versions 1 to 3 (CRLF
  checkout) these matched.
- `[V]` The shipped Diagnostics.EntityFrameworkCore, SpaProxy and
  Identity.UI 10.0.12 carry CRLF in Razor HTML literals and in an
  embedded PowerShell script; under version 4 ours had LF and the three
  fell to level 4, under version 2 (CRLF checkout) the first two were
  level 3.
- `[V]` The runtime 6.0 to 8.0 builds under version 3 (CRLF checkout)
  produced their packages and then failed in `AsnXml.targets`: the
  XSLT-regenerated `.xml.cs` files are diffed against the checked-in
  ones, which were CRLF after conversion while the generator on Linux
  writes LF; `--ci` turns the warning into an error. Under version 4 (LF
  checkout) the same builds exited 0.

- `[V]` (added 28 October 07:30) The ten runtime rows that differ in
  the resource and in `#~` (`tabledump.cs` on the kept DLL pairs:
  DependencyModel, Logging, Logging.Abstractions 10.0.12 from version
  2; ConfigurationManager, Pkcs 9.0.11 and Cryptography.Xml 9.0.0 from
  version 3; DependencyModel 8.0.2, IO.Packaging, MetadataLoadContext,
  CodeDom from the version-4 output, the lab keeps one per recipe):
  the type and method tables are in the same order in every pair; the
  only `#~` rows that differ in the version-2 and version-3 pairs are
  the `FieldRVA` rows. The resource blob is 8 or 16 bytes longer in the
  shipped DLL (the CRLF substitutions file, padded), and the
  strong-name slot and the static data fields that follow it in `.text`
  sit that much higher (Logging 10.0.12: resources end `0xB4A4` against
  `0xB49C`, the one static field at `0xB680` against `0xB678`). The
  four version-4 pairs also show the `CustomAttribute` blob indices
  shifted by the LF description attribute of the bullet above. So all
  46 resource rows are one effect: the newline of one generated file,
  and what its length moves.

`[I]` The official build checks the sources out with conversion to CRLF
(`* text=auto` on Windows) and runs on Windows. Our Linux build with
`core.autocrlf=true` gets the same source bytes; the remaining newline
differences come from build steps that write the platform's newline
(the substitutions template copied line by line, the AsnXml generator).
The level-4 rows that differ only in `managed resources` are this
effect and nothing else; a Windows run of the version-3 recipes would
close them, and nothing else about the method needs to change for that.

### 3. The order of source files

`[V]` Roslyn: all eight Microsoft.CodeAnalysis 5.0.0 packages at level 4
with IL bodies, `#~`, `#Blob` and `#US` differing. Microsoft.CodeAnalysis.CSharp:
43097 methods in both DLLs, 4658 user strings in both; 920 IL bodies
differ; the method table order differs: in the shipped DLL the types of
`Symbols/SynthesizedNamespaceSymbol.cs` and
`Symbols/SynthesizedSimpleMethodTypeParameterSymbol.cs` follow
`SymbolEqualityComparer` directly, in ours the types of the subfolder
`Symbols/Synthesized/` come first and those two files' types 1500 rows
later. EFCore 10.0.12 (the one efcore row at level 4 in every version):
17613 methods, same order; 8 bodies differ by one `TypeDef` token
(`ChangeTrackingStrategy` is row 0x14 in the shipped table, 0x15 in
ours) because `src/EFCore/ChangeTrackingStrategy.cs` sorts before the
subfolder `src/EFCore/ChangeTracking/` in the shipped build and after it
in ours. Both projects use the default `**/*.cs` glob.

`[I]` The compiler emits types in the order of its input files, and
that order is the order in which MSBuild's glob walks the directory
tree, which differs between the Windows and Linux walks when a folder
holds a file and a subfolder whose names share a prefix. Every token
that points at a shifted row changes, so hundreds of method bodies
differ although no instruction does. The compiler is deterministic; the
list it was given is an environment-dependent input that no standard
names, and the publisher's ordered compiler inputs are not available to
read (28/10 08:10: softened after a second opinion; whether a build log
records the order was not checked). To confirm: build once with the Compile items
sorted, or walk the two orders with MSBuild's `FileMatcher`.

`[V]` (added 28 October 07:35) The Linux half of the walk: `globorder/globorder.proj`
(MSBuild 10, `**/*.cs` over `src/Compilers/CSharp/Portable` of Roslyn at
the commit, exported from the mirror) lists 1140 files with
`Symbols/SymbolEqualityComparer.cs` at 853, the subfolder
`Symbols/Synthesized/` at 860 to 936 and `Symbols/SynthesizedNamespaceSymbol.cs`
at 937: the order our DLL's type table has. The Windows half is the
shipped DLL's order, and the Windows run below rebuilds Roslyn on the
host that produced it.

### 4. The deterministic source-root index

`[V]` Microsoft.Build.Framework 18.0.2 (version 2) at level 4 with IL
and `#US` only; one user string differs: shipped
`/_3/ErrorReporting/FailFast.cs`, ours
`/_1/microsoft.codeanalysis.contracts/5.0.0-1.25277.114/contentFiles/cs/net9.0/ErrorReporting/FailFast.cs`,
a `[CallerFilePath]` of a source file that a NuGet package contributes.

`[I]` Arcade's deterministic source paths map each `SourceRoot` to
`/_N/`; the official build had the package's content folder as a root
of its own, the third one, ours only the package cache as the first.
`PathMap` makes paths deterministic relative to the set of roots, and
that set depends on the environment. To confirm: the official build's
`SourceRoot` items (a binlog of an official build, not available).

### 5. The Razor compiler of the VMR

`[V]` Identity.UI 10.0.12 at level 4 in every version, IL and `#US`
only. The differing strings are Razor tag-helper ids, a document
checksum followed by the character offset of the tag in the `.cshtml`.
The checksum part equals ours from the CRLF checkout (version 2), not
from the LF one (version 4), so the shipped source was CRLF; on that
same text the shipped offsets are smaller (15314 against our 15457,
19129 against 19226), so the shipped build counted positions
differently.

`[I]` The VMR builds aspnetcore against the Razor compiler it has just
built from `src/razor`; our standalone inner build restores the Razor
compiler version pinned in `eng/Versions.props`. A newer Razor compiler
normalises line endings when it computes positions. This is the second
instance of the standalone-VMR deviation, in a tool rather than an
attribute. Not confirmed against the VMR's build logic.

### 6. Optimization data: nothing in the bytes

`[V]` Under version 1 both msbuild builds died restoring Microsoft-internal
tools for Arcade's optimization-data step (`VisualStudio.AcquireOptimizationData`,
401 on the devdiv feed, "Internal tool not found"). Under version 2
(`EnableNgenOptimization=false`) Microsoft.Build 17.11.48 came out at
level 3 and Microsoft.Build.Framework 18.0.2 at level 4 for reading 4
only.

`[I]` The step the public cannot run does not change the shipped
managed bytes of these two assemblies. The plan expected merged
optimization data to show as level 4 with equal IL; it did not.

### 7. Toolchain and feed results (the method's own limits)

- `[V]` clang 23.1.3 rejects the native shims of dotnet/runtime at 9.0.0,
  8.0.10, 8.0.1, 8.0.0, 7.0.0 and 6.0.0 (C-to-C++ compatibility
  diagnostics raised as errors, `-Wswitch-default`, `_Static_assert`);
  9.0.11 and the .NET 10 sources compile. Version 3 builds the managed
  subsets only (`libs.sfx+libs.oob`, .NET 5 and 6: `libs.ref+libs.src[+libs.packages]`);
  the README's `/p:BuildNative=false` is documented but consumed by no
  project file at 9.0.0. `[I]` The newer compiler, not an older one,
  rejects the sources: the toolchain the build scripts assume is pinned
  nowhere.
- `[V]` dotnet/runtime generates the out-of-band packages only with
  `BuildAllConfigurations=true` (`eng/packaging.targets`, .NET 6 to 9);
  the official pipeline packs them in a `Libraries_AllConfigurations`
  leg on `windows_x64`. Version 1's `libs -pack` built 9.0.11 cleanly
  and packed nothing in scope. The .NET 8 servicing commits pack their
  changed packages through csproj authoring (`GeneratePackageOnBuild`,
  `ServicingVersion`), present at the commits in scope.
- `[V]` The aspnetcore 8.0 tree builds its npm projects in every build
  when `node` is on PATH, and its pinned `eslint-plugin-jsdoc` refuses
  Node 26; with Node 18.20.8 (nodejs.org, sha256 checked) first on PATH
  the two HealthChecks packages reach level 3. The 9.0 tree accepts
  Node 26.
- `[V]` The .NET 5 SDK aborts on this machine ("No usable version of
  libssl was found", OpenSSL 3 only). Expectation 1 as written.
- `[V]` In invariant-globalization mode the .NET 7 SDK fails every
  project with `NETSDK1188` (satellite resource locales) under `--ci`;
  the SDK starts on ICU 78 without the variable. Version 4 limits the
  variable to .NET 5. The .NET 6 SDK showed no such check.
- `[V]` Two builds stop at a build-tool package that is no longer on
  the feeds (NU1603 as error): symreader 2.0.0
  (Microsoft.DotNet.NuGetRepack.Tasks 8.0.0-beta.23226.4) and aspnetcore
  6.0.24 (Microsoft.DotNet.Build.Tasks.VisualStudio 6.0.0-beta.23408.5).
  `[I]` Feed retention of Arcade's tool packages is a hard limit of
  rebuilding older releases from their scripts.
- `[V]` Arcade's `eng/common/tools.sh` exits 0 after "Build failed" in
  `--ci` mode by design and writes `##vso[task.complete result=Failed;]`
  instead. The scripts now read that marker (see script faults).

### 8. Expectations of the plan, checked

1. Partly: aspnetcore 9.0.0, efcore, reverse-proxy and (under version 2)
   msbuild built and packed; symreader did not (feed retention); the
   .NET 8 and 9 runtime builds needed version 3, and .NET 6 and 7 built
   under it as well; .NET 5 failed as expected.
2. Held in spirit: level 3, not 2, everywhere a package reached level 3
   (PDB checksum and MVID differ in every one). The specific mechanism
   predicted (generated assembly-info files) was not read; the newline
   carriers found are in reading 2.
3. Held: no row differs in a version attribute; the file versions
   matched wherever compared, so the build-id decoding (R4) is consistent
   with the shipped file versions (the decoding admits two ids per
   package; consistency, not proof: softened 28/10 08:10).
4. Held, and it is the cause of readings 1 and 5.
5. Not held: Roslyn's eight packages are level 4 for reading 3, not the
   compiler.
6. Unchanged.

## Script faults found during the night (fixed, affected builds rerun)

- aspnetcore's shared-framework step failed (missing submodules) and
  the pack steps ran anyway: submodules are now checked out and the
  steps chained with `|| exit 1`. Rerun: aspnetcore 9.0.0.
- Arcade's `--ci` exit code (reading 7): `repo-build.py` reads the
  failure marker; the aspnetcore multi-step command wraps each step.
  Reruns: aspnetcore 6.0 and 8.0 in version 1.
- Roslyn's build script has no `-nobl` and Arcade refuses a `--ci`
  build without a binary log: `-bl`. Rerun: Roslyn.
- `level.py` let a differing `managed resources` line through as level
  3 (it checked labels starting with `resource`). Fixed at 01:30; every
  stored row of every batch was re-derived from its saved reports: the
  release-only batches and version 1 unchanged, version 2 24 rows and
  version 3 2 rows moved from 3 to 4. The tables above are the corrected
  ones.
- The derivation picked `src/libraries/shims/stubs/*.csproj` as four
  packages' project (rule 7, shortest path); informational only for the
  runtime recipes, fixed for version 3 onwards.
- The version-4 batch started once beside version 2 because its wait
  loop got a wrong pid; killed within a minute of noticing, nothing
  recorded from it, restarted behind the reruns.

## Caveats and not tested

- Everything ran on Linux; the official builds ran on Windows. The
  level-4 rows that differ only in `managed resources` (reading 2) are
  expected to close on a Windows runner; not run.
- The version-1 binaries were not kept (the lab keeps one output per
  recipe); readings that compare version 1 bytes rest on the stored
  reports and comparisons.
- Readings 3 to 5 name a cause each with one confirming test still to
  run (sorted Compile items; the official `SourceRoot` set; the VMR's
  Razor compiler selection).
- Variation (a second build, A2) was not tested in this method; the
  release-only batches did that.
- The 28 packages outside Arcade repositories and the runtime packs
  (R8) are not in these numbers.
- The ten runtime rows that differ in `#~` besides the resource were
  read on the morning of 28 October (reading 2, `FieldRVA`); four of
  the ten pairs on disk are version-4 outputs, the version-3 DLLs of
  those four were not kept.

## Next

- A Windows run of the version-3 recipes (aspnetcore 9.0.0 and 8.0,
  efcore, runtime 9.0.11 and 9.0.0) on the free standard runners of this
  repository, to measure reading 2's claim.
- A sorted-Compile-items build of Roslyn or EFCore on Linux (one build)
  to confirm reading 3.
- Fold readings 1 to 7 into the thesis text as the list of inputs the
  standards' "same source, same build" assumption does not name.
