# What the source declares about the build environment

Run 13 October 2026 on `mac`. Online, read only: GitHub's API through `gh`.
Step 1b of the [dependency plan](2026-10-12-dependency-plan.md), on its census
of Phoenix `79cb67a7` (.NET 10). No build.

Data: `dependencies/data/2026-10-13-declared-env/mac/` (the lists stay out of git, as the
census lists do).

## Question

The census read what each package declares itself: `.nuspec`, DLL, PDB (level
1). For each package that declares a commit, what does **the repository at that
commit** declare about the build environment (level 2)?

- an SDK version: `global.json` (`sdk.version`, `rollForward`; Arcade's
  `tools.dotnet`);
- a CI configuration: which system, which OS image, which SDK version in CI.

CI logs are left out (decided 13/10): a log records what happened in one run;
it is not a declaration.

## Expectation (written before the run)

`[I]` all of it. Written before the first run, which was on the .NET 9 census
(see Commands); not changed since.

1. The declared commits exist on GitHub for more than 95 % of the 104 pairs.
2. Microsoft's repos (Arcade) almost all have a `global.json` with an exact
   `tools.dotnet`, and Azure Pipelines. Their OS images come from named agent
   pools, so the image is not readable from the repo.
3. About half of the third-party repos have a `global.json`. Most of those
   allow a roll-forward, so the SDK is a lower bound, not a version.
4. Most third-party repos build in GitHub Actions on a floating image
   (`*-latest`) with a wildcard SDK (`8.0.x`).
5. Fewer than 1 in 5 third-party commits declare both an exact SDK and a fixed
   OS image.

## Commands

From the root of Speciale2026, on `mac`, 13/10. `CACHE` is a directory that
keeps the API responses, so a rerun is offline.

    curl -sI 'https://go.microsoft.com/fwlink/?linkid=868515' | grep -i '^location'
    python3 -I experiments/dep-census/declared_env.py data/2026-10-13-dependency-census/mac/census.csv CACHE data/2026-10-13-declared-env/mac

The commands are as run. On 21/10 `data/` and `experiments/` in them moved
to `dependencies/data/` and `dependencies/experiments/`.

The script asks GitHub's API for the file tree at each declared commit, then
reads `global.json` and every CI file (GitHub Actions, Azure Pipelines,
AppVeyor, Travis, GitLab; at most 40 per repository). From the CI files it
takes the OS images (`runs-on`, `vmImage`, `image`) and the SDK versions
(`setup-dotnet`, `UseDotNet`). It runs in about one minute.

**The runs.** The script first ran in the morning on the census of the .NET 9
commit `e19ca414` (853 API responses). Reading that output by hand found three
faults, fixed before any result was used:

1. The one package with a commit but no repository URL was reported as
   "commit not found".
2. A `global.json` that lets the SDK roll forward past the patch counted as a
   declared SDK version, so for example Newtonsoft.Json reached the top level.
   Such a lower bound now has its own level (E3).
3. YAML comments and list dashes ended up in the values
   (`- Visual Studio 2022`, `windows-latest # required by …`).

After Phoenix moved to .NET 10, the fixed script ran on the census of
`79cb67a7`: 83 of its 104 pairs came from the cached responses, the 22 new
pairs gave 255 new responses. Only .NET 10 is tested, so the .NET 9 results
were removed (decided 13/10, Peter) and are not kept. Everything below is the
.NET 10 run.

## Result

311 of the 341 packages declare a commit. They come from 104
repository+commit pairs (one GitHub project at one exact commit each) in 80
projects: 79 on GitHub, plus one package with a commit but no repository URL.
30 packages declare no commit (census C1a, C1b), so there is nothing to look
up for them.

Each pair gets one level:

| Level | Meaning | Pairs, Microsoft | Pairs, third-party | Packages |
| --- | --- | ---: | ---: | ---: |
| E0 | No repository URL, or commit not found | 2 | 0 | 3 |
| E1 | Nothing: no `global.json`, no CI file, no build script | 0 | 0 | 0 |
| E2 | No SDK version, or only a wildcard such as `8.0.x` | 7 | 36 | 113 |
| E3 | SDK only as a lower bound (`rollForward` past the patch) | 18 | 15 | 69 |
| E4 | Exact SDK (or up to the patch), OS image not fixed | 20 | 3 | 122 |
| E5 | Exact SDK and only fixed OS labels | 3 | 0 | 4 |
| | | 50 | 54 | 311 |

"Microsoft" is the census's owner rule: the `.nuspec` authors include Microsoft.

