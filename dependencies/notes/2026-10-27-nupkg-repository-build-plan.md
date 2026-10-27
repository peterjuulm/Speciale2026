# Nupkg test, repository-build method: plan

Planning note, 27 October 2026, 16:30, written before the run. A separate
part of the nupkg experiments, next to the release-only method (versions 1
to 3) and the planned reprotest round. Scripts land under
`dependencies/experiments/nupkg/`, data under
`dependencies/data/2026-10-27-nupkg-repository-build/`.

## Question

The release-only method could not build 75 of the 139 Microsoft packages,
and the reason was the same in nearly every log: the project expects the
repository's own build system, Arcade, to have run first (the shared
framework, a generated `Directory.Build.props` under `artifacts/`, the
repo's MSBuild tasks). Those packages are the ones from dotnet/runtime,
dotnet/aspnetcore, dotnet/efcore, the VMR (dotnet/dotnet) with the same
three inside it, dotnet/roslyn, dotnet/msbuild, dotnet/symreader and
microsoft/reverse-proxy.

Question: when the repository's own build script is an input, built at
the declared commit with the official build id read from the shipped DLL,
how close does the result come to the package on nuget.org, by the same
four levels as before?

What is measured is the DLL that ships in Phoenix, taken out of our
package and out of nuget.org's, as in every earlier round. The levels say
nothing about the rest of the package. A build that fails shows a limit
of this method in this environment, not that the package cannot be
rebuilt.

Two things Microsoft's own documents name as reasons their binaries are
not byte identical are held constant by the method: signing (level 2
ignores the signature bytes) and the official build id (passed in, see
rule R4). What is left is the measurement.

The three questions stay apart: `publisher_match` is measured; `a_eq_a2`
is not tested in this run (one build per repository, see Caveats);
`variation` is the reprotest round's.

## Inputs (what the method is allowed to read)

Everything the release-only method reads (the .nupkg with its .nuspec, the
DLL's attributes, the PDB, the source at the declared commit), plus:

- the repository's build scripts at that commit (`build.sh`,
  `eng/build.sh`, `eng/common/*`), and its own documentation of how to
  build a subset;
- the repository's `NuGet.config` as checked in, with one rule (R5);
- the Arcade versioning specification
  (`src/arcade/Documentation/CorePackages/Versioning.md` in the VMR) for
  decoding the official build id.

CI pipeline files (`.azure/pipelines/*.yml`) are read only to confirm which
properties the official build passes; they are cited, not executed.

## Rules

R1. **Repository and commit**: from the .nuspec, as rule 1 and 2 of the
    release-only method. For a VMR commit, the inner repository is the one
    whose `src/<name>/` holds the project (runtime, aspnetcore, efcore).

R2. **SDK**: the repository's own. Arcade's `eng/common/tools.sh` installs
    the SDK named in `global.json` into `<repo>/.dotnet`. No SDK is chosen
    by us; the build's PATH has no other dotnet.

R3. **Build command**: the repository's script, the smallest subset its
    own documentation offers that produces the packages:

    | repository | command (from the checkout root) |
    |---|---|
    | aspnetcore (standalone or inside the VMR) | `eng/build.sh --ci -c Release --projects <App.Runtime csproj> <props>` then, once per product, `eng/build.sh --ci -c Release --pack --projects <csproj> <props>`. The first step is the fix `docs/BuildErrors.md` gives for "shared framework must be built". One call per project because a `;`-joined list loses its quotes in the shell and MSBuild splits it. |
    | runtime (standalone or inside the VMR) | `./build.sh libs -c Release -ci -pack <props>`, the libraries subset per `docs/workflow/building/libraries/README.md`. |
    | efcore, msbuild, symreader, reverse-proxy | `./build.sh --restore --build --pack --ci -c Release <props>` (Arcade's standard entry; msbuild's wrapper adds restore and build itself). |
    | roslyn | `./build.sh --restore --build --pack --ci -c Release <props>` (its own `eng/build.sh`, same flags). |

    `<props>` is `/p:OfficialBuildId=<id>` (R4), the release branding
    (R4b), and for an inner repository of the VMR
    `/p:UsingToolMicrosoftNetCompilers=false`: the VMR passes that to every
    inner build (`repo-projects/Directory.Build.targets`), so the SDK's csc
    compiles instead of the Microsoft.Net.Compilers.Toolset package the
    inner repository would otherwise restore, and the shipped DLLs' PDB
    compiler records name the SDK's csc. `-nobl` where the script accepts
    it (no binary log; it does not change outputs). `--ci` is what sets
    `ContinuousIntegrationBuild=true` in Arcade's `tools.sh`, the same
    property the release-only method passes. No `--sign`, no `--publish`.

