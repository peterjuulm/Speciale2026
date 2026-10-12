# Dependency plan: rebuilding Phoenix's NuGet packages

Planning note, 12 October 2026. Part 2 of the thesis. Not an experiment; each
run gets its own note. Phoenix commit `e19ca414` on `thesis/reproducible-builds`.
The first step, the census, ran the same day:
[data](../data/2026-10-12-dependency-census/mac/census.md).

## The question

Can we rebuild each NuGet package that Phoenix's release ships from the source
it declares, in the environment it declares, and get the bytes that are on
nuget.org?

## Decisions

1. **Scope.** What the Linux release ships: 391 packages. The exact rule and
   every package left out are in [Scope](#scope) below.
2. **Two tests.**
   - **Test B, the main test:** build the package from its declared commit and
     compare with the package on nuget.org.
   - **Test A, extra:** run reprotest on our own build of the package. This is
     what Benedetti et al. did.
3. **Environment.** We use only what the package declares. NuGet has no
   buildinfo file. The `.nuspec` can declare the repository and commit; the
   PDB can declare the compiler, its options and its references. Nothing
   declares the SDK, MSBuild or the OS. If it is not declared, the package is
   not reproducible.
4. **No sample.** We try every package. The packages with a commit come from
   104 repository+commit pairs, so that is the number of builds. Microsoft's
   packages are included.
5. **A failure is a result.** We mark the package "not reproducible" and record
   where it stopped (category below) and who could fix it (Benedetti et al.'s
   Fig. 3: as is, configuration, tool patch, external).
6. **What we compare.** The DLLs and PDBs that the release ships, with
   Authenticode and strong-name signatures removed. Not the `.nupkg`, which
   nuget.org signs.
7. **Machines.** The census runs on `mac`. Builds and reprotest run on `arch`.
8. **Dropped.** Checking package hashes against the lock file. NuGet already
   does it in locked mode, which Phoenix uses in CI
   (`Directory.Build.props:43-44`).

## Scope

**The rule:** a package is in if the release ships it. The release is the
self-contained `linux-x64` publish of the two programs, `WebAPI` and
`BackgroundJobExecutor` (`.github/workflows/03-release.yml:292,295`).

| | Packages | Why |
| --- | ---: | --- |
| **In:** the two programs' lock files | 388 | The full graph of each program: 85 direct, 303 transitive |
| **In:** runtime and host packs for `linux-x64` | 3 | A self-contained publish copies the .NET runtime into the release. The SDK downloads these packs; they are not in any lock file |
| **In, total** | **391** | One row each in [census.md](../data/2026-10-12-dependency-census/mac/census.md) |
| Out: only in a library's lock file | 7 | `ApplicationCore` and `Infrastructure` are compiled into the programs. The programs' graph decides the version that ships, for example `Azure.Core` 1.39.0, not 1.38.0 |
| Out: only used by `tests/` | 121 | Tests never ship |
| Out: packs for `win-x64` | 3 | The Windows release is later work (decided 5/10) |
| Out: local tools | 3 | `csharpier`, `dotnet-format`: formatting only. `dotnet-ef`: makes the migration bundle; in only if we measure that bundle |
| **Out, total** | **134** | One row each, with its reason, in [scope.md](../data/2026-10-12-dependency-census/mac/scope.md) |
| Out, not NuGet | | The frontend's npm packages (layer 3), and the .NET SDK, which is the toolchain (recorded by its `csc.dll` hash) |

**The two lists are not in git.** `census.md`, `census.csv` and `scope.md`
name every package and version Phoenix ships, and this repo is public (decided
12/10). Make them again from the Phoenix commit with the command in
[kommando.txt](../data/2026-10-12-dependency-census/mac/kommando.txt).

Notes on the counts:

- "Direct" means named in one of our own `.csproj` files, the libraries'
  included: 84 names, 85 versions (`SkiaSharp.NativeAssets.Linux.NoDependencies`
  ships as 3.119.0 and 3.119.2, one per program).
- 57 packages are in scope but ship no file for `linux-x64` (category N0):
  meta packages, packages for other platforms, and build-time packages such as
  analyzers and `Microsoft.EntityFrameworkCore.Tools`. They stay on the list,
  with nothing to compare.
- Check: 388 + 7 + 121 = 516, the packages in all five lock files `[V]`.

## Categories

A package goes in the first category that fits.

| Id | Category | Test B possible? |
| --- | --- | --- |
| N0 | Ships no files (meta package, build-time only) | Nothing to compare |
| N1 | Native code only | Scope open |
| C1a | No repository declared | No |
| C1b | Repository, but no commit | No |
| C2a | No PDB at all | No compiler declared |
| C2b | PDB not in the package (maybe on a symbol server) | Unknown until we look |
| C2c | PDB in the package, but no compiler record | No compiler declared |
| R | Commit and compiler both declared | Yes |
| C3 | Declared, but does not build | After a build |
| C4 | Builds, but the bytes differ (say where) | After a build |

## Steps

1. **Census** (done 12/10, `mac`): read every package's `.nuspec` and DLLs. No
   build, no network.

   | | N0 | N1 | C1a | C1b | C2a | C2b | C2c | R | Total |
   | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
   | Microsoft | 51 | 7 | 17 | 1 | 1 | 148 | 0 | 21 | 246 |
   | Third-party | 6 | 2 | 7 | 11 | 45 | 39 | 2 | 33 | 145 |

   The first run the same day used all four `src` lock files (395) and missed
   the runtime packs. The run above replaces it.

2. **Symbol servers** for the 187 C2b packages: get the PDBs from nuget.org's
   and Microsoft's symbol servers. Ask before downloading.
3. **Test B on the R packages** (54 now, more after step 2), on `arch`.
4. **Test B on the rest** that have a commit.
5. **Test A** on every package that builds, on `arch`.

## Expectations (draft, Leo and Peter confirm before the first build)

Written before any build. `[I]` until measured.

- After step 2, most C2b packages move to R. Microsoft and the large projects
  publish `.snupkg` files.
- Of the R packages, the third-party projects with Source Link and
  `ContinuousIntegrationBuild` match after signatures are removed. The
  mismatches are reference versions and paths.
- The Microsoft builds mostly stop at C3: Arcade, size, internal feeds.
- Test A is green wherever test B is green. A package that matches nuget.org
  was already built deterministically once.

## Open

- **Native code (N1, 9 packages).** In scope or "vendor bytes"? SQLite is
  small enough to be one native example.
- **`mac` as a second machine for test B.** Line endings and the
  case-insensitive file system could show up here.
- **BuildValidator.** Use it to test the compile step alone?
- **17 packages give a redirect as their repository** (`go.microsoft.com/fwlink`,
  for example SkiaSharp). Five of them are R. A redirect is not a repository.
- **The 45 Humanizer language packs are C2a.** They hold only resources, no
  code. Does C2a fit them, or are they N0?
- **Analyzers** (N0) run inside Phoenix's own compile but do not ship.

## Issues considered

The points we discussed on 12/10 before we decided the plan.

**Determinism is not reproducibility.** reprotest compares two of our own
builds (test A). It cannot tell if our build matches what the publisher
uploaded (test B). Test B is the supply-chain question.

**Benedetti et al. did only test A.** They built each repo's latest commit and
did not compare with the published package (Section III-C). Their reasons:
finding the right commit is hard, and environments differ. Test B is new
relative to their study.

**We cannot discard packages.** Benedetti et al. replaced a package with no repo
or a failed build by a new random one. Our population is Phoenix's graph, so we
count those packages instead.

**NuGet declares almost nothing about the build.** Only the repository and
commit (`.nuspec`) and the compiler record (PDB). No SDK, no MSBuild, no OS.
Benedetti et al. recommend that package managers publish buildinfo files.

**The version number is not the compiler.** "9.0.120" covers three different
`csc.dll` files (9/9). The PDB records the Roslyn version and commit, so we use
that.

**Where the PDB is decides what we know.** A PDB can be embedded in the DLL,
inside the `.nupkg`, on a symbol server (`.snupkg`), or missing. Most packages
(187) keep it outside the package, so the census must look on symbol servers.

**Signatures cannot be reproduced.** nuget.org signs every `.nupkg`
(`.signature.p7s`). Microsoft and some others sign DLLs with Authenticode or
a strong name. We have none of these keys, so we compare without signatures.

**The content hash is not the file hash.** The `sha512` in the lock file,
`project.assets.json` and `deps.json` is NuGet's content hash. For Serilog
4.2.0 it is `gmoWVOvK…`; the `.nupkg` file hashes to `5uMzWjAZ…` `[V]`. I think
NuGet leaves the signature out of the content hash `[I]`. The layer plan's step
"compare with the `.nupkg` hashes" would therefore fail on every signed package.

**The lock file only proves "the same as last time".** Locked mode stops a
build if a package changes. It cannot show that the package matches its
source. Test B does.

**`deps.json` is a run-time file, not a lock file.** The .NET host reads it at
start to find assemblies. The layer plan says the host does not check its
`sha512` `[I]`, not tested.

**`dotnet build` does not reach native code.** It copies `.so` files from the
cache. Rebuilding them needs each library's own C/C++ build.

**Microsoft's builds are expensive.** Large repos, the Arcade build scripts,
and signing. Included anyway; a failure goes in C3 with its cause.

**Our "never build inside git" rule conflicts with test B.** The publisher
built inside a clone, so the commit is in `AssemblyInformationalVersion` and
in Source Link. To match, we must build inside a clone at the declared commit.
This is a deliberate exception.

**The Mac can leak into the bytes.** One empty class gave the same bytes on
macOS and Linux (9/9). A real project can still differ by line endings or file
name case `[I]`.

**Earlier counts included the tests.** The 94 direct and 408 transitive (502)
in the layer plan come from `tools/dependency-graph`, which reads `tests/` too
(`tools/dependency-graph.js:89`) `[V]`. With today's lock files, `src` plus
`tests` gives 94 direct and 516 in total; that the 15/9 graph is smaller
because packages were added since is `[I]`.

**Not every lock file ships.** The two libraries have their own lock files, and
these can resolve another version than the programs do. Only the programs'
graph ships. A first census counted all four `src` lock files (395) and was
corrected the same day.

**A self-contained release ships the runtime.** The runtime packs come from
NuGet but are in no lock file. Layer 2 found that 323 of WebAPI's 746 files are
copies from them (W21). Without them, the scope would miss the largest part of
the release.

## Terms introduced on 12/10

**Concepts**

- **Test A / test B:** determinism under variation / rebuild matches nuget.org.
- **Census:** reading what each package declares, before any build.
- **Stratified sample:** a few items from each group, so the sample represents
  the whole. Not used: we test everything.
- **Declared environment:** what a package itself says about how it was built.
- **buildinfo:** a file that records a build's environment (Debian has one;
  NuGet does not).
