# Speciale2026

Experiments for Leo Sakharov and Peter Juul Møller's thesis on reproducible
builds in .NET and WS.PEMS (MSc Software Design, ITU, autumn 2026). The thesis
text itself is written in Overleaf; this repo holds only what must be runnable
again, and what came out of it.

**Language: English.** Decided 15 September 2026. All notes, findings, tables,
commit messages and answers are written in English unless Leo or Peter
explicitly asks for Danish. Every note that existed before that date was
translated to English the same day. Where Danish is used, write æøå directly,
not as HTML entities.

**The repo is public.** Nothing from Weel-Sandvig's source, build output or
internal documents may land here. No IP addresses, keys or personal paths
beyond those already in the `environment.txt` files.

## Structure

- `notes/yyyy-mm-dd-topic.md`: one note per experiment. Fixed sections:
  question, **expectation written before the run**, commands verbatim, result,
  interpretation, caveats. Observation and interpretation stay separate.
- `notes/yyyy-mm-dd-findings.md`: investigation notes with no run.
- `notes/dotnet-build-who-does-what.md`: background on MSBuild versus Roslyn.
  The glossary is in `notes/2026-09-07-empty-class.md`.
- `data/<experiment>/<machine>/`: `environment.txt`, `hashes.txt`,
  `sources.txt`, `rt-*.log` from reprotest, `kommando.txt` with the verbatim
  build command. Text goes in git, bytes do not: never DLLs or packages.
- `experiments/`: scripts. Empty so far; runs have been hand-typed commands
  recorded in the notes.

Note and data directory are named after **the day the run happened**, not the
day it was planned. One file per machine under `data/`; two people in the same
file is a merge conflict, not a measurement.

Claims that must be citable are marked `[V]` (verified: file, line or a run
that can be repeated) or `[I]` (inference). A prediction is `[I]` until it has
been measured.

## The machines

Three environments, all with the lab in `/private/tmp/rb1` and the SDK pinned
to 9.0.120 via `global.json` with `rollForward: disable`:

| Name | What | Particulars |
| --- | --- | --- |
| `arch` | Leo's laptop, Arch Linux | Two SDK 9.0.120: the Arch package in `/usr/share/dotnet` (csc `1b7543aa…`) and Microsoft's in `~/.dotnet` (csc `644a4d33…`). They produce different bytes. Always say which one is used. |
| `ubuntu-vm` | Shared droplet, Ubuntu 24.04 | apt has its own versions of everything in `/usr/bin`. The right ones are in `/root/.dotnet` and `/root/.local/bin` and are only on PATH in interactive shells. **Use full paths in anything that measures.** `disorderfs` exists only here. |
| `mac` | Peter's laptop, Apple Silicon | Microsoft's SDK via `dotnet-install.sh`. reprotest cannot run on macOS. |

## Traps, each paid for once

- **Never build inside a git repo.** The SDK embeds the HEAD commit in
  `AssemblyInformationalVersion`, so the hash shifts with every commit
  regardless of `PathMap`. That is why the lab lives in `/private/tmp/rb1`.
- **Never pipe reprotest's output.** It leaves a child process holding the pipe
  open, so `| tail` never sees the end. Redirect to a file.
- **reprotest's "successful" holds only within the run.** Control and
  experiment both build in the same random `/tmp/reprotest.XXXXXX/`. Without
  `PathMap` every run gets its own hash. Compare hashes across runs, not just
  verdicts.
- **`PathMap` from the command line must use the shell's `$PWD`**, that is
  `-p:PathMap=$PWD/=/_/`. `$(MSBuildProjectDirectory)` is not expanded in
  global properties and is silently ignored. Check with
  `strings minlib.dll | grep pdb`, which must show `/_/obj/...`.
- **`ContinuousIntegrationBuild` only maps the source root when Source Link
  can find `.git`.** In a copied tree it maps nothing but the NuGet cache
  (measured 15/9). Use an explicit `PathMap` anchored in
  `Directory.Build.props`; it works with or without git.
- **`PathMap` does not reach text written by source generators.** The Razor
  generator writes absolute `.cshtml` paths into generated C#, which Roslyn
  embeds in the PDB (measured 15/9). Check `experiments/pdbdump` when a PDB
  still differs after PathMap.
- **Clear `bin/` and `obj/` before reprotest**, or old output is copied into
  the test directory along with everything else.
- **reprotest's variation does not reach .NET's build servers.** The
  experiment build hands its compiling to the compiler server the control
  build started, which keeps the control's clock, locale, umask and `PATH`
  (measured 24/9). Start every build command with `dotnet build-server
  shutdown`.
- **reprotest fixes what it does not vary**: one CPU unless `--min-cpus` is
  given, `TZ=GMT+12`, `LANG=C.UTF-8`, and `HOME` inside the build directory.
  The `DOTNET_CLI_HOME` we set for that also moves the NuGet cache.
- The version number `9.0.120` does not identify the compiler. The Roslyn
  commit in `csc.dll` does. Always record the `csc.dll` hash in the
  environment block.

## Workflow

1. Write the note with the expectation **before** the run. Feel free to commit
   the empty result table first.
2. Record the environment block on each machine (`dotnet --info`, `uname`,
   `umask`, `locale`, tool versions, `csc.dll` hash, `date -Is`).
3. Run. Save the logs under `data/`, the command in `kommando.txt`.
4. Fill in result and interpretation. Do not correct the expectation
   afterwards; write down where it failed instead.
5. `git pull --rebase` before push. We both write directly in `main`.

## Where we stand

`notes/findings-table.md` is the running index of every cause found, its fix and
its status; keep it current. `notes/2026-09-15-layer-plan.md` is the plan: five
layers (build, publish, frontend, zip, container) measured one at a time.
As of 24/9: layer 1 is closed on `arch`. Layer 2 is green on `arch` for the
release's own publish commands, on one path and across paths, with NuGet lock
files in place, and under a shifted clock, umask 0002 and an extra `PATH`
entry. Locale was red: under `et_EE.UTF-8` the compiler orders the types it
generates for collection expressions differently, a Roslyn defect (W26).
Pinning `LC_ALL=C.UTF-8` or invariant globalization on the dotnet commands
fixes it without changing a byte; the release workflow does not set it yet.
Cross-machine runs are paused: the shared droplet is too small to compile
Phoenix. See `notes/2026-09-24-phoenix-layer2-reprotest.md`,
`notes/2026-09-24-roslyn-locale-repro.md` and `notes/2026-09-23-findings.md`. Open questions are under
"Caveats" in the newest experiment notes and under "Open" in the findings note.
Fixes to Phoenix live on the branch `thesis/reproducible-builds` in the
WS.Phoenix repo, never in this one.

For Phoenix, the lab `/private/tmp/rb1-phoenix` is an export of the commit being
measured, not a copy of the worktree: empty it, then
`git archive <commit> -- . ':(exclude).claude' | tar -x -C /private/tmp/rb1-phoenix`,
and check it file by file against the commit. Name the commit in every note.
