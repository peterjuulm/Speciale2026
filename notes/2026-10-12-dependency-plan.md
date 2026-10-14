# Dependency plan: rebuilding Phoenix's NuGet packages

Planning note, 12 October 2026, rewritten 13 and 14 October. Part 2 of the
thesis. Not an experiment; each run has its own note. Phoenix commit
**`79cb67a7`** on `thesis/reproducible-builds` (.NET 10).

A first version measured the .NET 9 commit `e19ca414`. Only .NET 10 is tested,
so that data was removed (decided 13/10, Peter); it is in git history, commit
`a03fe66`.

## The question

Can we rebuild each NuGet package that Phoenix's release ships from the source
it declares, in the environment it declares, and get the bytes that are on
nuget.org?

## Which packages we test

**The rule:** a package is tested if the Linux release ships it, or if it is a
tool whose output ships. The release is the self-contained `linux-x64` publish
of `WebAPI`, `BackgroundJobExecutor` and `DbMigrator`
(`03-release.yml:106,335,338`), plus the SQL script that `dotnet-ef` writes
(`03-release.yml:137`).

| | Packages | Why |
| --- | ---: | --- |
| **Tested:** the three programs' lock files (`net10.0` and `linux-x64` parts) | 337 | Everything each program uses: 85 named in our `.csproj` files, 252 pulled in by other packages |
| **Tested:** the .NET runtime packs for `linux-x64` | 3 | A self-contained release contains the .NET runtime. These packs are in no lock file |
| **Tested:** `dotnet-ef` 10.0.12 | 1 | A tool, but its SQL script ships (decided 13/10, Peter) |
| **Tested, total** | **341** | |
| Left out: only in a library's lock file | 17 | The libraries are compiled into the programs; the programs' own versions ship |
| Left out: only used by `tests/` | 76 | Tests do not ship |
| Left out: runtime packs for `win-x64` | 3 | The Windows release is later work (decided 5/10) |
| Left out: `csharpier`, `dotnet-format` | 2 | Formatting tools; never part of a build |
| **Left out, total** | **98** | |

Not NuGet packages, so not part of this test: the frontend's npm packages
(layer 3) and the .NET SDK itself (the toolchain, recorded by its `csc.dll`
hash).

Every package, with its category, is listed in `census.md`; every package left
out, with its reason, in `left-out.md`. Both are in
`data/2026-10-13-dependency-census/mac/` but **not in git**: they name every
package and version Phoenix ships, and this repo is public (decided 12/10).
`kommando.txt` makes them again.

## Where each package stands

Steps 1 and 2 sorted the 341 packages by what they declare. Only a package
that declares both its source and its compiler can be rebuilt by our rule
(decision 3).

| Category | Packages | What it means | Next |
| --- | ---: | --- | --- |
| **Ready to rebuild** | 196 | The `.nuspec` names the repository and commit; the PDB names the compiler and its options | Nupkg test |
| **No compiler declared** | 83 | The source is named, but no PDB records the compiler. 64 have no PDB anywhere (45 of them are Humanizer language packs); 19 have a PDB without that record (17 in the old Windows format) | Not reproducible: the environment is not declared |
| **No source declared** | 24 | We cannot tell which code was built. 9 name no repository, 13 no commit, 2 a commit that GitHub does not have | Not reproducible |
| **Native code only** | 9 | Only Linux machine code (`.so` files), compiled from C/C++ by the publisher, for example SQLite's `libe_sqlite3.so`. The .NET SDK only copies these files into the release, so rebuilding Phoenix says nothing about them; the .NET app host is the exception, which the SDK copies and stamps with the program's name `[I]` | Open: rebuild each library with its own C/C++ build, or not |
| **Ships nothing** | 29 | No file reaches the Linux release: meta packages, build-time tools such as analyzers, files for other platforms | Nothing to compare |

After the nupkg test, each "ready" package gets one result: **reproducible** (same
bytes once signatures are removed), **differs** (and where), or **does not
build** (and why).

The 196 ready packages come from **82 builds**: 61 repositories, some at
several commits. One build is one repository at one commit; it can give many
packages (`dotnet/runtime` at `9d5a6a9a` gives 25).