- **Compiler record:** the compiler version, options, defines and references
  that Roslyn writes into a portable PDB.
- **MVID:** the unique ID of one exact DLL. In a deterministic build it is a
  hash of the content.
- **Symbols / symbol server:** in .NET, "symbols" means the PDB. A symbol
  server stores PDBs and finds them by the ID in the DLL.
- **CodeView entry:** the record in a DLL that names its PDB and the PDB's ID.
- **Embedded PDB:** a PDB stored inside the DLL.
- **Reproducible entry:** a debug entry that shows the DLL was built with
  `/deterministic`.
- **PdbChecksum entry:** a debug entry with a hash of the whole PDB. It proves
  that a PDB belongs to this DLL.
- **Source Link:** a map in the PDB from each source file to a URL at the
  exact commit.
- **Content hash:** NuGet's hash of a package, in the lock file and
  `deps.json`. Not the hash of the `.nupkg` file.
- **Locked mode:** a restore that fails if the graph or a hash differs from the
  lock file (`NU1403` for a hash `[I]`).
- **Authenticode:** a Windows code signature inside a DLL.
- **Strong name:** a .NET signature that is part of an assembly's identity.
- **Repository signature:** nuget.org's signature on every `.nupkg`.
- **IL / native code:** .NET bytecode from Roslyn / machine code from a C or
  C++ compiler.