R4. **Official build id**: decoded from the shipped DLL's
    `AssemblyFileVersionAttribute` by Arcade's published scheme:
    FILE_PATCH = (PATCH mod 100) * 100 + yy, FILE_REVISION =
    (50 * mm + dd) * 100 + r, so `OfficialBuildId = 20yymmdd.r`. The
    derivation records the decoding and marks it `[I]`; the run checks it,
    because a wrong id gives a wrong file version in our build, which is a
    level-4 difference by itself. Three known limits of the decoding:
    - Arcade accepts revisions up to 199
      (`CalculateAssemblyAndFileVersions.cs`), and the VMR adds 100 to the
      revision before it reaches the inner repository
      (`repo-projects/Directory.Build.props`). So one FILE_REVISION reads
      two ways: day d, revision r, or day d-1, revision r+100. Both give
      the same file version, so the bytes do not depend on the choice;
      for a VMR product the second reading is passed, because the inner
      build runs without the VMR's +100. Both readings are in the facts.
    - Where FILE_PATCH does not fit the scheme (msbuild sets its own
      patch), the year is lost; it is taken from the nuget.org publish
      date, marked as such.
    - Products of one build that decode to different ids make the recipe
      "not derived"; one build cannot have two ids, and a vote is not a
      derivation.

R4b. **Release branding**: the shipped versions carry no prerelease
    label, so the build is told it is the release:
    `/p:DotNetFinalVersionKind=release`, and `/p:StabilizePackageVersion=true`
    for the repositories that gate the former on the latter (runtime,
    aspnetcore, efcore `eng/Versions.props`; inside the VMR the default is
    false, so without it the packages would come out as
    `10.0.12-servicing.<date>`). The evidence is the version string in
    the .nuspec.

R5. **Feeds**: the repository's `NuGet.config` as checked in. Where it
    lists a feed under `pkgs.dev.azure.com/dnceng/internal/`, that entry
    is removed before the build, and the removal is recorded in the facts.
    Reason: the packages on those feeds are the same versions that are
    public on nuget.org today; the internal feed only existed because they
    were not yet public on the release day. A restore that still fails is
    a result ("did not build: internal feed"), not something to fix. The
    edited lines are logged (`nuget-config-edits.txt`), and each product's
    `project.assets.json` (the resolved dependencies with their hashes) is
    kept, so what was restored from where can be read afterwards.

R6. **Checkout**: as the release-only method: full clone from the mirror,
    the commit checked out detached, `core.autocrlf=true` when the
    publisher built on Windows (CRLF in the generated files), as the
    facts say for every package here.

R7. **Products**: one build per repository and commit; every listed
    package built from that commit is taken from
    `artifacts/packages/Release/Shipping/` and compared with nuget.org by
    `level.py`, as before. Packages the script did not produce get "not
    produced".

R8. **Out of scope, stated**: the two runtime packs
    (Microsoft.NETCore.App.Runtime.linux-x64,
    Microsoft.AspNetCore.App.Runtime.linux-x64) need the full product
    build; SkiaSharp needs Apple workloads; the standalone repositories
    (Azure SDK, IdentityModel, Identity.Web, MSAL and the singles) have
    no Arcade build and already built under version 3; their causes are
    known for most (date suffix, clock, signing; three Identity.Web
    level-4 rows are still unread), so they are not rerun here.

## Scope and order