How the categories were found: the census read each package's `.nuspec` and
DLLs (step 1); the symbol servers supplied 474 of the 493 PDBs that were not in
their packages, which moved 145 packages to "ready" (step 2). The census's own
finer categories (`N0`…`C2c`, `R`) are in its note and data.

## A full build environment, and where a package declares it

What changes the bytes of a .NET build, from our own measurements, and where a
NuGet package can declare each part. "Level 1" is the package itself (`.nuspec`,
`.nupkg`, DLL, PDB); "level 2" is the repository at the declared commit
([declared-env](2026-10-13-declared-env.md)). Nothing is recorded for CI logs:
they are not a declaration (decided 13/10).

| # | Part of the environment | Where a package can declare it | Looked yet? |
| --- | --- | --- | --- |
| 1 | **Source commit** | `.nuspec` `<repository commit>`; often also the version (`4.2.0+c00e17fd…`) and Source Link in the PDB | Yes, census `[V]` |
| 2 | **The SDK's exact build** | Not as such. Hints: the PDB's compiler record names the Roslyn commit and the .NET runtime that ran the compiler; the `.nupkg`'s `.psmdcp` names the pack tool and its version (`NuGet.Build.Tasks.Pack 6.12.2.1` for Serilog 4.2.0); level 2: `global.json`, `setup-dotnet` in CI | Roslyn commit `[V]`; `global.json` and CI `[V]`; pack tool on 3 packages by hand `[V]` |
| 3 | **Package graph** (and runtime packs, for programs only) | The compiler record lists every reference by name and MVID, which fixes the exact reference DLLs; a `packages.lock.json` at the commit, if the repository has one | References `[V]`, not yet compared; lock files at the commit not checked `[I]` |
| 4 | **Command line and properties** | Not recorded. Their effect on the compile step is in the compiler record: Release or Debug, defines, language version, nullable, platform. The command itself may be in the repository's CI file or build script (level 2) | Compiler record `[V]`; commands in CI files not extracted `[I]` |
| 5 | **Environment variables** | Not recorded. Only their effects show, for example in a version stamp; a CI file may set some (level 2) | No |
| 6 | **Build path or `PathMap`** | The PDB's document paths: `/_/…` means mapped; a real path such as `D:\a\1\s\…` means not mapped, and that path is part of the environment | Not checked `[I]` |
| 7 | **Locale and umask** | Not recorded. The locale matters only for a compiler with a defect like W26; the umask never reaches a DLL's bytes | Not needed for the DLL |
| 8 | **Target RID and host OS** | Target: the package folders (`lib/<framework>/` is portable, `runtimes/<rid>/` is for one platform). Host: sometimes in the `.psmdcp` (Newtonsoft.Json 13.0.3: `Microsoft Windows NT 10.0.20348.0`, .NET Framework 4.7.2); `runs-on` in CI (level 2); line endings through the PDB's source checksums | Folders `[V]`; `.psmdcp` on 3 packages `[V]`; CI `[V]`; line endings `[I]` |
| 9 | **Tools whose output ships** | The pack tool: `.psmdcp`. Source generators, which write code into the DLL while it is compiled: their output may be embedded in the PDB `[I]` | Pack tool on 3 packages `[V]`; generators not checked |

So a package declares the compile step well (points 1, 2 and 3 through the
compiler record and Source Link) and almost nothing outside it (4, 5, 7). Two
cheap additions to the census, both offline: the pack tool and host from the
`.psmdcp` (2, 8, 9), and the PDB paths (6).

## Decisions

1. **Which packages:** the 341 above.
2. **Two tests.** **Nupkg test, the main test:** build the package from its
   declared commit and compare with the package on nuget.org. **Reprotest test,
   extra:** run reprotest on our own build of the package, as Benedetti et al.
   did.
3. **Only what is declared.** The `.nuspec` can declare the repository and
   commit; the PDB the compiler, its options and references; the repository's
   `global.json` the SDK. If a part is not declared, the package is not
   reproducible.
4. **No sample.** Every ready package is tried. The 311 packages that declare a
   commit come from 79 GitHub repositories at 103 commits, plus one package
   that declares a commit but no repository; one of the 103 commits is not on
   GitHub. So at most 102 builds can start; the nupkg test needs 82 of them.
   Microsoft's packages are included.
