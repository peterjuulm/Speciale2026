# The reference release rebuilt on the Mac (21 October 2026)

Grounds: a rebuild on `mac` of `v0.0.0-thesis.6`, compared with the
release that GitHub published on 14/10. Peter asked for it on 21/10. Run
by Claude.

## Question

Does `v0.0.0-thesis.6` come out the same on Peter's Mac as on GitHub's
runners and on `arch`? Two outputs: the frontend's static export and the
backend's two Linux zips, `ws-pems-linux-x64` and
`ws-pems-job-worker-linux-x64`. It is the first build of Phoenix on a
second machine that we run ourselves, and the first on another operating
system and processor (macOS on arm64, where `arch` and GitHub are Linux
on x86-64).

## Setup

- The tag `v0.0.0-thesis.6`, commit `be5fc56e`, fetched into
  `~/WS.Phoenix` on 21/10 without a change to its working tree.
  `ci-local.sh` (`experiments/phoenix-rt`, as of `fe4be3c`, the version
  of the delayed rebuild, with one change made during the run; see
  the result) takes a fresh
  shallow clone of the tag for each job, in `/private/tmp/rb1-ci/<job>`,
  the same paths as on `arch`. The NuGet cache and `HOME` are
  `/tmp/dch`, also the same path; it starts empty.
- The jobs `frontend` and `linux` only. Not the Windows job (it needs the
  signing image), the migrators, the SQL script or the images.
- SDK 10.0.401 from Microsoft (`~/.dotnet`, installed earlier with
  `dotnet-install.sh`), runtime 10.0.12, the runtime of `arch` and of
  the release (W58). The folder also holds SDK 9.0.120 and runtime 9.0.19;
  `global.json` with `rollForward: disable` picks 10.0.401.
- Node 22.23.3 for darwin-arm64 from nodejs.org, checked against its
  `SHASUMS256.txt`, in `/private/tmp/rb1-node22`.
- The npm cache `/private/tmp/rb1-npm` is filled first from the registry
  by an `npm ci --ignore-scripts` in a scratch clone of the tag, as the
  Mac has none. `ci-local.sh` then installs offline from it, as on `arch`.
- Packing: the tag's `pack-release-zip.sh` needs GNU `realpath -m` and
  `touch -d @N`, and `ci-local.sh` gives it the `PATH`
  `/private/tmp/rb1-tools:/usr/bin`. On the Mac that folder holds two
  small shims for those two options, links to `/bin/chmod` and `/bin/rm`,
  and nothing else; `zip` is Apple's `/usr/bin/zip` (Zip 3.0), not the
  Info-ZIP build on `arch`.
- Compared with the release's assets from GitHub (`gh release download`),
  by SHA-256, and, where a zip differs, entry by entry. The frontend
  export is compared with `wwwroot/` in the release's WebAPI zip, as the
  run's `frontend-export` artifact has expired.

## Expectation, written before the run

Written 14:05.

1. Both jobs pass on macOS. The locked restore downloads every package,
   the `linux-x64` runtime packs among them, from nuget.org.
2. The backend: every file in both publish folders is the same as in the
   release's zips. `[I]` Roslyn's output does not depend on the host's
   operating system or processor, the compiler runs on the same runtime
   patch (10.0.12, W58), and the paths are the same as on `arch`. The
   runtime and the third-party assemblies come from the same packages.
   The risks: macOS's ICU against Linux's, which .NET uses for culture
   data (`C.UTF-8` does not exist on macOS); APFS, which is
   case-insensitive and lists folders in another order; and the
   compiler's own bytes, which differ from `arch`'s (`csc.dll` is
   `99148255…` here, `28a84f96…` there), though the version is the same.
3. The frontend: the export is the same as the release's 994 files,
   less sure than the backend. `[I]` Next compiles with SWC, a native
   binary, here `@next/swc-darwin-arm64` instead of the Linux one. Both
   are built from one source, but nothing has tested that they emit the
   same code.
4. The zips: the same bytes as the release's, if the files are. `[I]`
   Apple's `zip` is Info-ZIP 3.0 too, and the packing script fixes times,
   modes, order and extra fields. A difference here is the zip tool, not
   the build, and is checked entry by entry.

## Commands

Verbatim in `data/2026-10-21-phoenix-mac-rebuild/mac/kommando.txt`.

## Result

`[V]` (`results.txt` and `environment.txt` in the data folder; the build
and its logs in `/private/tmp/rb1-mac-run`, not in git).

