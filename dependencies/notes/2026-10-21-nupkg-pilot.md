# Nupkg test pilot: Cronos 0.9.0

Run 21 October 2026 on `mac`. First build of the
[nupkg test plan](2026-10-21-nupkg-test-plan.md). Phoenix commit `79cb67a7`
ships `Cronos` 0.9.0, `lib/net6.0/Cronos.dll`.

Data: `dependencies/data/2026-10-21-nupkg-pilot/mac/`.

## Question

Built from its declared commit with its declared compiler, does Cronos 0.9.0
give the `lib/net6.0/Cronos.dll` that is on nuget.org, once the signature is
removed? Are two of our builds the same?

## What Cronos declares

Read before the build, 21/10.

| Part | Value | Source |
| --- | --- | --- |
| Source | `HangfireIO/Cronos` at `14ca2b14` (tag `v0.9.0`) | `.nuspec` `[V]` |
| Compiler | Roslyn `4.12.0-3.24523.4+f3348c2a`, run by .NET runtime `9.0.0` | PDB compiler record `[V]` |
| SDK | **9.0.100**: the only SDK with Roslyn `f3348c2a`. 9.0.101 has `913fb4ec`, 9.0.102 `dfa7fc6b` | `dotnet/sdk` `eng/Version.Details.xml` at each tag `[V]` |
| Options | Release, AnyCpu, C# 10, unsafe, the `NET6_0` defines | PDB compiler record `[V]` |
| Build path | `C:\projects\cronos\`, not mapped: `DeterministicSourcePaths=false` under AppVeyor | PDB documents; `src/Directory.Build.props` `[V]` |
| Line endings | LF: the PDB's SHA-256 of each source file matches the LF file, not CRLF | 4 files checked by hand `[V]` |
| Build command | `dotnet restore --locked-mode`, then `dotnet build --no-restore -c Release` on the solution, with `APPVEYOR=True` | `appveyor.yml`, `build.bat`, `Hangfire.Build` 0.5.0 `psake-common.ps1:38-52` `[V]` |
| Version stamp | None: `GenerateAssemblyInfo=false`, `AssemblyVersion("0.9.0")` in the source | `src/Directory.Build.props`, `src/SharedAssemblyInfo.cs` `[V]` |
| Host | AppVeyor image "Visual Studio 2022" (Windows) | `appveyor.yml` `[V]` |
| Signature | Authenticode, added after the build (SignPath). No strong name | census `[V]` |

The Mac cannot build at `C:\projects\cronos\`. Our build therefore adds
`PathMap` from its own directory to that path. This is the one value we add
that the original build did not have.

## Expectation (written before the run)

`[I]` all of it. Written by Claude for Peter before the first build.

1. With SDK 9.0.100, `APPVEYOR=True` and the `PathMap`, our
   `lib/net6.0/Cronos.dll` is byte-identical to nuget.org's once the
   Authenticode signature and the PE checksum are removed.
2. Our two builds, in two directories, are byte-identical.
3. Without the `PathMap`, the DLL differs only in the embedded PDB (document
   paths) and in the values that hash the PDB (PDB ID, `PdbChecksum`).

## Commands

From the root of Speciale2026, on `mac`, 21/10. Verbatim in `kommando.txt`.
The scripts are `dependencies/experiments/nupkg-test/cronos.sh` (clone at the
commit, `restore --locked-mode`, `build -c Release`, under `env -i` with
`APPVEYOR=True`) and `pe.py` (remove the Authenticode table and the PE
checksum; take out the embedded PDB). The PDBs were read with
`experiments/pdbdump`, the bytes mapped with `experiments/pe-diff-regions.py`.

    S=/private/tmp/rb1-sdks/9.0.100; L=/private/tmp/rb1-nupkg; T=dependencies/experiments/nupkg-test
    bash $T/cronos.sh $L/cronos-a $S pathmap   > $L/cronos-a.log 2>&1
    bash $T/cronos.sh $L/cronos-b $S pathmap   > $L/cronos-b.log 2>&1
    bash $T/cronos.sh $L/cronos-c $S nopathmap > $L/cronos-c.log 2>&1

Build c failed the first time on a defect in the script (an empty array under
`set -u` in macOS's bash 3.2), before `dotnet build`. Fixed and run again.

## Result

All three builds succeeded. The DLLs, signature and checksum removed (sha256,
`results.txt`):

| DLL | sha256 | Size |
| --- | --- | ---: |
| nuget.org | `adc6e8d7…` | 38912 |
| a (`PathMap`) | `6230712f…` | 38912 |
| b (`PathMap`, other directory) | `6339f6da…` | 38912 |
| c (no `PathMap`) | `cd79878b…` | 38912 |

**a against b.** 10284 bytes differ: 10212 in the embedded PDB, the rest in
values that hash it (MVID, PDB ID, timestamp, `PdbChecksum`). The PDBs differ
in one line only: the Source Link JSON maps the build directory,
`/private/tmp/rb1-nupkg/cronos-a/src/*` or `…/cronos-b/src/*`. `PathMap` does
not reach it. `[V]`

**nuget.org against a.** 10823 bytes differ. In the PDBs, three things
differ, and nothing else in `pdbdump`'s output `[V]`:

1. The document paths: nuget.org has `C:\projects\cronos\src\Cronos\…`, ours
   `C:\projects\cronos\` followed by `src/Cronos/…`. `PathMap` replaces the
   start of a path and keeps the rest of its separators.
2. The Source Link JSON: `C:\\projects\\cronos\\*` against our directory.
3. The file MSBuild generates, `.NETCoreApp,Version=v6.0.AssemblyAttributes.cs`:
   hash `f55a8701…` against `7897e595…`. Our file with every line ending
   turned into CRLF hashes to `f55a8701…`.

The 11 source files have the same hashes. The compiler's reference list (8843
bytes: each referenced DLL by name and MVID) is byte-identical `[V]`. Outside
the PDB and its hashes, every differing byte is a shift: our PDB is 18 bytes
longer (the Source Link path), so the data after it moves, and with it the
`.text` size in the headers and the four `FieldRVA` rows in `#~` `[V]`.

## Interpretation

Expectations 1 and 2 failed; 3 held in part. 1: no build matched nuget.org.
2: our two builds differ, because Source Link writes the real build directory
into the PDB. They are the same build at different paths. 3: c against a
differs only through the PDB, as expected: the document paths, but also the
Source Link directory, and the data after the longer PDB moves (`results.txt`).

Every difference comes from two inputs that the package records but the Mac
cannot give: the Windows build path `C:\projects\cronos\` and Windows line
endings in a file that MSBuild writes. The source, the compiler, its options
and the references all match. `[I]` On Windows at `C:\projects\cronos\`, with
SDK 9.0.100 and `APPVEYOR=True`, the DLL would match; not run.

For the plan: a package built **without** mapped paths records its host's path
and separators in its PDB. Linux and macOS cannot write a `\` separator, so
such a package built on Windows can only be rebuilt on Windows. This corrects
what we said on 21/10 before the run, that the Mac does as well as `arch`:
true for packages with mapped paths (`/_/`), not for Cronos. Neither `mac` nor
`arch` can rebuild Cronos.

## Caveats

- The published DLL is the NuGet cache's copy, not a new download; the cache
  checked the package's hash at the restore on 13/10.
- Only `lib/net6.0` was compared, the one Phoenix ships. The other four
  targets were built but not compared.
- The CRLF cause is shown by hash, not by a build that writes CRLF.
- That Roslyn cannot be made to write `\` on macOS or Linux is `[I]`: we tried
  `PathMap` only.
- `pdbdump` prints 16 bytes of each custom debug blob; the reference list was
  compared in full by hand, the other blobs only by size and those 16 bytes.