5. **A failure is a result.** It is recorded with where it stopped and who
   could fix it (Benedetti et al.'s Fig. 3: as is, configuration, tool patch,
   external).
6. **What we compare:** the DLLs and PDBs inside the package, not the `.nupkg`,
   which nuget.org signs. Before comparing, both files lose what needs the
   publisher's private key: the Authenticode certificate table, the
   strong-name signature (set to zeros) and the PE checksum.
7. **Machines.** Census on `mac`; builds and reprotest on `arch`.
8. **Dropped:** checking package hashes against the lock file. NuGet already
   does it in locked mode, which Phoenix uses in CI
   (`Directory.Build.props:43-44`).
9. **Official build settings** (added 13/10, Peter; Leo to confirm). A value
   that reaches the DLL from the publisher's release pipeline, not from the
   source, such as Microsoft's official build ID in the file version, is taken
   from the published DLL and given to our build. Every package where we do
   this is marked. Debian's buildinfo files record such values in the same
   way.

## Steps

1. **Census: what each package declares** (done 13/10, `mac`). Reads every
   package's `.nuspec` and DLLs in the NuGet cache, after a restore with SDK
   10.0.401 in a `git archive` export of `79cb67a7`.
   **1b. What the repository declares** (done 13/10;
   [declared-env](2026-10-13-declared-env.md)): `global.json` and CI files at
   each declared commit. 126 packages get an exact SDK; only 4 also a fixed OS
   image.
2. **Symbol servers** (done 13/10; [symbol-servers](2026-10-13-symbol-servers.md)):
   474 of 493 missing PDBs found, 145 packages moved to "ready".
3. **Nupkg test on the 196 ready packages:** 82 builds, on `arch`. Next.
4. **Reprotest test** on every package that builds, on `arch`.

## Phoenix on .NET 10: what matters for this plan

- **SDK `10.0.401`**, `rollForward: disable`; every workflow installs it from
  `global.json` (`deaf3090`) `[V]`.
- **`dotnet/dotnet`.** 62 packages, among them the runtime packs and
  `dotnet-ef`, come from Microsoft's combined repository for .NET 10 `[V]`.
- **`DbMigrator` fails a locked restore on macOS.** The restore stops with
  `NU1004`: the project asks for `linux-x64;osx-arm64;win-x64`, the lock file
  holds `linux-x64;win-x64` `[V]`. The project sets `PublishSingleFile` without
  naming one runtime, and I think the SDK then adds the machine's own runtime,
  `osx-arm64` on a Mac `[I]`. On Linux and in CI that runtime is already in
  the list. For the census it was restored unlocked in the export; its
  `net10.0`, `linux-x64` and `win-x64` lock sections stayed identical to the
  commit's `[V]`. A candidate W finding for Leo.

## Expectations (draft, Leo and Peter confirm before the first build)

Written before any build. `[I]` until measured. They use the census's codes:
R = ready to rebuild, C2b = PDB not in the package, C3 = does not build.

- After step 2, most C2b packages move to R. Microsoft and the large projects
  publish `.snupkg` files.
- Of the R packages, the third-party projects with Source Link and
  `ContinuousIntegrationBuild` match after signatures are removed. The
  mismatches are reference versions and paths.
- The Microsoft builds mostly stop at C3: Arcade, size, internal feeds.
- The reprotest test is green wherever the nupkg test is green. A package that matches nuget.org
  was already built deterministically once.

The first point was checked in step 2: 145 of 181 moved.

## Open

- **Native code (9 packages).** Test them, or call them vendor bytes? SQLite
  is small enough to be one native example.
- **The 45 Humanizer language packs** hold only translated resources, no code.
  Are they really "no compiler declared", or "ships nothing"?
- **17 packages give a redirect as their repository**
  (`go.microsoft.com/fwlink`, for example SkiaSharp). A redirect is not a
  repository.
- **`dotnet/dotnet`.** Its build is far larger than one repository's; how much
  of it the nupkg test needs is not known.
- **`mac` as a second machine for the nupkg test.** Line endings and the
  case-insensitive file system could show up.
