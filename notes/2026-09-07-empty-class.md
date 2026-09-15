# Experiment 1: baseline experiment - empty class, dotnet

Run 7 September 2026. (The note was originally dated 8 September; the files in `data/` have mtime 7 September, and the date was corrected on 8/9 together with the directory names `leo`/`peter` → `arch`/`ubuntu-vm`. Nothing else in the text was changed after the run.)

The question: the same source, compiled twice, do the same bytes come out?

This checks whether the Roslyn compiler is deterministic.

We use an empty class on purpose. One file, no packages, nothing that can go
wrong for other reasons. If that is not reproducible, nothing larger is. The
glossary at the bottom explains the terms.

## Three environments

| Label | Machine | Runs | Result directory |
| --- | --- | --- | --- |
| `arch` | Leo's laptop, Arch Linux | measurement 1, 2, 3 | `~/Dev/Speciale2026/data/2026-09-07-empty-class/arch` |
| `mac` | Peter's laptop, macOS | not in the first run | `~/Dev/Speciale2026/data/2026-09-07-empty-class/macos` |
| `vm` | shared Ubuntu 24.04, DigitalOcean | measurement 1, 2, 3 | `~/Speciale2026/data/2026-09-07-empty-class/ubuntu-vm` |

**First run:** Leo takes `arch`, Peter takes `vm`. `mac` is saved for later; the
commands are still in the text, so it can be run without rewriting the protocol.

The repo is cloned on all three machines, so each machine writes directly into
its own subdirectory under `data/2026-09-07-empty-class/`. No files are moved
afterwards.

The commands below are for **Linux (`arch` and `vm`)**. Where macOS differs, a
`mac` variant follows. The result directory is `$UD` in all commands; it is set
in step 1.

## Three measurements

1. **Two builds on the same machine**, which says whether the apparatus works.
   All three environments.
2. **Environment variations with reprotest**, which differences can the build
   take? `arch` and `vm`; reprotest is a Linux tool and does not run on mac.
   `vm` can do one axis more than `arch`, because `disorderfs` is in apt.
3. **The hashes compared across machines**, is the result the same in three
   environments?

`arch` against `mac` is the interesting comparison: two operating systems, two
CPU architectures, uncontrolled variation. `vm` is the controlled environment and
a third data point; it does not replace the laptop comparison. If we run
everything on the VM, we measure one environment three times, and the question
disappears.

---

## Step 0: agree on two things first

**Same SDK version: 9.0.120.** It matches WS.Phoenix' CI (`9.0.x`), and Leo
already has it. With different compilers, a difference in measurement 3 can be
explained in three ways, and then we learn nothing. Check:

```bash
dotnet --list-sdks
```

**Same path.** The build path is written into the finished DLL, so it has to be
identical. On macOS `/tmp` is a symlink to `/private/tmp`, and if Peter builds in
`/tmp/rb1`, his file may say `/private/tmp/rb1` inside. So we use the real path
in all three places. On `arch` and `vm`, once:

```bash
sudo mkdir -p /private/tmp && sudo chmod 1777 /private/tmp
```

## Step 1: setup, once per machine

**`arch`** - reprotest and diffoscope are installed. `dpkg` does not exist, and
reprotest dies without it, because it asks for the machine's architecture:

```bash
mkdir -p ~/.local/bin; printf '#!/bin/sh\ncase "$1" in --print-architecture) echo amd64 ;; esac\nexit 0\n' > ~/.local/bin/dpkg; chmod +x ~/.local/bin/dpkg
```

**`vm`** - update first, or the environment block describes a machine that no
longer exists:

```bash
sudo apt update && sudo apt upgrade -y && sudo reboot
```

Then the helper tools. `disorderfs` is the one we do not have on Arch:

```bash
sudo apt install -y disorderfs faketime pipx
```

reprotest is installed with pipx and not with apt, so `vm` and `arch` run **the
same version of the instrument**. Two reprotest versions are two measuring
devices, and then the tables cannot be put side by side:

```bash
pipx install reprotest==0.7.32 && pipx ensurepath
```