20 builds, 99 packages (every batch-3 package from an Arcade repository,
including the 24 that built at level 4 under version 3, so the two
methods can be compared on them), in this order (fast feedback first,
then the heavy ones). Build 5 holds 33 of the packages. Build ids decoded where the file version is already in the
version-3 facts; the rest are read from the nupkg by the derivation step.

| # | repository | commit | packages | build id | est. |
|---|---|---|---|---|---|
| 1 | dotnet/aspnetcore 9.0.0 | af22eff | 4 | 20241029.3 (9.0.24.52903) | 30 min |
| 2 | dotnet/symreader 2.0.0 | 27e5846 | 1 | 20230428.4 | 10 min |
| 3 | VMR 95017c7, src/efcore 10.0.12 | 95017c7 | 9 | 20260823.8 (10.0.1226.42308) | 20 min |
| 4 | VMR 95017c7, src/aspnetcore 10.0.12 | 95017c7 | 11 | 20260823.8 | 45 min |
| 5 | VMR 95017c7, src/runtime 10.0.12 | 95017c7 | 33 | 20260823.8 | 60 min |
| 6 | VMR 4452502, src/runtime 10.0.2 (Bcl.Cryptography) | 4452502 | 1 | 20251213.5 (10.0.225.61305) | 60 min |
| 7 | dotnet/roslyn 5.0.0 | 6c4a46a | 8 | 20251117.12 (5.0.25.56712) | 60 to 90 min |
| 8 | dotnet/msbuild 18.0.2 | 995a3dc | 1 | 20251021.2 (date and revision only) | 30 min |
| 9 | microsoft/reverse-proxy 2.1.0 | 77f78d4 | 1 | from nupkg | 15 min |
| 10 to 17 | dotnet/runtime, 8 commits (.NET 5 to 9) | 4822e3c, 5535e31, 81cabf2, 9d5a6a9, bf5e279, cf258a1, d099f07, fa7cdde | 22 | from nupkg | 8 × 50 min |
| 18 | dotnet/aspnetcore 6.0.24 (Razor) | 2aa4015 | 2 | 20231018.12 (6.0.2423.51812) | 30 min |
| 19 | dotnet/aspnetcore 8.0.0 (HealthChecks) | 3f1acb5 | 2 | from nupkg | 30 min |
| 20 | dotnet/msbuild 17.11.48 | 02bf662 | 2 | from nupkg | 30 min |

About 15 hours serially on arch (16 cores, 61 GB RAM, 69 GB free disk).
One build at a time, each in its own process group with a 4-hour limit
(the whole group is killed, so no orphaned MSBuild keeps running); the
checkout, `.dotnet`, `artifacts` and the package cache are deleted after
each, only `out/` (packages, logs, comparisons) is kept. A watchdog checks
the free disk every 30 s during a build and kills it below 8 GB; the
batch stops there too.

Prerequisites on arch: `clang` (present), `cmake` and `ninja` (missing;
the runtime libraries subset builds native shims). The driver refuses a
runtime recipe with "not run: cmake missing" rather than guessing a
smaller subset.

## Expectation (written before the run)

`[I]` all of it.

1. Builds 1, 2, 3, 8, 9 (aspnetcore 9.0.0, symreader, efcore, msbuild,
   reverse-proxy) run to the end and produce their packages. Of the
   dotnet/runtime builds, the .NET 8 and 9 ones (5 commits) build; the
   .NET 5, 6 and 7 ones (cf258a1, 4822e3c, d099f07) may fail on today's
   toolchain (old native build, old SDK on a new distro), and that is a
   result.
2. Level 3 rather than level 2 for most: the official builds ran on
   Windows, ours on Linux. If the SDK-generated source files (assembly
   info, global usings) get LF here where the publisher's had CRLF, their
   checksums in the PDB differ and the DLL's PDB checksum with them
   (`core.autocrlf` does not touch generated files; the SDK writes them
   with the platform newline, `WriteCodeFragment`). This is an inference,
   not a ceiling: the reports' PDB checksum lines decide it per package.
   Expected: most produced packages at level 3 (same IL and metadata,
   build identity differs).
