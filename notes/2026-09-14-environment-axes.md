# Experiment 2: environment variations

Run 14 September 2026 on `arch` (Leo's laptop, 14:13-14:15 CEST) and
`ubuntu-vm` (shared droplet, 14:14-14:16 CEST). The protocol was written 8-9
September and sat for two days before it was run.
Builds on [empty-class](2026-09-07-empty-class.md): same lab, same three files,
same pinned SDK. The terms are in the glossary there.

Data: `data/2026-09-14-environment-axes/arch/` and `.../ubuntu-vm/`.

The question: **which differences in the build environment can the build take?**

Experiment 1 showed that two builds in the same environment give the same bytes.
That does not say what happens when the environment changes. reprotest builds
twice and changes one thing between the builds: file permissions, language,
PATH, build directory, clock, or file order. It then compares the result. One
axis per run, so each outcome has one explanation.

## Expectation, written before the run

Everything `successful` except `+build_path`, which fails. The DLL contains a
reference to its PDB file, and that reference is an absolute path. Build in a
different directory, and a different string sits inside the binary.

`+fileordering` is unknown: it requires `disorderfs` and can only run on
`ubuntu-vm`, so it has not been measured before.

`+umask` and `+locales` are expected green, but for a specific reason.
Permissions and file order are exactly what zip and tar archives store. Here no
archives are produced, only loose files. A DLL stores neither permissions nor
order. The green cells are therefore conditional on there being no packaging
step, and that has to go in the conclusion.

## Before the run

The lab from 7/9 has to be in place, and yesterday's build output has to go.
Otherwise reprotest copies it into its test directory:

```bash
rm -rf /private/tmp/rb1/bin /private/tmp/rb1/obj
```

The result directory. The clone is in `~/Dev/Speciale2026` on laptops and in
`~/Speciale2026` on the VM:

```bash
export UD=$HOME/Speciale2026/data/2026-09-14-environment-axes/ubuntu-vm && mkdir -p "$UD"
```

`arch` uses fish:

```bash
set -gx UD $HOME/Dev/Speciale2026/data/2026-09-14-environment-axes/arch; mkdir -p $UD
```

Record the environment block again. It is a new day and a new experiment, and on
`ubuntu-vm` 2 GB of swap has been added since yesterday:

```bash
cd /private/tmp/rb1 && dotnet --info > "$UD/environment.txt"
```

```bash
uname -srm >> "$UD/environment.txt"; umask >> "$UD/environment.txt"; locale | head -1 >> "$UD/environment.txt"; diffoscope --version >> "$UD/environment.txt" 2>&1; command -v dotnet reprotest diffoscope >> "$UD/environment.txt"
```

And check that the right binaries are being found:

```bash
cd /private/tmp/rb1 && command -v dotnet reprotest diffoscope; dotnet --version; diffoscope --version
```

Expected on `arch`: `/usr/bin/dotnet`, `9.0.120`, `diffoscope 329`, reprotest from
`~/.local/bin`. Expected on `ubuntu-vm`: `/root/.dotnet/dotnet`,
`/root/.local/bin/reprotest`, `/root/.local/bin/diffoscope`, `9.0.120`, `329`.

**On `ubuntu-vm` the binaries are named with full paths in the run itself.** apt
has its own builds in `/usr/bin`: `dotnet` with SDK 10.0.111, reprotest 0.7.26,
and diffoscope 259. The right ones are only first in PATH because `~/.bashrc`
puts them there. `~/.bashrc` is not read by non-interactive shells, which are
the shells reprotest builds in. If the build command hits `/usr/bin/dotnet`, it
fails with "SDK 9.0.120 not found", and the error looks like a reprotest
problem. The `+exec_path` axis also changes PATH on purpose.

## The runs

Stand in the result directory so the log files land in the right place. reprotest
builds in its own temporary directory, so the build does not happen here:

```bash
cd "$UD"
```

Always redirect to a file. If you pipe the output, reprotest looks like it hangs
for many minutes: it leaves a child process holding the connection open after it
has stopped itself. Expect 60-90 seconds per run, longer on the VM.

`arch`:

```bash
reprotest --vary=-all -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-1-none.log 2>&1
```

`ubuntu-vm`, same run, full paths:

```bash
/root/.local/bin/reprotest --vary=-all -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 /root/.dotnet/dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-1-none.log 2>&1
```

The other axes, `arch`:

```bash
reprotest --vary=-all,+umask -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-2-umask.log 2>&1
```

```bash
reprotest --vary=-all,+locales -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-3-locales.log 2>&1
```

```bash
reprotest --vary=-all,+exec_path -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-4-exec_path.log 2>&1
```

```bash
reprotest --vary=-all,+build_path -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-5-build_path.log 2>&1
```

```bash
reprotest --vary=-all,+time -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-6-time.log 2>&1
```

And `ubuntu-vm`, where `+fileordering` is added:

```bash
/root/.local/bin/reprotest --vary=-all,+umask -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 /root/.dotnet/dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-2-umask.log 2>&1
```

```bash
/root/.local/bin/reprotest --vary=-all,+locales -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 /root/.dotnet/dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-3-locales.log 2>&1
```

```bash
/root/.local/bin/reprotest --vary=-all,+exec_path -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 /root/.dotnet/dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-4-exec_path.log 2>&1
```

```bash
/root/.local/bin/reprotest --vary=-all,+build_path -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 /root/.dotnet/dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-5-build_path.log 2>&1
```

```bash
/root/.local/bin/reprotest --vary=-all,+time -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 /root/.dotnet/dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-6-time.log 2>&1
```

```bash
/root/.local/bin/reprotest --vary=-all,+fileordering -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 /root/.dotnet/dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-7-fileordering.log 2>&1
```

`+fileordering` can only run there, because it requires `disorderfs`.

The whole table on one line:

```bash
grep -H -E 'Reproduction (successful|failed)' rt-*.log
```

diffoscope's explanation for the failing run:

```bash
grep -B 3 -A 12 'pdb' rt-5-build_path.log
```

## Result

| Axis | Varies | Expected | `arch` | `ubuntu-vm` |
| --- | --- | --- | --- | --- |
| `rt-1-none` | nothing | successful | successful | successful |
| `rt-2-umask` | file permissions | successful | successful | successful |
| `rt-3-locales` | language, character set | successful | successful | successful |
| `rt-4-exec_path` | PATH | successful | successful | successful |
| `rt-5-build_path` | the build directory | failed | **failed** | **failed** |
| `rt-6-time` | the clock | successful | successful | successful |
| `rt-7-fileordering` | file order | unknown | n/a | successful |

Thirteen runs, thirteen outcomes as predicted. `[V]`, the verdicts appear as
`Reproduction successful`/`failed` in `rt-*.log` under `data/`. Duration was
5-12 seconds per run on `arch` and 10-19 on `ubuntu-vm`; not the 60-90 seconds
the 25/8 note expected, because the project has no packages to fetch.

If an axis fails unexpectedly, the log file is the answer. If
`rt-7-fileordering` fails with a mount error instead of a build error, it is
FUSE and not a finding.

## Interpretation

**`+build_path` fails for exactly the reason the expectation gave, and only
that.** The control build sits in `…/const_build_path`, the experiment in
`…/build-experiment-1`: two characters longer. diffoscope shows via pedump that
`.text` grows from `0x648` to `0x64c`, four bytes, because the path sits in the
debug directory. The CodeView entry points at the PDB's absolute path, and the
string is rounded up to a four-byte boundary. Everything after the string shifts
four bytes: entry point `0x2642` → `0x2646`, import table `0x25f0` → `0x25f2`.
`TimeDateStamp` also changes, as it must when it is a content hash and not a
clock. No other differences. The same four bytes on both machines. `[V]`
(`rt-5-build_path.log`, both directories)

**Side finding: "successful" only holds within the run.** reprotest makes a new
`/tmp/reprotest.XXXXXX/` per run, and control and experiment both build in
`const_build_path` under it. The six random characters in the directory name are
enough: the six green runs on `arch` gave six different DLL hashes, the seven on
`ubuntu-vm` seven different ones, and none of them is `541bed82…`/`4b3808d1…`
from experiment 1, which was built in `/private/tmp/rb1`. `[V]` (last line in
each `rt-*.log`). reprotest's verdict "reproducible" therefore means "identical
to a control build in the same directory", and the experiment itself shows why
that is not enough. Without `PathMap` or `DebugType=none`, the hash is bound to
the build directory, and the *length* of the path is enough to change the
binary.

**The five green axes are green on their own terms.** `+umask` and
`+fileordering` are green because there is no archive step (see the
expectation); `+time` is green because `TimeDateStamp` is not a timestamp, the
same mechanism that explained 8/9's 70 bytes. `+locales` and `+exec_path` show
that neither language setting nor PATH order leaks into an IL-only DLL. It is
the managed layer that carries, not the toolchain as a whole.

**`+fileordering` really was measured.** An extra run with `--verbosity 2`
(`rt-7-fileordering-verbose.log`) shows that disorderfs was mounted with
`--shuffle-dirents=yes` and logged "shuffling directory entries" and "reversing
directory entries". `[V]` But the project has one source file, so there is only
the `obj/` content and the project directory to shuffle. With more `.cs` files,
MSBuild's glob sorting decides the outcome; that is not tested here.

Overall: **the build takes everything reprotest can vary, except its own
location.** It is a narrow channel (one string in the debug directory), and it
is closable with `PathMap` or without a PDB. That is the next experiment, not
this one.

## Caveats

- **reprotest simulates variation on one machine.** It answers "is the build
  sensitive to the axes we know about", not "is it identical when everything we
  did not think of also changes". The second question is experiment 1's, and
  that one failed. - **The two Linux environments run the same reprotest version
  (0.7.32, pipx), but a different diffoscope** if PATH on the VM points at the
  apt build. The verdict is robust: two different files are caught by both, but
  the explanation is worse with 259 than with 329. - **No archives.** See the
  expectation above: the green cells for `+umask` and `+fileordering` do not
  mean the sources are absent, only that nothing writes them down. - **The
  `+time` axis can run here** because the project has no dependencies. With
  packages, the shifted clock topples the TLS handshake against NuGet, and the
  axis becomes untestable without an offline cache. - **pedump is two different
  programs.** On `arch` it is the Ruby gem `pedump` (section table, imphash), on
  `ubuntu-vm` Mono's `pedump` (COFF/PE Header format). diffoscope 329 on both,
  but the explanation's layout differs. The verdict and the four bytes are the
  same. - **Protocol from 8-9 September, run 14 September.** The lab and the
  three source files are unchanged since 7/9 (same `sources.txt` hashes). Note
  and data directory are named after the day of the run; earlier references to
  `2026-09-08-…` and `2026-09-09-environment-axes` have been corrected. -
  **`+fileordering` with one source file** says little about real sensitivity;
  see the interpretation. - **Not tested:** `user_group`, `domain_host`,
  `num_cpus`, `aslr`, `kernel`, `timezone`. `PathMap` against `+build_path` was
  run the same day:
  [environment-axes-pathmap](2026-09-14-environment-axes-pathmap.md).
  `DebugType=none` is still not tested.