0.7.32 is the version `arch` measured with (verified 7/9 2026). `pipx install reprotest` without a version gives the newest, and then the two tables are not
from the same instrument.

Same reason for diffoscope. Ubuntu's apt package is 259, `arch` has 329, and that
is many years of difference in how well it can explain a difference:

```bash
pipx install diffoscope==329
```

Check that this is the one being found, not the apt build. `~/.local/bin` must
come before `/usr/bin` in PATH:

```bash
diffoscope --version
```

The verdict `successful`/`failed` does not depend on which diffoscope you have:
two different files are caught by both. What changes is the explanation. 259 can
settle for saying that the binaries differ, where 329 unpacks the PE file and
shows the embedded PDB path. With only the old one, you can instead read the path
straight out of the DLL with the `grep` command in step 4.

The SDK in exactly the version `global.json` requires; apt gives a different
patch:

```bash
curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --version 9.0.120
```

It lands in `~/.dotnet`, which is not on PATH. Put the line in your shell profile
so it holds next time too:

```bash
export PATH="$HOME/.dotnet:$PATH"
```

Make an ordinary user each instead of sharing `root`, so the runs can be told
apart.

**`mac`** - nothing to install beyond `dotnet` (version 9.0.120) and `git`.

**All three** - set the result directory as `$UD`, so the rest of the commands
are the same. Two things differ per machine: where the repo is cloned, and what
the directory is called (`leo`, `peter`, `vm-ubuntu`). On laptops the clone is in
`~/Dev/Speciale2026`, on the VM in `~/Speciale2026`.

