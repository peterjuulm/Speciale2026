# Repository-build method on the official host: the Windows run, 28 October 2026

Result note for the run planned in the section "Windows run of version 3"
of [2026-10-27-nupkg-repository-build-plan.md](2026-10-27-nupkg-repository-build-plan.md),
plus its "Version 5" section. The version-3 recipes of the 16 standalone
Arcade repositories were built on GitHub-hosted `windows-2022` standard
runners of this repository (free on a public repository), one job per
recipe, all in parallel, from 07:12 CET; four recipes were rerun at 07:14
after a script fault, Roslyn once more at 07:47 under version 5. The
artifacts were downloaded and classified on arch with the same `level.py`
as every earlier batch (`collect-runner.py`). Everything measured is in
`dependencies/data/2026-10-28-nupkg-repository-build-windows/` (and
`…-windows-v5/` for Roslyn under version 5): `results.tsv`, `run.log`,
`kommando.txt`, and per recipe under `arch/` the build log, the toolchain
record, the package comparison and the two DLL reports each level was
derived from.

The levels are unchanged: 1 identical; 2 only signature-related bytes
differ; 3 same IL, metadata streams and managed resources, build identity
(MVID, timestamp, PDB) differs; 4 anything else.

## What ran

| run | recipes | started | what |
|---|---|---|---|
| 40642458858 | the 16 standalone recipes of the Windows set | 07:12 | version 3 on `windows-2022` |
| 40642659531 | msbuild ×2, reverse-proxy, symreader | 07:14 | rerun after the `-restore -build` fault (below) |
| 40645930765 | roslyn-6c4a46a | 07:47 | version 5 (no stabilising properties) |

Not run on Windows: the four VMR inner builds (`dotnet-*`, 54 packages):
a `dotnet/dotnet` clone and build does not fit a 4-core runner with a
14 GB work disk. Their results stay those of the Linux batches.

`[V]` the runs and their jobs: `run.log` and
`https://github.com/peterjuulm/Speciale2026/actions/runs/<run>`.
Build times on the runner: aspnetcore 6 to 10 min, runtime 8.0.x 12 to
18 min, runtime 9.0.11 17 min, Roslyn 28 min (one 4-core runner each).

## Result

`[V]` `results.tsv` of the Windows set (34 rows from 15 recipes; the
runtime 9.0.0 job, 8 rows, is added below when it lands).

| state | rows |
|---|---|
| level 2 | 19 |
| level 3 | 4 |
| level 4 | 8 (Roslyn, version 3; the same 8 are level 2 under version 5, next section) |
| no package | 3 (symreader; the two Razor 6.0.24 packages) |

Per package, the Linux best level against Windows:

| package | Linux best (version) | Windows |
|---|---|---|
| Microsoft.Extensions.Diagnostics.HealthChecks, .Abstractions 8.0.0 | 3 (v3) | 2 |
| Microsoft.AspNetCore.Authentication.JwtBearer, .OpenIdConnect, DataProtection, DataProtection.Abstractions 9.0.0 | 3 (v1) | 2 |
| Microsoft.Extensions.DependencyModel 8.0.2 | 4 (v3, v4) | 2 |
| System.IO.Packaging 8.0.1, System.Memory.Data 8.0.1 | 4 / 3 | 2 |
| Microsoft.Bcl.TimeProvider 8.0.1 | 4 | 2 |
| Microsoft.Bcl.AsyncInterfaces 8.0.0, System.Reflection.MetadataLoadContext 8.0.0 | 3 / 4 | 2 |
| System.IO.Hashing 6.0.0 | 3 | 2 |
| System.Configuration.ConfigurationManager, System.Diagnostics.EventLog, System.Security.Cryptography.Pkcs, .ProtectedData 9.0.11 | 4 / 4 / 4 / 3 | 2 |
| Microsoft.Build.Framework 18.0.2 | 4 (source-root index) | 2 |
| Yarp.ReverseProxy 2.1.0 | 4 | 2 |
| Microsoft.Build 17.11.48 | 3 | 3 |
| System.CodeDom 6.0.0 | 4 | 3 |
| System.IO.Hashing 7.0.0 | not built (v3), 3 (v4) | 3 |
| System.IO.Ports 5.0.0 | no package (SDK needs OpenSSL 1.1) | 3 |
| Microsoft.CodeAnalysis ×8 5.0.0 | 4 (type order) | 4 under version 3 (version string); 2 under version 5 |
| Microsoft.DiaSymReader 2.0.0, Razor.Language and CodeAnalysis.Razor 6.0.24 | no package | no package |