- **A declared commit that GitHub does not have** `[V]`.
  `Microsoft.IdentityModel.Protocols` and `…Protocols.OpenIdConnect` 8.19.2
  declare commit `25d90ed3f488…` in
  `AzureAD/azure-activedirectory-identitymodel-extensions-for-dotnet`. Checked
  once more by hand: "No commit found for SHA" (HTTP 422).
- **The other E0** is `Microsoft.VisualStudio.Azure.Containers.Tools.Targets`:
  it declares a commit but no repository URL.
- **`dotnet/dotnet`.** 62 packages, among them the runtime packs and
  `dotnet-ef`, come from Microsoft's combined repository at two commits. Its
  `global.json` declares an exact SDK through Arcade (`tools.dotnet` 10.0.111 at
  `95017c71`); its OS images are template variables (E4).

The expectation, point by point:

1. **Held.** 102 of the 103 pairs with a GitHub URL exist (99 %) `[V]`.
2. **Held in part.** 21 Microsoft pairs build with Arcade and declare an exact
   SDK in `tools.dotnet` `[V]`. The other 29 Microsoft pairs (Azure SDK,
   identity libraries, SkiaSharp, ONNX Runtime and others) do not: 18 give only
   a lower bound, 7 no version or a wildcard, 2 a version up to the patch
   outside Arcade, and 2 are E0. Many OS images found in Microsoft's repos come
   from GitHub Actions workflows on `*-latest` or from template variables, not
   from readable release pipelines.
3. **Failed.** Only 18 of 54 third-party pairs have a `global.json` (33 %), not
   about half. **Held:** 15 of those 18 let the SDK roll forward past the patch.
4. **Held.** 37 of 54 third-party pairs use GitHub Actions; 36 of them on a
   floating or mixed image. In total, 18 give only a wildcard SDK in CI and 18
   no SDK at all.
5. **Held, more strongly than expected.** No third-party pair (0 of 54)
   declares an exact SDK and a fixed OS label. Only 3 pairs do, all
   Microsoft-authored: two `dotnet/aspnetcore` 6.0 commits and
   `serilog-extensions-logging`, whose authors include Microsoft.

## Interpretation

**The repository adds the SDK, mostly for Microsoft.** Level 2 gives an exact
SDK for 126 packages (E4 and E5), 123 of them Microsoft's. For third-party
packages it gives an exact SDK for 3 packages. The rest give a lower bound, a
wildcard, or nothing.

**Almost nobody declares the OS.** Only 4 packages reach E5, and even a fixed
label such as `ubuntu-22.04` or AppVeyor's `Visual Studio 2022` names an image
that the CI provider updates over time (see Caveats).

**The two levels do not overlap much.** Of the 53 packages that the census
found ready to rebuild by the PDB (census R), 13 also get an exact SDK from the
repository. The PDB names the compiler; the repository names the SDK; few
packages do both.

**Without a buildinfo file, the environment must be pieced together.** Our
finding: the information is spread over the `.nuspec`, the PDB, `global.json`
and the CI files, and most of it is a range, not a value. Benedetti et al.
recommend that packaging tools record build information themselves (the
compiler and its version, the build dependencies' exact versions, the build
options; Section V), and say that without buildinfo files an independent build
is very hard to compare with the published package (Section I). They do not
discuss CI logs; leaving the logs out is our own decision.

## Caveats

- **We do not know which CI file built the release.** A repository often has
  several workflows (tests, release, housekeeping). The script takes the OS
  images from all of them. Microsoft's official builds run in an internal
  Azure DevOps that the repository does not fully show.
- **A "fixed" OS label is not a fixed image.** GitHub and AppVeyor update their
  images regularly `[I]`. The label fixes the OS version, not the installed
  tools.
- **The YAML is read with patterns, not parsed.** Matrix values
  (`${{ matrix.os }}`) and templates (`${{ parameters.vmImage }}`) are not
  resolved; they count as "expression".
- **16 trees were too large for one listing** (`dotnet/runtime`,
  `azure/azure-sdk-for-net`, `dotnet/dotnet`). For those, the script read only
  the root, `.github/workflows`, `eng/pipelines`, `.azure-pipelines` and
  `build`. A `global.json` deeper in the tree would be missed.
- **Only the first `global.json` counts,** the one nearest the root. A project
  can have another one in a subfolder.
- **The owner rule is crude.** `serilog-extensions-logging` counts as
  Microsoft because its authors include Microsoft.
- **The lists were kept out of git until 21/10** (`declared-env.md`,
  `declared-env.csv`), for the same reason as the census lists. They are in
  git since 21/10, at Peter's request. `kommando.txt` makes them again.
