# Dependency plan: rebuilding Phoenix's NuGet packages

Planning note, 12 October 2026, rewritten 13 October for .NET 10. Part 2 of
the thesis. Not an experiment; each run gets its own note. Phoenix commit
**`79cb67a7`** on `thesis/reproducible-builds` (.NET 10). The census:
[data](../data/2026-10-13-dependency-census/mac/census.md).

The first version of this plan and its census measured the .NET 9 commit
`e19ca414`. Phoenix moved to .NET 10 on 13/10 and only .NET 10 is tested, so
that data was removed (decided 13/10, Peter); it is in git history, commit
`a03fe66`.

## Phoenix on .NET 10

Leo merged main into the WS branch and moved it to .NET 10
([phoenix-merge-main](2026-10-13-phoenix-merge-main.md),
[phoenix-net10-release](2026-10-12-phoenix-net10-release.md)). What matters
for this plan `[V]`:

- **SDK `10.0.401`**, `rollForward: disable`. Every workflow installs it from
  `global.json` (`deaf3090`).
- **Three programs ship, not two.** The release also publishes the database
  migrator, `src/DbMigrator`, self-contained for `linux-x64`
  (`03-release.yml:106-108`).
- **`dotnet-ef` 10.0.12 is in scope** (decided 13/10, Peter). It writes the
  idempotent SQL script that ships in the release's `db/`
  (`03-release.yml:137`).
- **Many Microsoft packages come from `dotnet/dotnet`**, Microsoft's
  combined repository for .NET 10: 62 packages, among them the runtime packs and
  `dotnet-ef`, at two commits.