`[V]` each Linux level from the `results.tsv` of the respective batch,
each Windows level from this batch's.

The `build` column says "did not build (exit 1)" for seven recipes whose
packages were nevertheless produced and compared; the failures come
after packing (reading 5).

## Readings

### 1. The build identity follows the host

`[V]` For every level-2 row, the shipped and the rebuilt DLL have the
same MVID, PE timestamp, PDB GUID and PDB checksum, and the same
strong-name signature bytes (HealthChecks 8.0.0:
`mvid 697f69be-7ba4-476d-833c-773ca0f08c6c`, PDB guid
`1d503fd5-…`, in both `arch/aspnetcore-3f1acb5/…/level/report-*.txt`).
The only differing lines are `authenticode`, `pe checksum`, `size`,
`sha256`, `file`. On Linux the same recipes gave different MVID,
timestamp and PDB identity for the same IL (version 3,
`…-v3/arch/aspnetcore-3f1acb5/…/level/`).

`[V]` (08:02) Level 2 checked on the whole file, not on report lines:
`stripsign.cs` zeroes the PE checksum, cuts the Authenticode block and
its directory entry, zeroes the strong-name signature bytes, and hashes
the rest. All 19 level-2 pairs hash equal
(`signature-stripped.txt` in the data folder); Microsoft.Build 17.11.48
(level 3) differs from byte `0x88`, the PE timestamp.

`[I]` The deterministic compiler's identity hash includes something the
host supplies, and on the official host it is the official value. The
plan's prediction of 07:40 ("the level-3 rows stay at level 3 because
the PDB's compiler record names a different runtime build") was wrong
and stands corrected: the Linux level-3 rows were a host effect, not a
toolchain-record effect. What the host contributes to the hash is not
read here; it is the next thing to read for the four rows that stay at
level 3 on Windows (reading 4).

### 2. The newline rows close

`[V]` Every package that was level 4 on Linux with only the generated
resource differing (reading 2 of the Linux note), or with that resource
and the `FieldRVA` addresses it shifts, is level 2 on Windows: the
8.0.x and 9.0.11 runtime packages, HealthChecks, DependencyModel. The
runtime 6.0 and 8.0 builds that failed on Linux in the `AsnXml.targets`
newline check exit 0 on Windows.

`[I]` As predicted: the build host's newline was the whole of those
rows, and the official build ran on Windows.

### 3. The glob-order rows close, and one more input appears

`[V]` Roslyn under version 3 on Windows: the eight packages stay at
level 4, but `il bodies`, `#Strings` and `#US` no longer differ; the
type and method tables are in the shipped order
(`arch/roslyn-6c4a46a/…/level/report-*.txt`, differing lines
`#~, #Blob, section .rsrc, section .text` and identity). `tabledump.cs`
on Microsoft.CodeAnalysis.Common: `CustomAttribute` blob indices and
`FieldRVA` differ, nothing else in `#~`. The one attribute that differs
is the informational version: shipped
`5.0.0-2.25567.12+6c4a46a…`, ours `5.0.0+6c4a46a…`; the version
resource (`.rsrc`, 20 bytes) carries the same string.

`[I]` The Windows walk reproduces the shipped type order, which confirms
reading 3 of the Linux note: the order of source files from the glob is
an OS-dependent input. What remains is a version-string input of a new
kind: Roslyn's official pipeline passes `-officialBuildId` only
(`azure-pipelines-official.yml` at the commit), the assembly keeps the
prerelease label, and the package reaches nuget.org as 5.0.0 by
repacking. Our rule R4b (`StabilizePackageVersion`,
`DotNetFinalVersionKind=release`) stabilised the assembly as well.
Version 5 passes OfficialBuildId only for Roslyn; its prediction is
level 2 (result below).

### 4. Four rows stay at level 3

`[V]` Microsoft.Build 17.11.48, System.CodeDom 6.0.0, System.IO.Hashing
7.0.0 and System.IO.Ports 5.0.0 differ in identity only (MVID,
timestamp, PDB guid and checksum; Microsoft.Build:
`arch/msbuild-02bf662/…/level/`).