The first try stopped at once: `env: sh: No such file or directory`.
`ci-local.sh` gave the jobs a `PATH` of `/usr/bin` only, and macOS keeps
`sh`, `chmod` and `rm` in `/bin`. Every `PATH` in the script now ends in
`:/bin` too; on Arch `/bin` is a link to `/usr/bin`, so `arch`'s builds
see the same tools. The second try ran 14:03-14:09, 5 minutes 19 seconds.

1. Held. Both jobs passed: `frontend` in 2 minutes 14 seconds, `linux`
   in 3 minutes 5 seconds. The locked restore filled the empty NuGet
   cache from nuget.org, 4.2 GB.
2. Held. All 1624 files of the WebAPI zip and all 500 of the job
   worker's zip are the release's, byte for byte. The PDBs record the
   compiler `5.9.0-1.26423.113+e34a38d2…` on runtime
   `10.0.12-servicing.26422.108+95017c71…`.
3. Held. All 994 files of the export are the files at the same paths
   under the release's `wwwroot/`, byte for byte.
4. Held. Both zips are the release's, byte for byte:
   `ws-pems-linux-x64` `4c0d6362…`, `ws-pems-job-worker-linux-x64`
   `202f5b5d…`, the hashes in the published `SHA256SUMS`. `zipinfo -v`
   lists the same entries with the same metadata.

Seen on the way: the build did not run in the culture that
`LC_ALL=C.UTF-8` asks for. MSBuild wrote its times with a decimal comma,
`Restored … (in 18,99 sec)`, in all six restore lines. macOS's own
setting is `da_DK` (`defaults read -g AppleLocale`), and the shell's
`LC_*` variables are all `C`.

## Interpretation

**The release is reproducible on a second operating system and
processor.** `[V]` for `v0.0.0-thesis.6`, its frontend and Linux zips (W71).
macOS on arm64 gives the bytes that GitHub's Linux x86-64 runner gave on
14/10, and `arch` on 14/10 and 20/10. This is the first green cell for
another machine that we did not set up the same way as `arch`.

**The compiler's own bytes do not matter; its version does.** `[I]`
`csc.dll` is `99148255…` here and `28a84f96…` on `arch`, but the PDBs
record the same Roslyn commit and the same runtime patch. The likeliest
reason is that the SDK ships `csc.dll` compiled ahead of time for each
platform (ReadyToRun) from one IL build. So two different `csc.dll`
hashes can give the same output; the Roslyn commit in the PDB is what to
compare across platforms. W58 stays the condition: the same runtime
patch.

**SWC's native binary for darwin-arm64 emits the Linux binary's code.**
`[V]` for this export. The expectation's doubt did not come true.

**The locale pin does not reach .NET on macOS, and here it did not
need to.** `[I]` With `LC_ALL` set to a locale that macOS does not have,
.NET seems to fall back to the system's setting, `da-DK`, and ran the
compiler in it. The bytes did not change: W26, the locale defect, is gone
on SDK 10 (12/10), and nothing else in this build depends on the
culture. On SDK 9.0.120 this Mac would have shown W26 in spite of the pin.

**Apple's `zip` packs as Info-ZIP's build on Linux does,** `[V]` for these
two zips, once the packing script has fixed times, modes and order.

## Caveats

- Two jobs only. The Windows release, the migrators, the SQL script and
  the images were not built.
- The Mac's SDK came from `dotnet-install.sh` some time before the run,
  not from the branch's installer with its SHA-512 check, and its folder
  also holds SDK 9.0.120. The PDBs show that 10.0.401's compiler on 10.0.12
  ran.
- The packing used two shims of our own for GNU `realpath -m` and
  `touch -d @N`. They do what the script asks of the GNU tools, as far as
  it was tested here, but the release job never ran them.
- The build paths, `/private/tmp/rb1-ci/<job>` and `/tmp/dch`, were the
  same as on `arch` on purpose. On macOS `/tmp` is a link to
  `/private/tmp`. Another path was not tested here; `build_path` is green
  on `arch` (layer 2, 5/10, on SDK 9).
- The culture's source on macOS is read from MSBuild's output and the
  system setting, not from .NET itself; `CultureInfo.CurrentCulture` was
  not printed.
- The frontend installed offline from a cache filled on the same day by
  `npm ci --ignore-scripts`, so the registry was asked once, by the fill.

## Not tested

- The other four jobs on the Mac, the Windows zips with the release's
  signatures pasted among them.
- The branch head (`2cd85fd0`, 67 commits after the tag), which has no
  release to compare with.
- A build at another path on the Mac.