How the census was run on `mac`, and one finding on the way (details in the
run's `environment.txt`):

- SDK 10.0.401 installed in `~/.dotnet` with Microsoft's `dotnet-install.sh`.
- Restored in a `git archive` export of `79cb67a7`, not in the worktree.
- **`DbMigrator` cannot restore in locked mode on macOS.** It sets
  `PublishSingleFile` without a single runtime, so the SDK adds the host's
  runtime (`osx-arm64`) and the lock file no longer matches (`NU1004`) `[V]`.
  On Linux and in CI the host runtime is already in the list. In the export it
  was restored unlocked; its `net10.0`, `linux-x64` and `win-x64` lock sections
  stayed identical to the commit's `[V]`. For Leo: a candidate W finding.

## The question

Can we rebuild each NuGet package that Phoenix's release ships from the source
it declares, in the environment it declares, and get the bytes that are on
nuget.org?

## Decisions

1. **Scope.** What the Linux release ships: 341 packages. The exact rule and
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
4. **No sample.** We try every package. A build is one GitHub project at one
   exact commit, a "repository+commit pair". The 311 packages that declare a
   commit come from 104 such pairs in 80 projects (one "project" is a package
   with a commit but no repository URL; one pair's commit is not on GitHub), so
   at most 102 builds. Microsoft's packages are included.
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
9. **Official build settings** (added 13/10, Peter; Leo to confirm). Some
   values reach a DLL from the publisher's release pipeline, not from the
   source: in Microsoft's Arcade builds, the official build ID that becomes the
   file version. We take such a version stamp from the published DLL and give
   it to the build; everything else comes from the source. Every package where
   we do this is marked in its result. Debian's buildinfo files record values
   that are not in the source in the same way, so that others can repeat the
   build.

## Scope

**The rule:** a package is in if the release ships it, or if it is a tool
whose output ships. The release is the self-contained `linux-x64` publish of
the three programs `WebAPI`, `BackgroundJobExecutor` and `DbMigrator`
(`03-release.yml:106,335,338`), plus the SQL script from `dotnet-ef`.

| | Packages | Why |
| --- | ---: | --- |
| **In:** the three programs' lock files, `net10.0` and `linux-x64` parts | 337 | The full graph of each program: 85 direct, 252 transitive |
| **In:** runtime and host packs for `linux-x64` | 3 | A self-contained publish copies the .NET runtime into the release. The SDK downloads these packs; they are in no lock file |
| **In:** `dotnet-ef` | 1 | A local tool, but its SQL script ships |
| **In, total** | **341** | One row each in [census.md](../data/2026-10-13-dependency-census/mac/census.md) |
| Out: only in a library's lock file | 17 | `ApplicationCore` and `Infrastructure` are compiled into the programs. The programs' graph decides the version that ships |
| Out: only used by `tests/` | 76 | Tests never ship |
| Out: packs for `win-x64` | 3 | The Windows release is later work (decided 5/10) |
| Out: local tools | 2 | `csharpier`, `dotnet-format`: formatting only |
| **Out, total** | **98** | One row each, with its reason, in [scope.md](../data/2026-10-13-dependency-census/mac/scope.md) |
| Out, not NuGet | | The frontend's npm packages (layer 3), and the .NET SDK, which is the toolchain (recorded by its `csc.dll` hash) |

**The lists are not in git.** `census.md`, `census.csv` and `scope.md` name
every package and version Phoenix ships, and this repo is public (decided
12/10). Make them again with the commands in
[kommando.txt](../data/2026-10-13-dependency-census/mac/kommando.txt).

Notes on the counts:

- "Direct" means named in one of our own `.csproj` files, the libraries'
  included: 82 names, 85 versions.
- 29 packages are in scope but ship no file for `linux-x64` (category N0):
  meta packages, packages for other platforms, build-time packages such as
  analyzers and `Microsoft.EntityFrameworkCore.Tools`, and one package that
  .NET 10 removes from the graph because the framework contains it
  (`Microsoft.Extensions.DependencyInjection.Abstractions` 2.1.0, in WebAPI's
  lock file but not in its restore output `[I]`).
- Check: 337 + 17 + 76 = 430, the package versions in all six lock files `[V]`.

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

1. **Census: what each package declares** (done 13/10, `mac`, on
   `79cb67a7`). Reads every package's `.nuspec` and DLLs in the NuGet cache.
   No build, no network; the restore before it downloads.

   | | N0 | N1 | C1a | C1b | C2a | C2b | C2c | R | Total |
   | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
   | Microsoft | 23 | 7 | 2 | 2 | 0 | 141 | 0 | 21 | 196 |
   | Third-party | 6 | 2 | 7 | 11 | 45 | 40 | 2 | 32 | 145 |

   **1b. The repositories at the declared commits** (done 13/10, `mac`, on
   the census above; [declared-env](2026-10-13-declared-env.md)). Reads
   `global.json` and the CI files through GitHub's API. 122 packages get an
   exact SDK but no fixed OS image (E4), 4 get both (E5). 13 of these 126 are
   among the 53 R packages.
2. **Symbol servers** (done 13/10, `mac`;
   [symbol-servers](2026-10-13-symbol-servers.md)). For the 181 C2b packages,
   474 of 493 PDBs were found on Microsoft's or nuget.org's symbol server
   (37 MB). 145 packages move to R; 17 have only Windows-format PDBs, which
   record no compiler; 19 have no PDB on either server.

   **Ready to rebuild (R) after step 2: 198 of 341 packages** (53 from the
   census, 145 from the symbol servers). Their compiler records name 39
   different Roslyn builds.
3. **Test B on the 198 R packages**, on `arch`.
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
- **A declared commit that is not on GitHub.** `Microsoft.IdentityModel.Protocols`
  and `…Protocols.OpenIdConnect` 8.19.2 declare commit `25d90ed3`, and GitHub
  answers "No commit found" `[V]`. Built from a private copy? Category E0 for
  now.
- **`dotnet/dotnet`.** 62 packages, the runtime packs among them, now come
  from Microsoft's combined repository. Its build is far larger than one
  project's; how much of it test B needs is not known.
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
(181) keep it outside the package, so we looked on the symbol servers (step 2).

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

**Microsoft's repos build with Arcade** (added 13/10). Arcade is Microsoft's
shared build system for its .NET repos: `./build.sh` installs the exact SDK
from `tools.dotnet` in `global.json`, restores the Arcade SDK from Microsoft's
own feeds, and adds shared rules for versions, signing and packaging. 21 of
the 104 builds use it. We do not build a whole repo for one package: the build
can be limited to the projects we need and what they depend on `[I]`, but the
full repository is cloned. Two risks remain. Old commits may need build
packages that the feeds no longer hold (then C3). And the official build ID
comes from Microsoft's internal pipeline, not the repo; decision 9 covers it.
Signing needs Microsoft's keys, so we compare without signatures (decision 6).

**Our "never build inside git" rule conflicts with test B.** The publisher
built inside a clone, so the commit is in `AssemblyInformationalVersion` and
in Source Link. To match, we must build inside a clone at the declared commit.
This is a deliberate exception.

**The Mac can leak into the bytes.** One empty class gave the same bytes on
macOS and Linux (9/9). A real project can still differ by line endings or file
name case `[I]`.

**The layer plan's counts are not used.** Its 94 direct and 408 transitive
(502) come from `tools/dependency-graph`, which reads `tests/` too
(`tools/dependency-graph.js:89`) `[V]`, and describe the .NET 9 graph of 15/9.

**Not every lock file ships.** The two libraries have their own lock files, and
these can resolve another version than the programs do. Only the programs'
graph ships, so the census reads only the programs' lock files.

**A self-contained release ships the runtime.** The runtime packs come from
NuGet but are in no lock file. Layer 2 found that 323 of WebAPI's 746 files are
copies from them (W21). Without them, the scope would miss the largest part of
the release.

## Terms

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
- **Repository+commit pair:** one GitHub project at one exact commit. One pair
  is one build; one build can give many packages.
- **Windows-format PDB:** the older PDB format. It records no compiler, so a
  package with only such PDBs has no declared compiler.
- **SSQP key:** how a symbol server finds a PDB: `<pdb>/<GUID><age>/<pdb>`, with
  `FFFFFFFF` instead of the age for a portable PDB.

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
- **Arcade:** Microsoft's shared build system for its .NET repos
  (`dotnet/arcade`). Each repo carries its scripts in `eng/common/` and starts
  with `./build.sh`, which installs the SDK named in `tools.dotnet`, restores
  the Arcade SDK package and builds with Microsoft's shared rules. A layer on
  top of `dotnet build`.
- **Official build ID:** a date and counter that Microsoft's release pipeline
  gives an Arcade build; it becomes part of the DLL's file version. Not in the
  repo.
- **NuGet Package Explorer / `dotnet-validate`:** check a package for Source
  Link, deterministic build and PDBs `[I]`, not run.
- **`dotnet/dotnet`:** Microsoft's combined repository, from which .NET 10's
  own packages are built.
- **`experiments/dep-census/census.py`:** our census script.
- **`experiments/dep-census/declared_env.py`:** reads `global.json` and the CI
  files at each declared commit (step 1b).
- **`experiments/dep-census/symbols.py`:** looks up the missing PDBs on the
  symbol servers (step 2).
- **`tools/dependency-graph.js`:** Phoenix's script that counted the graph on
  15/9.
