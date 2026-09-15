# Experiment 1, repeated

Run 8 September 2026 on `arch` and `ubuntu-vm`. Same protocol as
[7 September](2026-09-07-empty-class.md): same lab, same three files, same
pinned SDK. The procedure is written there and is not repeated here.

Data: `data/2026-09-08-empty-class/arch/` and `.../ubuntu-vm/`.

The question: **do yesterday's numbers come out again?**

This is not repetition for its own sake. It is the first test of whether the
protocol works as a protocol, whether a description is enough to hit the same
number on another day. And the environment has shifted slightly since yesterday:
`ubuntu-vm` has been given 2 GB of swap, and both machines have been rebooted or
shut down along the way.

## Expectation, written before the run

| Environment | `minlib.dll` |
| --- | --- |
| `arch` | `541bed823d12e42b5e9e6087c9c32a9d6fbaa9a116aae61fc00c808231e74113` |
| `ubuntu-vm` | `4b3808d1cc1d642577f60a054905f5f065aab8b9aea1765b407fc583cef70d33` |

The source hashes must be `2a766d57…`, `079f65f3…`, `8628a3a4…` in both places,
and `csc.dll` must be `1b7543aa…` on `arch` and `644a4d33…` on `ubuntu-vm`.

If other numbers come out, that is a finding and not an error: then something in
the environment has changed that we have not described, and today's environment
blocks against yesterday's say what.

## The run

The result directory first. `arch` (fish):

```bash
set -gx UD $HOME/Dev/Speciale2026/data/2026-09-08-empty-class/arch; mkdir -p $UD
```

`ubuntu-vm` (bash):

```bash
export UD=$HOME/Speciale2026/data/2026-09-08-empty-class/ubuntu-vm && mkdir -p "$UD"
```

The source is the same as yesterday and is not written again, but this time the
check is saved:

```bash
cd /private/tmp/rb1 && sha256sum minlib.csproj Beregning.cs global.json | tee "$UD/sources.txt"
```

The pin, from the project directory:

```bash
cd /private/tmp/rb1 && dotnet --version
```

The environment block:

```bash
cd /private/tmp/rb1 && dotnet --info > "$UD/environment.txt"
```

```bash
uname -srm >> "$UD/environment.txt"; umask >> "$UD/environment.txt"; locale | head -1 >> "$UD/environment.txt"; diffoscope --version >> "$UD/environment.txt" 2>&1; command -v dotnet reprotest diffoscope >> "$UD/environment.txt"
```

```bash
cd /private/tmp/rb1 && sha256sum "$(dotnet --info | sed -n 's/^ *Base Path: *//p')Roslyn/bincore/csc.dll" | tee -a "$UD/environment.txt"
```

Two clean builds:

```bash
cd /private/tmp/rb1; rm -rf bin obj; dotnet build -c Release; sha256sum bin/Release/net9.0/minlib.dll | tee -a "$UD/hashes.txt"
```

```bash
cd /private/tmp/rb1; rm -rf bin obj; dotnet build -c Release; sha256sum bin/Release/net9.0/minlib.dll | tee -a "$UD/hashes.txt"
```

On `ubuntu-vm`, `dotnet` is named with its full path, `/root/.dotnet/dotnet`, in
all the commands above. apt has its own `dotnet` with SDK 10.0.111 in `/usr/bin`,
and it fails against the pin.

## Result

| What | Expected | `arch` | `ubuntu-vm` |
| --- | --- | --- | --- |
| `sources.txt`, three files | `2a766d57…` `079f65f3…` `8628a3a4…` | verified | verified |
| `csc.dll` | `1b7543aa…` / `644a4d33…` | `1b7543aa…` | `644a4d33...` |
| `minlib.dll`, build 1 | as yesterday | `541bed82…` | `4b38...` |
| `minlib.dll`, build 2 | as build 1 | `541bed82…` | `4b38...` |

## Interpretation

**`arch`: the protocol holds over time.** Run 8 September 14:14, a day after the
first run. Same three source hashes, same `csc.dll`, and the same DLL hash twice,
`541bed823d12e42b5e9e6087c9c32a9d6fbaa9a116aae61fc00c808231e74113`, identical to
7 September.

Today's environment block is line for line identical to yesterday's, except that
`pipx list` has been replaced by `command -v`. SDK version, commit `d0558bff3d`,
kernel, `umask`, `locale` and diffoscope version are unchanged. Nothing has
drifted in the environment between the two runs, and that is why the same number
came out.

This is the weakest form of reproducibility, same machine, later point in time,
and it had to hold before anything else means anything. It holds.

`ubuntu-vm` is missing.

## Caveats

- **Same lab as yesterday.** The source files were not rewritten, only verified.
  That is a strength for the comparison and a weakness for the protocol: whether
  the `printf` lines still produce the same bytes is not tested here.
- **Same machines.** The repetition tests the protocol over time, not across
  environments.
- Same boundaries as 7 September: only `dotnet build`, no packing, no archives,
  no dependencies, only x64 Linux.
