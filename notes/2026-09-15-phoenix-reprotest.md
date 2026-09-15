# Phoenix layer 1, environment axes: reprotest

Run 15 September 2026 on `arch`. Continues
[phoenix-layer1](2026-09-15-phoenix-layer1.md), where two builds on the same path
gave 0 differing files. Same lab, same SDK, same day.
Data: `data/2026-09-15-phoenix-reprotest/arch/`.

## Question

Which changes in the build environment can Phoenix' own assemblies tolerate? One
axis per run, as in [environment-axes](2026-09-14-environment-axes.md).

## Setup

- Lab `/private/tmp/rb1-phoenix`, an rsync of the worktree
  `thesis/reproducible-builds` at `6b7a3254` (global.json pinned), cleared of
  `bin`/`obj` before the run. - reprotest 0.7.x from `~/.local/bin`, diffoscope
  from `arch`. - The build command sets `DOTNET_ROOT` and `PATH` explicitly to
  `~/.dotnet`, so reprotest uses Microsoft's 9.0.120, not the Arch package in
  `/usr/bin`. The 14/9 note describes the mix-up. - Only the two root projects
  are built, not the `.sln`, so the test project is out. - Artefact pattern: our
  own DLLs and PDBs plus the generated json files in `WebAPI/bin`, and
  `BackgroundJobExecutor.*`. The ~1600 copied package files were identical in
  layer 1 and are left out to keep diffoscope time down. - Restore happens
  inside each reprotest build, from a warm cache in `~/.nuget/packages`.

## Expectation, written before the run

`+build_path`: **red**. The PDBs for all four own assemblies differ on the
absolute source paths. The DLLs differ on PDB checksum and MVID in the debug
directory, the same five fields as in empty-class 8/9. `deps.json` and
`runtimeconfig.json` are identical; they contain no paths. Everything else
identical.

If red as expected: `PathMap`/`ContinuousIntegrationBuild` are committed on the
branch, the lab is rsynced again, and the axis is run again. Expectation for the
repeat: green.

The other axes (`+time`, `+locales`, `+umask`, `+exec_path`) are expected green,
as on empty-class 14/9. Run after the path axis, one at a time.

## Commands

Verbatim in `kommando.txt`. The reprotest logs `rt-N-<axis>.log` contain
diffoscope dumps of Phoenix assemblies and MSBuild output quoting WS source
paths, so they stay in Leo's private repo. `logs.md` in the data folder lists
each log with line count, verdict and sha256.

## Result

`+build_path`: **red**, reprotest exit 1. Log file `rt-1-build_path.log`,
453,927 lines, mostly diffoscope's PDB dump.

The first attempt failed with MSB1008: `dotnet build` takes one project at a
time. Corrected to two calls chained with `&&`; `rt-0-failed-msb1008.log` is
kept.

| File | Differs | What |
| --- | --- | --- |
| `WebAPI.pdb`, `ApplicationCore.pdb`, `Infrastructure.pdb`, `BackgroundJobExecutor.pdb` | yes | absolute source paths, as expected |
| `WebAPI.dll`, `Infrastructure.dll`, `BackgroundJobExecutor.dll` | yes | `TimeDateStamp`, RVAs shifted 2 bytes |
| `ApplicationCore.dll` | yes | as above **plus four type names** in metadata |
| `spa.proxy.json` | yes | `WorkingDirectory` is an absolute path to `ClientApp/` |
| `WebAPI.staticwebassets.runtime.json` | yes | absolute path to `obj/.../compressed/` |
| `*.deps.json`, `*.runtimeconfig.json`, copied packages | no | |

Three things I had not predicted:

1. **The RVAs move.** `AddressOfEntryPoint` and the import table's address are
   shifted 2-4 bytes in all DLLs. Explanation: the DLL's debug directory
   contains the PDB's full path as a string, and reprotest's two paths have
   different lengths (`const_build_path` against `build-experiment-1`, 16
   against 18 characters). Everything after the string moves. That is why the
   19/8 probe saw 189 byte positions and not 70: the path sits *in* the DLL, not
   only in the PDB. `[V]` pedump hunks in the log. 2. **A source generator
   writes the path into type names.** In `ApplicationCore.dll` four generated
   types are called `<RegexGenerator_g>F<64 hex>__ImoPrefixPattern_0` and so on,
   and the 64 hex characters differ between the two builds. That is Roslyn's
   naming of file-local types: `F` + a hash of the source file's path. The regex
   generator (`[GeneratedRegex]`) uses it. The path is therefore not only debug
   metadata; it is part of the program's type system. `[V]` four `#Strings`
   entries. 3. **Two json files carry the build path.** `spa.proxy.json` from
   the SpaProxy package and `staticwebassets.runtime.json` from the SDK. Both
   are development artefacts and probably do not travel into publish, but they
   sit in `bin/` and would fail a naive comparison.