3. The file version in our build equals the shipped one for every
   package whose build id was decoded by the full scheme (R4), which
   confirms the decoding. Where it does not, the package is at level 4
   on the version and the decoding is wrong, not the build.
4. The VMR's inner runtime and aspnetcore build standalone, restoring the
   sibling repositories' packages from the public feeds instead of from
   the same VMR run.
5. Roslyn: the shipped Microsoft.CodeAnalysis.CSharp 5.0.0's PDB names
   csc 5.0.0-2.25451.107, the SDK's compiler from `global.json`, not a
   bootstrap of the commit itself. So the build runs without
   `--bootstrap`, and the eight Roslyn packages are expected at level 3
   like the rest. The compiler each build actually used is recorded
   (`toolchain.txt`).

6. The three Identity.Web packages are not in this run (R8); nothing
   here changes their rows.

If 2 holds, the follow-up is the same builds on a windows-2022 runner for
the small repositories (aspnetcore 9.0.0, efcore, symreader), to see
whether the OS closes the gap to level 2. That needs the workflow to
accept the repository recipe; not part of this run.

## Procedure

1. `derive-repo.py LIST OUT`: for each package, read repository, commit,
   shipped DLL and file version (version-3 facts where they exist, else
   the nupkg from nuget.org), decode the build id, group by repository
   and commit into one recipe each (`<repo>-<commit7>.toml` with a
   `[[products]]` list), write `facts.txt` beside it.
2. `repo-build.py RECIPE WORKDIR`: clone from the mirror, strip internal
   feeds (R5), run the recipe's command in a controlled environment (as
   `rebuild.py`: HOME, PATH `/usr/bin`, LANG, NUGET_PACKAGES, no other
   dotnet), copy each product's nupkg from the shipping folder, download
   the nuget.org package, compare, write `out/<product>/summary.txt` in
   the shape `run-batch.py` already classifies.
3. `run-repo-batch.py BATCH LIST LAB`: steps 1 and 2 in the order above,
   one at a time, classify every product with `level_of`, append to
   `results.tsv` after each build, commit and push the data after each
   build, clean the lab after each build, stop below 8 GB free.
4. Morning: read `results.tsv` and `run.log`; write the result note.

## Caveats (known before the run)

- One build per repository, so A against A2 is not measured here. A
  second build of the small repositories is a cheap follow-up.
- Linux against Windows, see expectation 2. The result note must keep
  "level 3 because of OS" apart from "level 3 because of something else",
  by reading the PDB checksums in the reports.
- The internal-feed rule (R5) edits one checked-in file. It is the only
  edit to the source tree, and it is logged.
- A recipe whose `global.json` names an SDK older than 8 gets
  `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` in its environment, because
  those SDKs do not start on Arch's ICU 78. It changes nothing the
  compiler emits; it is in the recipe and the facts. The ICU, OpenSSL and
  native tool versions of the machine are recorded per build.
- **The VMR's inner repositories are built standalone**, with the
  repository's own dev-workflow script, not through the VMR's
  orchestration. The orchestration passes more than we do: `DotNetBuild`,
  `DotNetBuildFromVMR` (`--productBuild --fromVMR`), a
  `DotNetPackageVersionPropsPath` with the versions of the sibling
  repositories built in the same run, `SourceBuilt*Dir` paths,
  `RepoOriginalSourceRevisionId` from `source-manifest.json`, and it
  bootstraps runtime. We restore the siblings from the public feeds
  instead, which for a released version are the same packages. What we
  do pass is what the shipped DLL shows was in effect: the SDK's compiler
  (`UsingToolMicrosoftNetCompilers=false`), the release branding (R4b),
  the VMR's +100 revision (R4), and Source Link to dotnet/dotnet, which
  comes for free because the inner repository sits inside the VMR's git
  checkout. A difference that this deviation could explain is reported
  as such, and the next step would be one build through the VMR's own
  `--projects repo-projects/efcore.proj` to see whether it closes.
- Estimates are from repository size, not measurements; the first build
  of each kind gives the real number.

## Version 2: the VMR identity properties (written 27 October 22:20, after build 4 of version 1, before any version-2 run)

