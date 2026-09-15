# Experiment 3: is the compiler the same?

Run 8 September 2026, on `arch` only. Builds on
[empty-class](2026-09-07-empty-class.md); the terms are in the glossary there.

Data: `data/2026-09-08-compiler-identity/arch/`.

The question: **was it the compiler's bytes that made the two DLLs different on
7 September?**

## Background

Experiment 1 gave two different binaries from the same source, the same path and
the same pinned SDK version:

| | `arch` | `ubuntu-vm` |
| --- | --- | --- |
| `minlib.dll` | `541bed823d12e42b…` | `4b3808d1cc1d6425…` |
| `csc.dll` | `1b7543aa709363b6…` | `644a4d336dcd11a7…` |
| SDK Version | 9.0.120 | 9.0.120 |
| SDK Commit | `d0558bff3d` | `3f97250e38` |
| MSBuild | `17.12.57+d0558bff3` | `17.12.57+07da1b9a8` |
| Host Version | 10.0.11 | 9.0.19 |
| RID | `arch-x64` | `linux-x64` |
| `LANG` | `da_DK.UTF-8` | `C.UTF-8` |
| The SDK's origin | The Arch package `dotnet-sdk-9.0 9.0.19.sdk120-1` | Microsoft's binary release via `dotnet-install.sh` |

Both call themselves 9.0.120, but `dotnet --info` reveals that they are built
from **different source revisions**. On `arch` MSBuild's commit suffix is
identical to the SDK's commit; on `ubuntu-vm` they differ. That is the signature
of a unified source build against components built separately.

The wording should therefore not be "same source, different binary", which is
wrong. It should be: **the version number 9.0.120 identifies neither the source
revision nor the binary.** It covers at least two commits and two compiler
binaries.

And the commit field does not solve it. It is still a string stamped in during
the build, which nothing checks against bytes. Commit is provenance, hash is
identity.

## Why `arch` only

The design is a 2x2 where three cells are already settled:

| | Arch's SDK | Microsoft's SDK |
| --- | --- | --- |
| **The Arch machine** | `541bed82…` measured 7/9 | **? - this test** |
| **The Ubuntu VM** | not feasible | `4b3808d1…` measured 7/9 |

Peter has nothing to do: he already has Microsoft's SDK, and a reinstall would
not change a byte.

The mirror image, Arch's SDK on Ubuntu, is effectively blocked. Arch runs glibc
2.44, the VM 2.39 (measured 8/9), and the SDK's native parts are linked against
the newer one on Arch. You could unpack the pacman package and try, but then you
measure a transplant and not a distribution. It is not needed either: if the
output is determined by the compiler and not by the machine, one direction is
enough to show it.

## The method

One variable is changed. Microsoft's 9.0.120 is downloaded **alongside** the Arch
package, and the same source is built again on the same path on the same machine.
Everything else is held fixed, `LANG=da_DK.UTF-8` included.

```bash
export UD=$HOME/Dev/Speciale2026/data/2026-09-08-compiler-identity/arch && mkdir -p "$UD"
```

fish: `set -gx UD $HOME/Dev/Speciale2026/data/2026-09-08-compiler-identity/arch`.

```bash
curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --version 9.0.120
```

It lands in `~/.dotnet` and does not touch `/usr/share/dotnet`. Check that it is
picked when you point at it. `Base Path` must say
`/home/leos/.dotnet/sdk/9.0.120/`:

```bash
cd /private/tmp/rb1 && env PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="$HOME/.dotnet" dotnet --info | grep -E 'Version:|Base Path'
```

Record both compilers as files. That is the control: if Microsoft's `csc.dll` on
Arch is identical to Microsoft's `csc.dll` on the VM, the tool is the same and
only the machine differs:

```bash
sha256sum /usr/share/dotnet/sdk/9.0.120/Roslyn/bincore/csc.dll "$HOME/.dotnet/sdk/9.0.120/Roslyn/bincore/csc.dll" | tee "$UD/compilers.txt"
```

Build with Microsoft's SDK:

```bash
cd /private/tmp/rb1; rm -rf bin obj; env PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="$HOME/.dotnet" dotnet build -c Release; sha256sum bin/Release/net9.0/minlib.dll | tee -a "$UD/hashes.txt"
```

And the environment block, as always from the project directory:

```bash
cd /private/tmp/rb1 && env PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="$HOME/.dotnet" dotnet --info > "$UD/environment.txt"
```

```bash
uname -srm >> "$UD/environment.txt"; umask >> "$UD/environment.txt"; locale | head -1 >> "$UD/environment.txt"
```

## Result

| What | Expected | Measured |
| --- | --- | --- |
| SDK Commit, Microsoft's SDK on `arch` | `3f97250e38` (same as the VM) | |
| `csc.dll`, Microsoft's SDK on `arch` | `644a4d336dcd11a7…` (same as the VM) | |
| `csc.dll`, the Arch package | `1b7543aa709363b6…` | |
| `minlib.dll` built with Microsoft's SDK | `4b3808d1cc1d6425…` (same as the VM) | |