- **BuildValidator.** Use it to test the compile step alone?
- **Analyzers** run inside Phoenix's own compile but do not ship.

## Issues considered

The points we discussed on 12/10 before we decided the plan.

**Determinism is not reproducibility.** reprotest compares two of our own
builds (reprotest test). It cannot tell if our build matches what the publisher
uploaded (nupkg test). The nupkg test is the supply-chain question.

**Benedetti et al. did only the reprotest test.** They built each repo's latest commit and
did not compare with the published package (Section III-C). Their reasons:
finding the right commit is hard, and environments differ. The nupkg test is new
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
source. The nupkg test does.

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

**Our "never build inside git" rule conflicts with the nupkg test.** The publisher
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
copies from them (W21). Without them, the test would miss the largest part of
the release.

## Terms

**Concepts**

- **Reprotest test:** reprotest builds the package twice under varied
  conditions and compares. Answers: is our build deterministic? (Called test A
  until 14/10.)
- **Nupkg test:** rebuild the package from its declared source and compare
  with the package on nuget.org. It compares the DLLs and PDBs *inside* the
  `.nupkg`, with signatures removed, not the `.nupkg` file itself (decision 6).
  Answers: does the published package match its source? (Called test B until
  14/10.)
- **Census:** reading what each package declares, before any build.
- **Repository / commit / package:** the source code on GitHub / one exact
  version of it, which is one build / what a build gives, compared with
  nuget.org. 61 repositories → 82 commits → 196 packages for the nupkg test.
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
- **Shared object (`.so`):** a shared library on Linux and most Unix-like
  systems: machine code for one operating system and one processor type,
  compiled from C or C++. A program loads it while it runs; many programs can
  use the same file, and the system keeps one copy in memory. The same idea is
  `.dll` on Windows and `.dylib` on macOS.
- **Native DLL / .NET DLL:** both can end in `.dll`. A native DLL holds machine
  code for Windows; a .NET DLL holds IL and runs wherever a .NET runtime runs.
- **ELF:** the file format of Linux programs and `.so` files. The format, not
  the extension, makes a file a Linux library.
- **Object file (`.o`) / static library (`.a`):** a C or C++ compiler turns each
  source file into an object file. A static library is copied into each
  program when it is built; a shared object stays a separate file.
- **Runtime identifier (RID):** a name for an operating system and a processor
  type, for example `linux-x64`, `linux-arm64`, `win-x64`, `osx-arm64`. A
  package ships one native file per RID; a lock file has one section per RID.
- **glibc / musl:** two C libraries for Linux. Most distributions, Arch among
  them, use glibc; Alpine uses musl. A `.so` built for one may not run with the
  other, hence RIDs such as `linux-musl-x64`.
- **.NET runtime:** the native program that runs IL, itself built per platform:
  on Linux `libcoreclr.so`, with `libSystem.Native.so` as .NET's bridge to the
  operating system.
- **ReadyToRun (R2R):** a .NET DLL that also holds precompiled machine code for
  one platform, to start faster. It keeps its IL. Most of the runtime pack's
  DLLs are ReadyToRun (W21).
- **App host:** the small native program that starts a .NET program, for
  example `WebAPI`. The SDK copies it from the host pack and writes the
  program's name into it `[I]`.
- **Public signing / delay signing:** building a strong-named DLL without the
  private key: the public key is filled in, the signature space stays zeros.
- **What is removed before comparing:** the Authenticode certificate table and
  the header field that points to it, the strong-name signature (set to
  zeros), and the PE checksum, which the signature changes (decision 6).
- **Satellite assembly:** a DLL with only translated resources, for example the
  Humanizer language packs.
- **Meta package:** a package with no files of its own, only dependencies.
- **Analyzer:** a DLL that runs inside the compiler during a build and does not
  ship.
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

- **reprotest:** builds twice with variations and compares (reprotest test).
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
- **jsign:** a tool that makes Authenticode signatures on any operating
  system. Phoenix's Windows release uses jsign 7.5 on a Linux runner
  (`deployment/signing/`).
- **Azure Artifact Signing:** Microsoft's cloud service that holds the private
  key for code signing. Phoenix's Windows release signs through it; the Linux
  release is not signed, only listed in `SHA256SUMS`.
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