Build 4 (the VMR's aspnetcore at 95017c7, standalone) put all ten
packages at level 4 for one cause, read from the reports: our DLLs say
`RepositoryUrl` = github.com/dotnet/aspnetcore and `SourceCommitUrl`
under that repository, and lack the `OriginalRepoCommitHash` attribute;
the shipped DLLs say dotnet/dotnet and carry the hash cb21a42 of the
aspnetcore commit the VMR was made from. Those are exactly two of the
properties the VMR orchestration passes to the inner build
(`RepositoryUrl`, `RepoOriginalSourceRevisionId`; the caveat above
named them). Both values are facts of the release and of the source:
the DLL's attributes, and `src/source-manifest.json` at the commit.

Version 2 adds, for the VMR's inner repositories:
`/p:RepositoryUrl=https://github.com/dotnet/dotnet` and
`/p:RepoOriginalSourceRevisionId=<commitSha of the inner repository in
src/source-manifest.json>`.

Added 22:55, after build 7 (msbuild 18.0.2) and before any version-2
run, R5b for every recipe: `/p:EnableNgenOptimization=false`. Passing
`OfficialBuildId` (R4) makes Arcade's `OfficialBuild` true, and in a
Release official build Arcade's `VisualStudio.AcquireOptimizationData`
step then restores internal tools from a Microsoft-internal feed (401)
and fetches IBC optimization data from an internal drop. msbuild has
`UsingToolIbcOptimization=true`, so build 7 died there; Roslyn has it
on Windows only. The documented suppression is
`EnableNgenOptimization=false`. A shipped DLL that carries merged
optimization data will then stay at level 4 with equal IL, and that is
the finding: an input of the official build that is not public. Nothing
else changes. Version 1's rows stay
as the version-1 measurement; version 2 is a separate batch
(`2026-10-28-nupkg-repository-build-v2`, recipes under
`recipes/repository/2026-10-28-nupkg-repository-build-v2/`), run after
version 1's batch.

Expectation `[I]`: the ten aspnetcore packages move to level 3 (the
attributes were the only difference besides build identity in nine of
them; Identity.UI also differs in IL and #US, to read). efcore does not
change (its DLLs matched on `RepositoryUrl` through Source Link; its one
level-4 row is IL). Amended 22:35, after build 5 and before any
version-2 run: runtime's 34 packages also came out level 4 with
`RepositoryUrl` = dotnet/runtime against the shipped dotnet/dotnet
(`src/runtime/Directory.Build.props` sets it), so they are expected to
move as well, except that most of them also differ in the managed
resources by 8 bytes (1296 against 1288 in Logging), which version 2
does not touch; those stay at level 4 until that is read.

## Version 3: the standalone runtime commits without the native shims (written 27 October 23:20, after build 9 of version 1, before any version-3 run)

Build 9 (`runtime-9d5a6a9`, dotnet/runtime 9.0.0, eight packages) did
not build. The `libs` subset starts with `libs.native`, the C shims
under `src/native/libs`, and this machine's clang 23.1.3 rejects
eleven places in them (`pal_gssapi.c`, `pal_networking.c`,
`pal_threading.c`, `pal_signal.c`, `pal_process.c`, `openssl.c`,
`pal_evp_kdf.c`, `pal_evp_mac.c`) with C-to-C++ compatibility
diagnostics raised as errors (`-Wimplicit-void-ptr-cast`,
`-Wjump-misses-init`, `-Wimplicit-int-enum-cast`). The repository does
not pass `-Werror` for a release branding (`configurecompiler.cmake`
gates it on `PRERELEASE`, which nothing sets); the diagnostics are
errors in this clang. The .NET 10 sources in the VMR (build 5) compile
on the same clang, so the sources, not the method, are what the newer
compiler rejects: expectation 1 said older toolchains, this is a newer
one. The managed build never started, so the eight packages have no
version-1 measurement beyond "did not build".

R3c, version 3, for the standalone dotnet/runtime commits only: the
subset leaves out `libs.native` and `libs.pretest` (test assets) and
names the two managed subsets the shipped packages come from, read
from `eng/Subsets.props` at the commit: `libs.sfx+libs.oob` where the
file defines `Libs.Sfx` (.NET 7 and later), `libs.ref+libs.src+libs.packages`
in .NET 5 and 6. The shipped packages in scope contain managed code
only, so the shims are not an input of any byte compared. Everything
else is version 2 (identity properties for VMR inner builds, which
these are not; `EnableNgenOptimization=false`). The README
(`docs/workflow/building/libraries/README.md`, 9.0.0) offers
`/p:BuildNative=false` for this; no project file at that commit reads
the property (`git grep "(BuildNative)"` finds nothing), so the subset
is the way that exists. Recorded as a finding about the build
documentation.

Batch `2026-10-28-nupkg-repository-build-v3`, recipes under
`recipes/repository/2026-10-28-nupkg-repository-build-v3/` (derived
with `--v3`), order `order-2026-10-28-v3.txt`: the eight standalone
runtime recipes, run after version 2's batch. Version 1's rows stay.

Expectation `[I]`: the .NET 8 and 9 commits (5535e31, bf5e279,
81cabf2, 9d5a6a9, fa7cdde) build and come out at level 4 where the
package embeds a generated `ILLink.Substitutions.xml` (the newline
effect of build 5) and level 3 otherwise. The .NET 5, 6 and 7 commits
(cf258a1, 4822e3c, d099f07) are expected not to build for the reason
expectation 1 gave: their SDKs (global.json) predate this machine's
OpenSSL 3 and ICU, and `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT` covers
only the ICU part.

Amended 23:05, after build 10 (`runtime-fa7cdde`, 9.0.11) and before
any version-3 run. Build 10 compiled (exit 0, no shim errors: the
servicing sources compile on clang 23) and packed nothing but the
RID-specific `runtime.linux-x64.runtime.native.System.IO.Ports`.
`eng/packaging.targets` sets `GeneratePackageOnBuild` only with
`BuildAllConfigurations=true` (or for RID-specific projects) in .NET 6
to 9, and the libraries README says `build.sh libs -allconfigurations`
for packages; the official pipeline packs the out-of-band libraries in
its `Libraries_AllConfigurations` leg, `-s tools+libs -allConfigurations`
on `windows_x64` (`eng/pipelines/runtime-official.yml`). Version 1's R3
command (`libs -pack`, from the README's build line) therefore cannot
produce the packages in scope for the standalone .NET 6 to 9 commits;
that is version 1's result for them. R3c becomes
`tools+libs.sfx+libs.oob -allconfigurations` (`tools+libs.ref+libs.src+libs.packages
-allconfigurations` in .NET 5 and 6): the official leg's subsets and
switch minus the shims. The leg is a Windows build, so the newline
effect of build 5 applies to every package that embeds a generated
file. The derivation also no longer picks `src/libraries/shims/stubs/*.csproj`
as a package's project (rule 7 took the shorter path; four recipes
named a stub). Recipes regenerated.

Amended 23:15 after a second opinion, checked in the files, before any
version-3 run: .NET 5 and 6 have no `tools` subset (an unknown subset
fails `eng/SubsetValidation.targets`), so `tools+` is passed only where
`eng/Subsets.props` defines it; .NET 6 keeps the name `libs.packages`
without a project mapping (packing moved into the source projects), so
6.0.0 gets `libs.ref+libs.src` and 5.0.0 `libs.ref+libs.src+libs.packages`.
Two results to expect rather than fix: (1) in .NET 8 servicing
(bf5e279, 81cabf2) `eng/packaging.targets` withholds
`GeneratePackageOnBuild` unless the project sets it, and at these
commits the four projects in scope do not (Microsoft.Bcl.TimeProvider
at 81cabf2 even sets it to `false` with `ServicingVersion=1`), so the
commit's own build cannot produce the shipped package: the package
authoring that produced it is not at the commit the DLL names.
(2) Some .NET 5 `pkgproj` files harvest assets from an earlier
package instead of building them, so a match there shows reuse, not a
rebuild. Both go in the result note if they occur.