### Run 2: `ContinuousIntegrationBuild=true` in `Directory.Build.props`

Committed as `ed249cd4`, lab rsynced, same axis again. **Red, unchanged.** The
same ten files, the same four regex hashes changing, zero occurrences of `/_/` in
the output. `rt-2-build_path-pathmap.log`.

The cause, measured with `dotnet build -v:n` in the lab: csc got
`/pathmap:"/home/leos/.nuget/packages/=/_/"` and nothing else. `[V]`
`ContinuousIntegrationBuild` sets `DeterministicSourcePaths`, which maps
`SourceRoot` items. The source directory's `SourceRoot` comes from Source Link,
which finds the repo root with git. The lab has no `.git`, so Source Link
reported "Source Link is empty", and only the NuGet cache was mapped.
**Microsoft's recommended setting maps the wrong thing in a tree without git.**
In CI, where there is a git checkout, it would have worked. That is a finding in
itself: whether the path leaks depends on whether `.git` is present, not on the
code.

### Run 3: explicit `PathMap` rooted in the props file's directory

`<PathMap>$(MSBuildThisFileDirectory)=/_/</PathMap>` added, committed as
`4a6551b4`, lab rsynced, same axis. **Three of four assemblies green.**
`rt-3-build_path-pathmap-explicit.log`, 19,787 lines against 453,927.

| File | Run 1 | Run 3 |
| --- | --- | --- |
| `ApplicationCore.dll` + `.pdb` | red, 4 type names | **green** |
| `Infrastructure.dll` + `.pdb` | red | **green** |
| `BackgroundJobExecutor.dll` + `.pdb` | red | **green** |
| `WebAPI.dll` | red, RVAs shifted | red, `TimeDateStamp` only |
| `WebAPI.pdb` | 30,370 differing lines | 288 differing lines |
| `spa.proxy.json`, `staticwebassets.runtime.json` | red | red, as expected |

The four regex type names are now identical, so Roslyn hashes the *mapped* path.
`[V]` Channels 1, 2 and 3 are closed for the three assemblies.

### WebAPI's last byte: the Razor generator writes the path into source text

Measured with two local builds on `/private/tmp/rb1-phoenix` and
`/private/tmp/rb1-phoenix-B` (2 characters longer) and the tool
`experiments/pdbdump`, which reads the PDB's tables with
System.Reflection.Metadata. PDB B is 4 bytes longer; the DLLs differ in 72 bytes,
all in the five identity fields. No path in the DLL. `[V]`

The dump of the two PDBs is identical across 987 lines except three:

| Entry | A | B |
| --- | --- | --- |
| document `.../RazorSourceGenerator/Pages_Error_cshtml.g.cs`, content hash | `d262fd8e…` | `fac9f2de…` |
| document `.../RazorSourceGenerator/Pages__ViewImports_cshtml.g.cs`, content hash | `47f43c1c…` | `1081a178…` |
| EmbeddedSource for the `_ViewImports` document | 775 bytes | 777 bytes |

The embedded source files were extracted and diffed. The Razor source generator
writes the **absolute** path to the `.cshtml` file into the C# code it
generates, in `#pragma checksum "..."` and in every `#line (...) "..."`:

    #pragma checksum "/private/tmp/rb1-phoenix/src/WebAPI/Pages/_ViewImports.cshtml" "{8829d00f-…}" "9a53bf9f…"
    #line (1,2)-(1,11) "/private/tmp/rb1-phoenix/src/WebAPI/Pages/_ViewImports.cshtml"

Roslyn embeds generated source files in the PDB as text, and hashes them.
`PathMap` maps what the compiler writes itself: the document names, including
those originating from `#line`, appear correctly as
`/_/src/WebAPI/Pages/Error.cshtml` in the table. But the compiler does not touch
the text *inside* the generated file. `[V]` `pdbdump` diff, `src-*/` locally.