`[V]` (08:10) Microsoft.Build ships its portable PDB in the package
(`lib/net8.0/Microsoft.Build.pdb`, both sides). `pdbdump.cs` on the two
(`arch/msbuild-02bf662/Microsoft.Build-17.11.48/pdb-*.txt`): 585
documents with the same hashes, the same source link, the same metadata
references (9452 bytes, equal), and one differing field in the compiler
record: `runtime-version 4.8.9315.0` shipped, `4.8.9363.0` ours. The
PDB id differs, and with it the CodeView entry, the MVID and the
timestamp of the DLL.

`[I]` msbuild builds with the Visual Studio engine, so its compiler runs
on the host's .NET Framework, and the compiler writes that runtime's
version into the PDB; the identity hash covers the PDB. The official
agent had .NET Framework 4.8.9315, the runner image 4.8.9363. One more
input that no release record names: the patch level of the runtime
under the compiler, which the repository-pinned SDK fixes for the
level-2 rows (their compiler ran on the SDK's own runtime) and the
desktop engine does not. Reading 6 of the Linux note stands: with the
PDB field as the only difference, optimization data left nothing in the
bytes. CodeDom 6.0.0, IO.Hashing 7.0.0 and IO.Ports 5.0.0 ship no PDB in
the package and nuget.org has no symbols package for them; not read.

### 5. What the Windows builds themselves said

- `[V]` Arcade's `build.cmd` already passes `-restore -build` to
  `eng/common/build.ps1`; PowerShell refuses a switch given twice. The
  first jobs of msbuild, reverse-proxy and symreader failed on that
  (`run.log` 07:12); `derive-repo.py` now adds only the flags the entry
  script lacks, and the four were rerun.
- `[V]` msbuild (both commits) and Roslyn pack their packages and then
  fail in `VisualStudio.BuildIbcTrainingInputs.targets`: "Properties
  VisualStudioDropName and RepositoryName must be specified in official
  build that produces Visual Studio insertion components". An
  `OfficialBuildId` makes these repositories' Windows builds expect the
  VS insertion pipeline. Packages unaffected.
- `[V]` reverse-proxy packs Yarp and then fails in `docfx` (MSB3073).
- `[V]` runtime 7.0.0 (d099f07) under version 3 carries invariant
  globalization and fails with NETSDK1188 on Windows exactly as on
  Linux; the package was produced anyway (level 3).
- `[V]` symreader and aspnetcore 6.0.24 fail at restore on Windows as on
  Linux: NU1603 for Arcade tool packages that have left the feeds.
- `[V]` The runtime 9.0.0 job (runtime-9d5a6a9) stayed in its build step
  for two hours where 9.0.11 took 17 minutes; cancelled at 09:15, its
  log (879 lines, uploaded on cancel) ends after the IL build of
  System.Private.CoreLib with no error. Not read further; the recipe was
  started again at 09:16 (its rows and run id are in `results.tsv` and
  `run.log` once collected).
- `[V]` System.IO.Ports 5.0.0 builds on Windows (the .NET 5 SDK runs
  there without OpenSSL 1.1) and packs; level 3.

## Version 5 (Roslyn without the stabilising properties)

`[V]` Run 40645930765 (07:47 to 08:09), data
`dependencies/data/2026-10-28-nupkg-repository-build-windows-v5/`: all
eight Microsoft.CodeAnalysis packages at level 2, and whole-file equal
with the signatures removed (`signature-stripped.txt`, eight pairs,
2.2 to 6.8 MB each). The build packed them as
`microsoft.codeanalysis.*.5.0.0-2.25567.12.nupkg`; the comparison took
the DLL from that package (`results.tsv`, note column). The build still
exits 1 after packing (the VS insertion targets, reading 5).

`[I]` The prediction of the plan's version-5 section held. The shipped
Roslyn DLLs are the bytes of a prerelease build; the release version
exists only in the package name and nuspec, written by a repack step
after the build. "Release" is therefore not one thing across Arcade
repositories: runtime and aspnetcore build with the release version
kind, Roslyn repacks. For the catalogue this is one input (the route by
which the version string reaches the assembly) with two values, and the
release names neither.

## Caveats and not tested

- The VMR inner builds (54 packages) were not built on Windows.
- Four level-3 rows are not read (reading 4).
- One build per package: A against A2 was not measured on the runner.
- The first version-5 derivation ran without the flag (a patch that had
  not applied) and its job was cancelled within a minute; the recipes
  were regenerated and the job restarted (commit history 07:45 to 07:47).
