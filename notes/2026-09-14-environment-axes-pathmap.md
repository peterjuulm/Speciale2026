# Experiment 2b: environment variations with PathMap

Run 14 September 2026 on `arch` (Leo's laptop, Arch SDK 14:38, Microsoft SDK
14:43 CEST) and `ubuntu-vm` (shared droplet, 14:38 CEST), right after
[environment-axes](2026-09-14-environment-axes.md). Same lab
`/private/tmp/rb1`, same three source files, same pinned SDK 9.0.120. The
glossary is in [empty-class](2026-09-07-empty-class.md).

Data: `data/2026-09-14-environment-axes-pathmap/arch/`, `.../ubuntu-vm/` and
`.../arch-ms-sdk/`. The verbatim build command is in `kommando.txt` in each
directory.

The question: **does `PathMap` close the one axis that failed, and what is left
once it is closed?**

## Background

Experiment 2 gave 13 verdicts as predicted: everything green except
`+build_path`. But the twelve green runs gave twelve different DLL hashes,
because reprotest builds in a new `/tmp/reprotest.XXXXXX/` per run, and the
directory name appears in the DLL via the path to the PDB file. "Successful"
only meant "build 1 and build 2 in the same directory are equal".

## Expectation, written before the run

1. `+build_path` turns green.
2. All runs on one machine give the **same** hash, because the random directory
   name is no longer written in.
3. The two machines give **different** hashes, even though both run 9.0.120. The
   Arch package's `csc.dll` is built from a different Roslyn commit than
   Microsoft's, see [compiler-identity](2026-09-08-compiler-identity.md).
4. If `arch` is built with Microsoft's SDK from `dotnet-install.sh` (in
   `~/.dotnet` since 8/9), it hits the VM's number.

The hash will not be `4b3808d1…` from experiment 1; that build had no `PathMap`
and contains the path `/private/tmp/rb1`.

## The runs

The only change from experiment 2 is the last parameter to `dotnet build`:

```bash
reprotest --vary=-all,+build_path -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release -p:PathMap=$PWD/=/_/' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll'
```

`$PWD` is expanded by the shell reprotest starts the build in, that is with the
directory actually being built in. The compiler then writes `/_/` where it would
otherwise write the directory. The first attempt used
`$(MSBuildProjectDirectory)`; that does not work from the command line, because
MSBuild does not expand property expressions in global properties. The parameter
was ignored, and the path was still in the DLL. `[V]`
Check that the mapping took effect:

```bash
strings -n 6 bin/Release/net9.0/minlib.dll | grep pdb
# /_/obj/Release/net9.0/minlib.pdb
```

In a csproj the parameter corresponds to:

```xml
<PathMap>$(MSBuildProjectDirectory)=/_/</PathMap>
```

The third setup, `arch-ms-sdk`, additionally puts
`PATH=/home/leos/.dotnet:$PATH DOTNET_ROOT=/home/leos/.dotnet` in front, so it is
Microsoft's 9.0.120 that builds. `environment.txt` shows
`Base Path: /home/leos/.dotnet/sdk/9.0.120/`.

## Result

| Axis | `arch`, Arch SDK | `arch`, Microsoft SDK | `ubuntu-vm` |
| --- | --- | --- | --- |
| `rt-1-none` | successful | successful | successful |
| `rt-2-umask` | successful | successful | successful |
| `rt-3-locales` | successful | successful | successful |
| `rt-4-exec_path` | successful | successful | successful |
| `rt-5-build_path` | **successful** | **successful** | **successful** |
| `rt-6-time` | successful | successful | successful |
| `rt-7-fileordering` | n/a | n/a | successful |
| DLL hash, all runs | `0b8f72d28cfd…` | `535a56fc682f…` | `535a56fc682f…` |

19 runs, 19 green, and three hash columns with one number in each. `[V]`
(last line in each `rt-*.log`)

| Setup | `csc.dll` sha256 | Roslyn commit | Hash |
| --- | --- | --- | --- |
| `arch`, the Arch package | `1b7543aa709363b6…` | `d0558bff…` | `0b8f72d28cfd…` |
| `arch`, Microsoft | `644a4d336dcd11a7…` | `fc52718e…` | `535a56fc682f…` |
| `ubuntu-vm`, Microsoft | `644a4d336dcd11a7…` | `fc52718e…` | `535a56fc682f…` |

All four expectations held.

## Interpretation

**`PathMap` closes the path, and only the path.** `+build_path` goes from red to
green with one parameter. No other axis changes, which is expected, since they
were green already.

**The hash column collapses from twelve numbers to one per machine.** That is the
real result. reprotest's verdict says "build 1 equals build 2"; the identical
hash across six independent runs in six random directories says "any build equals
any build". The `arch` hash is also identical to a build made by hand in a fourth
directory outside reprotest. `[V]`

**What is left between the machines is the compiler's identity.** With the path
gone there is one difference left between `arch` and `ubuntu-vm`: which `csc.dll`
builds. Swap the Arch package's for Microsoft's, and the numbers are the same
across Arch Linux and Ubuntu. That is the 8/9 finding again, but now without path
noise and measured through every axis: two compilers with the same version number
give two different binaries; two installations of Microsoft's compiler on two
operating systems give one.

Together with experiment 2: **a .NET classlib build is sensitive to exactly two
things reprotest can reach, the build directory and the compiler.** The first is
closed with `PathMap`. The second is not closed by a version number, but by
fetching the compiler from the same source.

## Caveats

- **`PathMap` is not free.** Debuggers now have to be told that `/_/` means the
  source directory (Source Link or a manual mapping). Not investigated here.
- **Only the DLL is measured.** The PDB still contains source paths, mapped to
  `/_/`, and the compiler's identity. Whether two PDBs are identical across runs
  has not been measured.
- **`+fileordering` with one source file** still says little; see experiment 2.
- **Not tested:** Peter's Mac. The prediction is `535a56fc682f…` with his
  `dotnet-install.sh` SDK and the same `PathMap`, even though his `csc.dll` is a
  different file (`1824569732a63f5d…`, osx-arm64), because the declared Roslyn
  commit is the same. `[I]`
- **Not tested:** `DebugType=none` as an alternative closure, and whether the
  compiler channel then also disappears from the DLL.
- `pedump` is still two different programs on the two machines; irrelevant here,
  since no run failed.