- **P/Invoke:** how a .NET DLL calls a native library.
- **Native assets:** the `.so`, `.dylib` or `.dll` files under
  `runtimes/<rid>/native/`.
- **Satellite assembly:** a DLL with only translated resources, for example the
  Humanizer language packs.
- **Meta package:** a package with no files of its own, only dependencies.
- **Analyzer:** a DLL that runs inside the compiler during a build and does not
  ship.

**Files**

- `.nuspec`: the package manifest; can declare `<repository url commit>`.
- `.nupkg`: the package, a zip.
- `.snupkg`: a symbol package, PDBs only, for the symbol server.
- `.signature.p7s`: nuget.org's signature, inside the `.nupkg`.
- `<id>.<version>.nupkg.sha512`: in the NuGet cache, the hash of the `.nupkg`
  file.
- `.nupkg.metadata`: in the NuGet cache, the content hash and the source feed.
- `packages.lock.json`: the locked graph, with a content hash per package.
- `obj/project.assets.json`: what restore resolved, and which files each
  package gives each target.
- `bin/…/<app>.deps.json`: the host's list of what to load at run time.
- `.config/dotnet-tools.json`: local .NET tools (`dotnet-ef`, `dotnet-format`,
  `csharpier`).

**Tools**

- **reprotest:** builds twice with variations and compares (test A).
- **Roslyn:** the C# compiler, `csc.dll`.
- **BuildValidator:** a tool in the Roslyn repo that reads a DLL and its PDB,
  compiles the sources again with the recorded options, and compares. It uses
  the library `Microsoft.CodeAnalysis.Rebuild`. Only the compile step; no
  MSBuild.
- **Arcade:** Microsoft's shared build scripts for its .NET repos.
- **NuGet Package Explorer / `dotnet-validate`:** check a package for Source
  Link, deterministic build and PDBs `[I]`, not run.
- **`experiments/dep-census/census.py`:** our census script.
- **`tools/dependency-graph.js`:** Phoenix's script that counted the graph on
  15/9.