The first two rows are the control: if Microsoft's SDK on Arch hits the same
commit **and** the same `csc.dll` hash as on the VM, the tool is demonstrably the
same, and only the machine differs.

## What the difference between the two compilers consists of

Investigated 8 September after the run, with `pedump` (via diffoscope) and
`ilspycmd`.

**The compilers are the same code.** Decompiled, both `csc.dll` are 1672 lines,
and only 12 lines differ, every one of them metadata:

| | Arch | Microsoft |
| --- | --- | --- |
| `TargetFramework` | `.NETCoreApp,Version=v9.0` | `.NETCoreApp,Version=v8.0` |
| `CommitHash` | `d0558bff3d817c76a12aa68…` | `fc52718eccdb37693a40a51…` |
| `AssemblyInformationalVersion` | `4.12.0-3.25609.5+d0558…` | `4.12.0-3.25609.5+fc527…` |
| `RepositoryUrl` | `github.com/dotnet/dotnet` | `github.com/dotnet/roslyn` |

Same Roslyn version, `4.12.0-3.25609.5`. Arch builds from the unified source tree
(`dotnet/dotnet`), Microsoft from `dotnet/roslyn`, and the two binaries run on
different frameworks. The last two differing lines are a generated type name
whose hash follows from the others.

Both embedded PDB paths start with `/_/`, so **both Microsoft and Arch use
`PathMap` on their own releases.** The fix WS.Phoenix lacks, the tool vendors
apply to themselves.

**And they emit identical code.** The same source built on the same path with
each of the two compilers gave `e793b11f1e74ab42…` against `4ede5f519b3e2eef…`,
but decompiled the two results are **0 lines different**.

The difference is 70 bytes out of 4096, sitting in five clumps:

| Byte (1-indexed) | Size | Field |
| --- | --- | --- |
| 137-140 | 4 | the PE header's `TimeDateStamp` (verified by offset) |
| 1597-1612 | 16 | the module's MVID in the GUID heap |
| 1821-1824 | 4 | timestamp in the debug directory |
| 1905-1920 | 16 | PDB id (CodeView GUID) |
| 2065-2096 | 32 | PDB checksum, SHA-256 size |

The bottom four are inferred from position and size, not verified against the
format specification. No byte of IL, metadata tables or string heaps differs.

`TimeDateStamp` is worth a look: pedump reads the fields as `"2048-04-05
10:47:46"` and `"2054-09-09 08:29:46"`. Absurd future dates, because Roslyn in
deterministic mode writes a content hash in the timestamp field instead of the
clock. The field that classically breaks reproducibility has been turned into an
identity field.

### What it means

**Bit identity is stricter than code identity.** Two independently built
compilers of the same version demonstrably emitted the same code, and the
artefacts still differed, because .NET's deterministic build deliberately binds
the artefact's identity to the compiler's identity.

The consequence is hard: a distribution that builds the compiler from source can
**never** hit the vendor's artefacts, no matter that the code is the same. To
verify a release bit for bit, you need the vendor's own compiler binary. Pinning
"9.0.120" is not enough, and pinning the source revision is not enough either.

The mechanism, that Roslyn's deterministic hash takes in the compiler's own
identity, is inferred from the observation and has to be checked against Roslyn's
source before it is cited.

## How to read the outcome

**The hash comes out `4b3808d1…`.** The case is closed: same source, same path,
same compiler binary, and then the same output. That run settles three things at
once, because `arch` keeps its own values for everything else: `LANG` is still
`da_DK.UTF-8` against the VM's `C.UTF-8`, the RID is still `arch-x64`, and the
`dotnet` host is still 10.0.11 against the VM's 9.0.19. If the hash still lands,
all three are ruled out as causes. One build, four answers.

**The hash comes out something third.** Then more than the compiler is in play.
The next run adds `env LANG=C.UTF-8` on top, and after that the RID and the
`dotnet` host version remain as candidates.

**The hash comes out `541bed82…`.** Then we built with the Arch package after
all; `DOTNET_ROOT` or PATH did not take effect. Check `Base Path` in the
environment block before interpreting the result.

## Why it matters beyond the experiment

The thesis' claim is that a version is a self-declared string with no binding to
a binary. Here it is demonstrated on our own machine, in miniature: two
compilers, one version number, two results. It is also a warning about the
method. A reproducible build requires the toolchain to be identified by content,
not by name. `global.json` pins a version number, and that is not enough.

## Caveats

- **The Arch package stays installed.** The experiment adds an SDK, removes none.
  Every later run must therefore say explicitly which `dotnet` it used, and
  `command -v` belongs in the environment block.
- **The `dotnet` host is shared.** `global.json` pins the SDK, not the host
  (`Host: 10.0.11` on `arch`). It starts the compiler but does not compile
  itself, so it should not reach the output, but that is an assumption, not a
  measurement.
- **One machine.** The experiment explains the difference; it does not show that
  Microsoft's SDK gives the same bytes on arbitrary machines.
