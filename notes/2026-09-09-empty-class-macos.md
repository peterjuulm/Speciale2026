# Experiment 1 on macOS: the third environment

Run 9 September 2026 on `mac` (Peter's laptop, Apple Silicon). Same lab and the
same three files as [7 September](2026-09-07-empty-class.md); the glossary is
there. The protocol below is the macOS-specific version and can stand alone.

Data: `data/2026-09-09-empty-class/macos/`.

The question: **does `4b3808d1…` come out on a third operating system and a
different CPU architecture?**

## Why it is worth running now

[Compiler-identity](2026-09-08-compiler-identity.md) showed that the output is
determined by the SDK, not the machine: Microsoft's 9.0.120 on Leo's Arch
machine gave Peter's exact bytes, while kernel, distribution, glibc and `LANG`
stayed Leo's. But both existing environments are **Linux on x64**. The
hypothesis from 7 September, that the managed layer carries across operating
systems because a class library DLL contains only IL, has still only been tested
on Linux.

`mac` is that test. Two things change at once compared to `ubuntu-vm`:

| | `ubuntu-vm` | `mac` |
| --- | --- | --- |
| Operating system | Ubuntu 24.04 | macOS 14.6 (Darwin 23.6.0) |
| CPU | x86-64 | arm64 (Apple Silicon) |
| RID | `linux-x64` | `osx-arm64` |

Two axes at once is normally a bad idea. Here it is defensible, because the
outcome has only two interesting values: if the hash lands, both axes are ruled
out in the same run. If it does not, the run is not the conclusion. It is the
starting shot, and then the axes have to be separated.

## The control that decides whether the measurement answers at all

`csc.dll` **must** be `644a4d336dcd11a7…`, the same file as on `ubuntu-vm` and
the same file Microsoft's SDK gave on `arch`.

The Roslyn compiler in `Roslyn/bincore` is a managed assembly and should
therefore be the same bytes in all of Microsoft's SDKs, regardless of RID.
Should. If it is not, we have measured a third compiler. Then the run says
nothing about OS and CPU; it just repeats the finding from 8 September in a new
variant. The hash is therefore taken **before** the build, not after.

## Expectation, written before the run

| What | Expected |
| --- | --- |
| `sources.txt`, three files | `2a766d57…` `079f65f3…` `8628a3a4…` |
| `csc.dll` | `644a4d336dcd11a7…` (as on `ubuntu-vm`) |
| `minlib.dll`, build 1 | `4b3808d1cc1d642577f60a054905f5f065aab8b9aea1765b407fc583cef70d33` |
| `minlib.dll`, build 2 | as build 1 |

If other numbers come out, that is a finding, not an error. The section **How to
read the outcome** at the bottom says what each result means.

## Four places where macOS differs from the Linux protocol

1. **`shasum -a 256` instead of `sha256sum`.** Same algorithm, same output
   format, different command name. The format is the same, so `shasum -a 256 -c`
   can read Leo's and the VM's evidence files directly. 2. **No reprotest and no
   diffoscope.** Measurement 2 (the environment axes) does not run here; it is a
   Linux tool. `mac` contributes measurement 1 and 3. 3. **`/private/tmp`
   already exists.** No `sudo mkdir`. On the other hand it is macOS' own `/tmp`,
   and it is cleared by the `periodic` job for files untouched for three days.
   The lab may therefore be gone next week. Check the source hashes again before
   a later run instead of assuming the directory is as you left it. 4. **Two
   `dotnet` on the machine.** The system one is in `/usr/local/share/dotnet`
   (SDK 9.0.102, host 9.0.1, verified 9/9). The pinned 9.0.120 lands in
   `~/.dotnet`, which is not on PATH. Same problem as on the VM, where apt had
   its own, and the same solution: name it explicitly in every command.

## Step 1: the SDK, side by side

The Arch run on 8 September put Microsoft's SDK beside the distribution's
instead of replacing it. The same is done here, for the same reason: the
experiment adds an SDK and removes none, so the machine can still be used for
other things.

```bash
curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --version 9.0.120
```

The script picks `osx-arm64` on its own on Apple Silicon. **Let it.** That is
the point of the run; `--architecture x64` would give a Rosetta compiler and
measure something else.

Check that it is picked when you point at it. `Base Path` must say
`/Users/peterjuulmoller/.dotnet/sdk/9.0.120/`, and `Version:` must say `9.0.120`:

```bash
cd /private/tmp/rb1 && env PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="$HOME/.dotnet" dotnet --info | grep -E 'Version:|Base Path|RID'
```

If it says `9.0.102` or `/usr/local/share/dotnet`, `PATH` did not take effect.
Everything after this measures the wrong compiler. Stop and find out why before
you build.

## Step 2: the result directory

zsh:

```bash
export UD=$HOME/Speciale2026/data/2026-09-09-empty-class/macos && mkdir -p "$UD" && echo $UD && ls -d "$UD"
```

The variable disappears with a new tab. Put the line in `~/.zshrc` for as long as
the experiment runs. If `$UD` is empty, `tee -a "$UD/hashes.txt"` becomes
`tee -a /hashes.txt` and fails with `Permission denied`.

## Step 3: the lab

**Already created and verified 9 September 2026, before the run.** The three
files are in `/private/tmp/rb1` with the hashes `2a766d57…`, `079f65f3…`,
`8628a3a4…`, checked against `arch`'s own evidence file from 8 September with
`shasum -a 256 -c`. The check is saved in
`data/2026-09-09-empty-class/macos/sources.txt`.

If the lab has to be recreated because macOS has cleared `/private/tmp`, or
because the run is repeated on another machine, these are the four commands:

```bash
mkdir -p /private/tmp/rb1 && cd /private/tmp/rb1 && pwd -P
```

It must say `/private/tmp/rb1`, not `/tmp/rb1`. The build path is written into
the finished DLL, so it has to be the same physical string as on the two other
machines. `pwd -P` follows the symlink all the way.

```bash
printf '<Project Sdk="Microsoft.NET.Sdk">\n  <PropertyGroup>\n    <TargetFramework>net9.0</TargetFramework>\n  </PropertyGroup>\n</Project>\n' > /private/tmp/rb1/minlib.csproj
```

```bash
printf 'namespace Minlib;\n\npublic class Beregning\n{\n    public int Tal() => 42;\n}\n' > /private/tmp/rb1/Beregning.cs
```

```bash
printf '{\n  "sdk": {\n    "version": "9.0.120",\n    "rollForward": "disable"\n  }\n}\n' > /private/tmp/rb1/global.json
```

And the check, where yesterday's evidence file is today's test:

```bash
cd /private/tmp/rb1 && shasum -a 256 -c "$HOME/Speciale2026/data/2026-09-08-empty-class-v2/arch/sources.txt"
```

Three times `OK`. Otherwise: stop.

## Step 4: the environment block, before the measurement

Run this from the project directory, so `global.json` applies. Outside
`/private/tmp/rb1` the block describes a different SDK from the one that builds:

```bash
cd /private/tmp/rb1 && env PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="$HOME/.dotnet" dotnet --info > "$UD/environment.txt"
```

The machine itself. `sw_vers` is macOS' answer to the distribution file and
belongs here, because that is the axis the run tests:

```bash
uname -srm >> "$UD/environment.txt"; sw_vers >> "$UD/environment.txt"; umask >> "$UD/environment.txt"; locale | head -1 >> "$UD/environment.txt"; command -v dotnet >> "$UD/environment.txt"; echo "$HOME/.dotnet/dotnet" >> "$UD/environment.txt"
```

And the compiler, as files and not as a version number. This is the control from
the section above:

```bash
shasum -a 256 "$HOME/.dotnet/sdk/9.0.120/Roslyn/bincore/csc.dll" | tee -a "$UD/environment.txt"
```

It must say `644a4d336dcd11a7…`. If it does not, write the number down and read
**How to read the outcome** before building further.

## Step 5: measurement 1, two clean builds

```bash
cd /private/tmp/rb1; rm -rf bin obj; env PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="$HOME/.dotnet" dotnet build -c Release; shasum -a 256 bin/Release/net9.0/minlib.dll | tee -a "$UD/hashes.txt"
```

```bash
cd /private/tmp/rb1; rm -rf bin obj; env PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="$HOME/.dotnet" dotnet build -c Release; shasum -a 256 bin/Release/net9.0/minlib.dll | tee -a "$UD/hashes.txt"
```

`rm -rf bin obj` and not just `bin`: the `bin/` DLL is a copy of the `obj/` DLL,
so without `obj` in the cleanup you reuse the previous build and measure nothing.

If the build fails with `SDK 9.0.120 not found`, the command hit
`/usr/local/share/dotnet/dotnet`. That is `rollForward: disable` doing its job,
and the error is therefore good news: the pin works. Fix PATH and run again.

### The build path inside the binary

```bash
cd /private/tmp/rb1 && env LC_ALL=C grep -ao '/[A-Za-z0-9_/.-]*rb1[A-Za-z0-9_/.-]*' bin/Release/net9.0/minlib.dll | sort -u
```

It must say `/private/tmp/rb1/obj/Release/net9.0/minlib.pdb`. If it says
`/tmp/rb1/…`, the build went through the symlink, and then the hash cannot land.

## Step 6: save it

```bash
cd ~/Speciale2026 && git add data notes && git commit -m "Experiment 1: empty class, macOS run" && git pull --rebase && git push
```

## Result

Run 9 September 2026.

| What | Expected | Measured on `mac` |
| --- | --- | --- |
| `sources.txt`, three files | `2a766d57…` `079f65f3…` `8628a3a4…` | verified |
| `csc.dll` | `644a4d336dcd11a7…` | **`1824569732a63f5d…`**, differed |
| `minlib.dll`, build 1 | `4b3808d1…` | `4b3808d1…` |
| `minlib.dll`, build 2 | as build 1 | `4b3808d1…` |
| Embedded PDB path | `/private/tmp/rb1/obj/…` | `/private/tmp/rb1/obj/Release/net9.0/minlib.pdb` |

The SDK resolved to `Base Path: /Users/peterjuulmoller/.dotnet/sdk/9.0.120/`,
`RID: osx-arm64`, host 9.0.19, the same host as `ubuntu-vm`. Full block in
`data/2026-09-09-empty-class/macos/environment.txt`.

## Interpretation

**Both at once: the control failed, and the hash landed anyway.**

That outcome was in none of the three columns above. The expectation was that a
different `csc.dll` would mean we were measuring a third compiler and therefore
could not answer the OS question. That inference was wrong, and that is the
run's real finding.

**1. Operating system and CPU are ruled out.** Three environments, two operating
systems, two CPU architectures, one number. `minlib.dll` came out `4b3808d1…` on
macOS 14.6 arm64, byte for byte the same as on Ubuntu x86-64. The hypothesis from
7 September holds: the managed layer carries across. It is the strongest result
in the project so far.

**2. The compiler's bytes do not decide the output, its declared identity does.**
There are now three `csc.dll` behind the string `9.0.120`:

| | `csc.dll` | SDK Commit | MSBuild | Roslyn | `minlib.dll` |
| --- | --- | --- | --- | --- | --- |
| The Arch package | `1b7543aa…` | `d0558bff3d` | `+d0558bff3` | `+d0558bff…` (`dotnet/dotnet`) | `541bed82…` |
| Microsoft linux-x64 | `644a4d33…` | `3f97250e38` | `+07da1b9a8` | `+fc52718e…` (`dotnet/roslyn`) | `4b3808d1…` |
| Microsoft osx-arm64 | `1824569732a63f5d…` | `3f97250e38` | `+07da1b9a8` | `+fc52718e…` (`dotnet/roslyn`) | `4b3808d1…` |

The bottom two are **different files with identical declared identity**. Every
string is the same: SDK commit, MSBuild commit, Roslyn version, commit hash and
host (`9.0.19` / `8381bdb01f`), and they gave the same output. The top one has
different strings and gave different output. It is the identity strings that
travel out into the artefact, not the file's hash.

That is the counterfactual case 8 September could not deliver.

Compiler-identity made the right intervention: Microsoft's 9.0.120 downloaded
beside the Arch package, same pin, same path, same machine. That run settled
that **the SDK** decides the output and not the machine. But it could not settle
*which property of the SDK* does it. The reason is in its own `compilers.txt`:
Microsoft's `csc.dll` on `arch` was `644a4d33…`, **byte-identical** with the
VM's. Bytes and strings travelled together and both fitted. Two explanations,
"the compiler's bytes decide" and "the compiler's declared identity decides",
therefore both predict `4b3808d1…` for that run. It confirms both and separates
neither.

`osx-arm64` is the first case where the two explanations predict different
outcomes: same strings, different bytes. The byte explanation predicts a new
hash, the identity explanation predicts `4b3808d1…`. `4b3808d1…` came out.

The expectation section in this note followed the byte explanation: the run was
gated on `csc.dll` being `644a4d33…`, and a deviation had been written down in
advance as "then we are measuring a third compiler and cannot answer the OS
question". That was wrong, and it stays up there as it was written.

The mechanism behind the byte difference is probably ReadyToRun: `csc.dll` on
`mac` contains an `RTR` signature, that is AOT-compiled native code, and it is
architecture-specific. Same IL and same metadata, different native layer. That
explains how the files can differ without the output differing.

### What this corrects in the conclusion from 8 September

[Compiler-identity](2026-09-08-compiler-identity.md) and
[the day's findings](2026-09-08-findings.md) concluded that "bit identity is
stricter than code identity", and that .NET's deterministic build binds the
artefact's identity to **the compiler's identity** understood as its bytes. The
wording has to be tightened:

- **The requirement is not a bit-identical compiler binary.** That is
  demonstrated here: a different binary hit the same artefact. The requirement is
  the same Roslyn version **and** the same commit hash, which are the strings
  written into the PDB.
- **The consequence for a distribution stands, but for a different reason.** Arch
  cannot hit Microsoft's artefacts, not because they built a different binary,
  but because they built from a different source tree and therefore stamp in a
  different commit string. If they built from `dotnet/roslyn` at the same commit,
  the result here suggests they could hit, even though the binary would differ.
- **The caveat from 8/9 about the mechanism is therefore met on one point and
  sharpened on another.** It was correct that Roslyn's deterministic hash takes
  in the compiler's identity. It was wrong to read "identity" as "bytes".

It is still an observation, not a reading of Roslyn's source. But it now rests
on three compilers and three runs instead of two, and one of the three is
exactly the counterfactual case that separates the two explanations.

### Caveats

- **R2R is inferred, not verified against the Linux file.** The `RTR` signature
  is measured in the `mac` build; that the Linux build has the same with x64 code
  instead is assumed. It is settled by hashing the IL part of both files, not the
  whole file.
- **Only one commit tested.** That the same commit gives the same output is shown
  for `fc52718e…` on two platforms. Whether it generalises has not been tested.
- **Host and RID travelled with the SDK again.** `Host: 9.0.19` happens to be the
  same as `ubuntu-vm`, so the host version is still not independently ruled out;
  it is just no longer a suspect, since everything else varied around it.
- Same boundaries as 7 September: only `dotnet build`, no packing, no archives,
  no dependencies, one empty class.

## How to read the outcome

**`csc.dll` lands, and `minlib.dll` comes out `4b3808d1…`.** The strongest
result in the project so far: three environments, two operating systems, two CPU
architectures, one number. Then the hypothesis from 7 September is confirmed:
the managed layer carries across when the compiler binary is the same, and the
wording gets sharp. The artefact's identity follows the compiler, not the
machine. That is also the argument that has to carry on to the real artefact,
because it is exactly the property a vendor-independent verification would rest
on.

**`csc.dll` lands, but `minlib.dll` comes out something third.** Then OS or CPU
is in play after all, and the run has two axes in it. The next step is to
separate them, and the cheapest place is the CPU: install `--architecture x64`
beside it and build again on the same path. If *that* hits `4b3808d1…`, it was
the architecture; if it does not, it is the operating system. Either way compare
the environment blocks line by line. `Host Version` is a known candidate, because
it has never been independently ruled out (see the caveats in
[compiler-identity](2026-09-08-compiler-identity.md)).

**`csc.dll` does not land.** Then the run is not an OS test. Microsoft then
publishes different compiler bytes per RID under the same version number, and
*that* is itself a finding, a third binary behind the string `9.0.120` on top of
the two we already have. Write the hash down, run the build anyway, and keep the
two results apart: one says something about SDK publishing, the other nothing
about OS.

## What we do not measure here

- **The environment axes.** reprotest does not run on macOS. `mac` contributes
  measurement 1 and 3; the axes are in
  [environment-axes](2026-09-14-environment-axes.md).
- **The system's own 9.0.102.** It stays and is not measured. Had we built with
  it, we would be measuring a fourth compiler.
- Same boundaries as 7 September: only `dotnet build`, no packing, no archives,
  no dependencies, one empty class.