bash and zsh (Peter's mac, the VM):

```bash
export UD=$HOME/Speciale2026/data/2026-09-07-empty-class/ubuntu-vm && mkdir -p "$UD"
```

fish (Leo's machine):

```bash
set -gx UD $HOME/Dev/Speciale2026/data/2026-09-07-empty-class/arch; mkdir -p $UD
```

**The syntax is not the same.** `set -gx` exists only in fish; in bash it fails
with `set: -g: invalid option`, and `$UD` ends up empty. If `$UD` is empty,
`tee -a $UD/hashes.txt` becomes `tee -a /hashes.txt` and fails with
`Permission denied`. Always check first:

```bash
echo $UD && ls -d "$UD"
```

The variable disappears with a new tab or a new ssh session. Put the line in
`~/.bashrc` or `~/.config/fish/config.fish` for as long as the experiment runs.

## Step 2: the project, three files written by hand

We do not use `dotnet new`. That template follows the SDK version, so two
different SDKs can produce different source, and then we measure the template
instead of the compiler.

The directory, and a check that it is the same *physical* path. `pwd -P` follows
symlinks all the way:

```bash
mkdir -p /private/tmp/rb1 && cd /private/tmp/rb1 && pwd -P
```

It must say `/private/tmp/rb1` in all three environments. If it does not: stop.

The project file:

```bash
printf '<Project Sdk="Microsoft.NET.Sdk">\n  <PropertyGroup>\n    <TargetFramework>net9.0</TargetFramework>\n  </PropertyGroup>\n</Project>\n' > /private/tmp/rb1/minlib.csproj
```

The source:

```bash
printf 'namespace Minlib;\n\npublic class Beregning\n{\n    public int Tal() => 42;\n}\n' > /private/tmp/rb1/Beregning.cs
```

The SDK lock:

```bash
printf '{\n  "sdk": {\n    "version": "9.0.120",\n    "rollForward": "disable"\n  }\n}\n' > /private/tmp/rb1/global.json
```

Check that the pin works before building anything. `dotnet --version` looks up
`global.json` from the directory you are standing in:

```bash
cd /private/tmp/rb1 && dotnet --version
```

It must say `9.0.120`. Outside the directory you get your newest SDK instead, on
Leo's machine 10.0.111. That is the whole difference, and it is easy to miss.

Confirm that the right file is being found:

```bash
cd /private/tmp/rb1 && dotnet --info | grep -A 1 'global.json file'
```

It must say `/private/tmp/rb1/global.json`. If it says `Not found`, the file is
in the wrong place, and you are building with a different compiler without being
told.

With `rollForward: disable` the build also fails loudly if 9.0.120 is not
installed, which is the point. A build that succeeds is therefore itself proof
that the pin was respected.

Finally, check that we have exactly the same bytes:

```bash
cd /private/tmp/rb1 && sha256sum minlib.csproj Beregning.cs global.json | tee "$UD/sources.txt"
```

`mac` - same algorithm, different command name:

```bash
cd /private/tmp/rb1 && shasum -a 256 minlib.csproj Beregning.cs global.json | tee "$UD/sources.txt"
```

`tee` and not just the screen: the three numbers are the proof that the machines
measured the same source. Without the file, "we had the same input" is a claim
nobody can check afterwards.

Expected:

| File | sha256 |
| --- | --- |
| `minlib.csproj` | `2a766d57249ab657b48234557ff2c6a76...` |
| `Beregning.cs` | `079f65f3d3a0c041bb61817e68762b5a6...` |
| `global.json` | `8628a3a4483b68445847707e60dd11611...` |

The hash on `global.json` holds for version 9.0.120. Pick another and it changes,
but the three numbers must be the same in all three environments. That is the
actual check.

## Step 3: the environment block, before the measurement

The build environment is everything outside the source that can affect the
result: SDK version, operating system, language settings, file permissions, the
version of the measuring tool. It must be written down *before* we measure. If
measurement 3 shows a difference, this block is what says why.

`dotnet --info` must be run **from the project directory**, not from the result
directory. Outside `/private/tmp/rb1` the `global.json` does not apply, and then
the block describes a different SDK from the one that builds:

```bash
cd /private/tmp/rb1 && dotnet --info > $UD/environment.txt
```

The machine itself:

```bash
uname -srm >> $UD/environment.txt; umask >> $UD/environment.txt; locale | head -1 >> $UD/environment.txt; diffoscope --version >> $UD/environment.txt 2>&1; pipx list >> $UD/environment.txt 2>&1
```

And which binaries are actually found, not which are installed:

```bash
command -v dotnet reprotest diffoscope >> $UD/environment.txt
```

That line is not decoration. On the VM there are two builds of all three tools:
apt has `dotnet` with SDK 10.0.111, `reprotest` 0.7.26 and `diffoscope` 259 in
`/usr/bin`, while the versions the experiment requires live in `~/.dotnet` and
`~/.local/bin`. `pipx list` shows 0.7.32 regardless of which one runs. Without
`command -v` the evidence records what was installed, not what measured.

And the compiler, as files and not as a version number:

```bash
cd /private/tmp/rb1 && sha256sum "$(dotnet --info | sed -n 's/^ *Base Path: *//p')Roslyn/bincore/csc.dll" | tee -a $UD/environment.txt
```

`tee` instead of `>>`, so you see the result immediately instead of discovering
an empty line later. If it fails, there are three things to check, in this order:
`command -v dotnet` (is it installed in `~/.dotnet` without being on PATH?),
`pwd` (are you in the project directory?) and `echo $UD`.

If the expression still does not work, find the file directly instead of deriving
the path:

```bash
find ~/.dotnet /usr/share/dotnet -path '*9.0.120/Roslyn/bincore/csc.dll' 2>/dev/null
```

and run `sha256sum` on that path. The line is documentation, not a measurement.
It is only needed when measurement 3 has to be explained, so it must not block
the reprotest runs.

`umask` and `locale` are two of the axes reprotest varies in measurement 2, so
they have to be in the block for the table to be readable afterwards. `pipx list`
catches the reprotest version. And `csc.dll` is the C# compiler itself: its hash
is the only thing that actually identifies what built. The version number is a
string.

## Step 4: measurement 1, two builds on the same machine

The boring check. Build, and write down the hash:

```bash
cd /private/tmp/rb1; dotnet build -c Release; sha256sum bin/Release/net9.0/minlib.dll | tee -a $UD/hashes.txt
```

`mac`:

```bash
cd /private/tmp/rb1; dotnet build -c Release; shasum -a 256 bin/Release/net9.0/minlib.dll | tee -a $UD/hashes.txt
```

And again, with `rm -rf bin obj` in front, so it is a clean build and not a reuse
of last time:

```bash
cd /private/tmp/rb1; rm -rf bin obj; dotnet build -c Release; sha256sum bin/Release/net9.0/minlib.dll | tee -a $UD/hashes.txt
```

**Expected:** two identical hashes. The compiler does not waver on its own.

If they differ: stop. Then something is wrong in the setup, and measurement 2
will only show noise.

### Seeing the build path inside the binary

Worth doing in all three environments. It shows with your own eyes the mechanism
measurement 2 is about:

```bash
cd /private/tmp/rb1 && env LC_ALL=C grep -ao '/[A-Za-z0-9_/.-]*rb1[A-Za-z0-9_/.-]*' bin/Release/net9.0/minlib.dll | sort -u
```

There is the absolute path written into the compiled file, a reference to the PDB
file. That is why two directories give two different DLLs even though the code is
the same.

## Step 5: measurement 2, environment variations (`arch` and `vm`)

reprotest builds the project twice, changes exactly one thing between the two
builds, and compares the result. If there is a difference, it calls diffoscope,
which explains *what* differs instead of just saying the bytes do not match.

Clean up first, or reprotest copies old build output into its test directory:

```bash
rm -rf /private/tmp/rb1/bin /private/tmp/rb1/obj
```

Stand in the result directory so the log files land in the right place. reprotest
builds in its own temporary directory, so the build does not happen here:

```bash
cd $UD
```

`--vary=-all` means "vary nothing". `--vary=-all,+umask` means "vary only umask".
One axis at a time, so an outcome always has exactly one explanation.

Always redirect to a file. If you pipe the output, reprotest looks like it hangs
for many minutes, because it leaves a child process holding the connection open
after it has stopped itself.

**On `vm` the binaries must be named with full paths.** `~/.local/bin` and
`~/.dotnet` are only first in PATH because `~/.bashrc` puts them there, and
`~/.bashrc` is not read by non-interactive shells, which are the ones reprotest
builds in. If the build command hits `/usr/bin/dotnet`, it fails with "SDK 9.0.120
not found", and the error looks like a reprotest problem. The `+exec_path` axis
also manipulates PATH on purpose. So on the VM each run becomes:

```bash
/root/.local/bin/reprotest --vary=-all -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 /root/.dotnet/dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-1-none.log 2>&1
```

Check beforehand, from an ordinary terminal in the project directory. It must say
`/root/.dotnet/dotnet`, `/root/.local/bin/...`, `9.0.120` and `329`:

```bash
command -v dotnet reprotest diffoscope; dotnet --version; diffoscope --version
```

The commands below are written for `arch`, where `dotnet` in `/usr/bin` is the
right one. On `vm` the full paths are substituted as above.

No variation:

```bash
reprotest --vary=-all -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-1-none.log 2>&1
```

File permissions:

```bash
reprotest --vary=-all,+umask -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-2-umask.log 2>&1
```

Language and character set:

```bash
reprotest --vary=-all,+locales -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-3-locales.log 2>&1
```

Where the tools are found (PATH):

```bash
reprotest --vary=-all,+exec_path -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-4-exec_path.log 2>&1
```

The build path:

```bash
reprotest --vary=-all,+build_path -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-5-build_path.log 2>&1
```

The clock:

```bash
reprotest --vary=-all,+time -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-6-time.log 2>&1
```

**`vm` only** - file order on disk. The axis requires `disorderfs`, which does
not exist on Arch. This is the axis that has so far been listed as "not tested":

```bash
reprotest --vary=-all,+fileordering -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-7-fileordering.log 2>&1
```

Expect 60-90 seconds per run, longer on the VM if it only has one vCPU. The whole
table on one line:

```bash
grep -H -E 'Reproduction (successful|failed)' rt-*.log
```

**Expected:** `successful` on every axis except `+build_path`.

The reason is the whole thesis in miniature: the DLL contains a reference to its
PDB file, and that reference is an absolute path. Build in a different directory
and a different path is written inside the DLL, so it is not bit-identical even
though the code is the same.

diffoscope's explanation:

```bash
grep -B 3 -A 12 'pdb' rt-5-build_path.log
```

If an axis fails that we did not expect, the log file is the answer. That is why
they belong in the repo.

## Step 6: measurement 3, three environments compared

No new commands. We compare `hashes.txt` and `environment.txt` from the three
machines.

The hypothesis is that the operating system does not matter: a DLL from a class
library contains IL, the intermediate code .NET compiles to, which is independent
of processor type. With the same compiler and the same path the result *should*
be bit-identical across Linux and macOS, also when one machine is x64 and the
other arm64. Whether that holds, we do not know. That is why it is worth
measuring.

- **Identical hashes:** the managed layer carries across operating systems. A
  result that can be cited, and the basis for moving on to the real artefact.
- **Different hashes:** compare the environment blocks line by line and find the
  one that differs. Then the next run is the same recipe with that one difference
  closed, one variable at a time, nothing else.

**Measured on `arch` 7 September 2026:**

| What | sha256 |
| --- | --- |
| `minlib.dll`, two clean builds | `541bed823d12e42b5e9e6087c9c32a9d6fbaa9a116aae61fc00c808231e74113` (identical both times) |
| `csc.dll` from SDK 9.0.120 | `1b7543aa709363b6f05273134f8c501b392ebb7480689008a1cc880ae8c38212` |

The SDK was the Arch package `dotnet-sdk-9.0 9.0.19.sdk120-1`, reprotest 0.7.32,
diffoscope 329, `LANG=da_DK.UTF-8`, `umask 0022`, kernel 7.1.8-arch1-3.
Full block in `data/2026-09-07-empty-class/arch/environment.txt`.

`arch` against `vm` is the first run's real comparison: two Linux machines, same
architecture, same SDK version number. And here there is a good chance the hashes
differ, for a reason worth understanding.

**The same version number is not the same compiler.** Arch builds .NET from
source; Leo's SDK comes from the package `dotnet-sdk-9.0 9.0.19.sdk120-1` and
lives in `/usr/share/dotnet`. Peter's comes from Microsoft's `dotnet-install.sh`
and is Microsoft's own binary release. Both call themselves 9.0.120.

If the DLLs differ, the `csc.dll` hash from the environment block is the first
place to look: if it differs, we measured two different compilers, not two
different environments. That is precisely the gap the thesis is about, a version
being a self-declared string rather than a binding to a binary, showing up in our
own measuring apparatus.

## Step 7: save it, from each machine

Each machine commits its own directory. Three machines on the same branch means
`git pull --rebase` must be run before push, every time:

```bash
cd ~/Dev/Speciale2026 && git add data notes && git commit -m "Experiment 1: empty class, arch run" && git pull --rebase && git push
```

Change the message to `mac run` or `vm run` depending on which machine you are
sitting at.

On the VM: set `user.name` and `user.email` for your own user, or the history of
a public repo says `root@ubuntu-...`, and then you cannot see who ran what:

```bash
git config --global user.name "Dit Navn" && git config --global user.email "din@mail.dk"
```

---

## Result form

Filled in as we run. These are the numbers the note is supposed to contain.

| Measurement | Varies | Expected | `arch` | `mac` | `vm` |
| --- | --- | --- | --- | --- | --- |
| 1 - two builds | nothing | same hash | same | | |
| 2 - rt-1-none | nothing | successful | | n/a | |
| 2 - rt-2-umask | file permissions | successful | | n/a | |
| 2 - rt-3-locales | language, character set | successful | | n/a | |
| 2 - rt-4-exec_path | PATH | successful | | n/a | |
| 2 - rt-5-build_path | the build directory | failed | | n/a | |
| 2 - rt-6-time | the clock | successful | | n/a | |
| 2 - rt-7-fileordering | file order | unknown | n/a | n/a | |
| 3 - DLL hash | OS, CPU, distro | unknown | `541bed82…` | | |

## What we do not measure

- **The packaging layer.** Only `dotnet build`, not `dotnet pack`. Packing has
  its own sources of noise, and they belong in a later experiment.
- **Peter's environment variations on his own machine.** reprotest does not run
  on mac. His contribution is measurement 1 and 3; the VM covers the variations.
- **The container.** The VM is an environment we clicked our way to, not one
  described as data. A pinned image is the next step, not this one.
- **Real software.** An empty class has no dependencies, no frontend and no
  native libraries. This is the baseline, not the result.

## Glossary

- **bit-identical** - two files are the same down to every single byte, not just
  "the same content".
- **hash, sha256** - a fingerprint of bytes. The same bytes always give the same
  fingerprint; one byte of difference gives a completely different one. That is
  why we compare hashes instead of files.
- **DLL** - the compiled code, the actual result of the build.
- **IL** - Intermediate Language. The intermediate code .NET compiles the source
  to. Independent of processor type; the translation to machine code happens
  first at run time.
- **PDB** - the debugging file, which maps from machine code back to lines in the
  source. The DLL contains a reference to it, and the reference is an absolute
  path.
- **build environment** - everything outside the source that can affect the
  result: SDK version, operating system, language settings, file permissions, the
  clock, the build path.
- **variation, axis** - the one thing reprotest changes between its two builds.
- **reprotest** - tool that builds twice with one controlled difference and
  compares the result. Written for Debian; runs only on Linux.
- **diffoscope** - tool that unpacks two files and explains what separates them,
  in readable form. reprotest calls it automatically on a difference.
- **disorderfs** - file system that deliberately hands out files in random order.
  That is what reprotest uses for `+fileordering`. In apt, not on Arch.
- **umask** - the mask that decides which permissions new files get.
- **locale** - the language and character set setting, for example `da_DK.UTF-8`.
- **rollForward: disable** - the line in `global.json` that forbids `dotnet` from
  using an SDK version other than the one given. If the version is missing, the
  build fails loudly instead of quietly using a different compiler.
- **PathMap** - the setting that can later replace the absolute build path with a
  fixed string. We do not use it here; first we need to see the problem.

---

## Result and interpretation (added 8 September 2026)

Written the day after the run. The text above stands as it was when we measured;
this is appended, not woven in.

**Two builds on the same machine: identical, in both places. Between the two
machines: different.**

| Environment | `minlib.dll` |
| --- | --- |
| `arch` | `541bed823d12e42b5e9e6087c9c32a9d6fbaa9a116aae61fc00c808231e74113` |
| `ubuntu-vm` | `4b3808d1cc1d642577f60a054905f5f065aab8b9aea1765b407fc583cef70d33` |

Each hash appears twice in its `hashes.txt`, from two clean builds with
`rm -rf bin obj` in between. Measurement 1 therefore held in both places: the
compiler does not waver on its own. Measurement 3 failed.

The source and the path are ruled out. Both environment blocks say
`global.json file: /private/tmp/rb1/global.json`, so the build directory was the
same string. That leaves four differences:

| | `arch` | `ubuntu-vm` |
| --- | --- | --- |
| `csc.dll` | `1b7543aa709363b6…` | `644a4d336dcd11a7…` |
| The SDK's origin | The Arch package `dotnet-sdk-9.0 9.0.19.sdk120-1`, built from source by the distribution | Microsoft's binary release via `dotnet-install.sh` |
| RID | `arch-x64` | `linux-x64` |
| `LANG` | `da_DK.UTF-8` | `C.UTF-8` |

The prime suspect is the first: two different compilers, both called 9.0.120.
That is the thesis' own claim showing up in the measuring apparatus, the version
number is a self-declared string, not a binding to a binary. Whether it is
actually the explanation is settled in
[compiler-identity](2026-09-08-compiler-identity.md).

The environment variations (step 5 above) were not run on the 7th; they are in
[environment-axes](2026-09-14-environment-axes.md).

### Gaps in the evidence

- **The source check was not saved.** The command only printed to the screen, so
  we have no written proof that the three input files were identical on the two
  machines. The files sit untouched in both labs, so it can be collected
  afterwards, but that becomes evidence gathered 8/9 for a run from 7/9, and it
  has to be written that way.
- **`command -v` was not recorded.** On the VM there are two builds of every
  tool, so `pipx list` alone does not say what ran.