The generator gets `MSBuildProjectDirectory` as a compiler-visible property and
could have written relative paths. There is no setting in the Razor SDK's targets
that controls it. `[V]` grep in `Sdks/Microsoft.NET.Sdk.Razor/targets`.

Side note: `Program.cs` in WebAPI registers no Razor Pages.
`Pages/Error.cshtml` and `_ViewImports.cshtml` are leftovers from the project
template and are presumably never used. `[V]` grep, 0 hits on
`AddRazorPages`/`MapRazorPages`. Delete the directory and the channel disappears
for Phoenix. But the finding applies to any project with Razor.

### Run 4: `src/WebAPI/Pages` deleted

Verified first that nothing references the pages: 0 hits on `AddRazorPages`,
`MapRazorPages`, `ErrorModel` outside the directory. Committed as `e6e92423`, lab
rsynced, same axis. **All four assemblies and PDBs green.** Only `spa.proxy.json`
and `WebAPI.staticwebassets.runtime.json` differ, both with the build path in
plain text, as predicted from run 1. `rt-4-build_path-no-razor.log`.

| File | R1 | R2 | R3 | R4 |
| --- | --- | --- | --- | --- |
| ApplicationCore, Infrastructure, BackgroundJobExecutor (.dll+.pdb) | red | red | green | green |
| WebAPI.dll + .pdb | red | red | red | **green** |
| spa.proxy.json, staticwebassets.runtime.json | red | red | red | red |

### Runs 5-8: the other axes

Run after run 4, same lab, HEAD `e6e92423`. One axis per run.

| Axis | reprotest | Differing files | Log |
| --- | --- | --- | --- |
| `+time` | exit 0 | none | `rt-5-time.log` |
| `+locales` | exit 0 | none | `rt-6-locales.log` |
| `+umask` | exit 0 | none | `rt-7-umask.log` |
| `+exec_path` | exit 0 | none | `rt-8-exec_path.log` |

All green, as on empty-class 14/9. The two json files were identical on these
axes too: they carry the path, but not time, locale or permissions. Each run
took 4-5 minutes, with two restores and four builds.

Note what `+time` green means: MSBuild and csc write no clock readings into
anything we measured, `deps.json` included. The PE timestamp is a hash, as the
8/9 note showed. Time only enters at layer 4, when the zip format stores the
files' mtime.

## Interpretation

The expectation held in direction, not in extent. The path leaks through five
channels, not one:

1. source paths in the PDB
2. the PDB path stored in the DLL's debug directory
3. file-local type names from the regex source generator
4. text written by the Razor source generator and embedded in the PDB
5. two SDK-generated json files

Run 3 showed that channels 1 to 3 follow `/pathmap`: Roslyn writes those itself
and computes the regex type names from the mapped path. Channel 4 does not,
because the text is the generator's, not the compiler's. Channel 5 does not,
because the json files are written by MSBuild targets after compilation.
Whether the two json files are part of publish at all is decided in layer 2.

Two generators from the same vendor, two different answers on whether PathMap
applies. For reproducibility, every source generator in the dependency tree is a
potential source of path leakage, and the compiler flag does not cover them.
That is an unexpected connection between layer 1 and the dependency part.

Run 2 gave a finding we were not looking for: the setting Microsoft recommends
for reproducible builds only works when the build tree is a git checkout. A build
from a tarball or a copied directory, which is what an auditor or a customer
would typically have, leaks the path anyway. Reproducibility depends on a file,
`.git`, that is not part of the source.

Finding 2 is the most interesting one for the thesis: a build path ends up as
the identity of a type in the delivered binary. That is not "metadata about the
build"; that is the program itself being different.

## Caveats and not tested

- `arch` only. `+fileordering` was not run; it requires `disorderfs` and can only
  run on `ubuntu-vm`.
- WebAPI's PDB difference is closed by deleting the unused Razor pages. That is a
  Phoenix-specific solution; a project that actually uses Razor still has the
  channel open. What to do there has not been investigated.
- The two json files are not closed. Whether they are part of publish is decided
  in layer 2.
- The `pdbdump` output and the extracted generated files contain WS paths and
  code; they stay locally with Leo.
- The explanation for the RVA shift (string length in the debug directory) is
  derived from the pattern, not measured byte for byte. `[I]` until it is.
- `dotnet build`, not publish. The publish axes are layer 2.
- Frontend out via `SkipSpaBuild`.
- Restore from a warm cache both times. Cold cache is the dependency part's test.
