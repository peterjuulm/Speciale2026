# Phoenix layer 1: two clean builds of our own assemblies

Run 15 September 2026 on `arch`. First experiment on the real Phoenix tree after
the three empty-class experiments in Speciale2026.
Data: `data/2026-09-15-phoenix-layer1/arch/`.

Phoenix is Weel-Sandvig's code and this repo is public. The data directory holds
the environment block, the commands and the manifest hash. The full hash lists
(1610 file names) and build logs (14,300 warnings with source paths) stay locally
with Leo until it is settled what may live here.

## Question

Do two clean `dotnet build -c Release` of Phoenix on the same path, the same
machine and the same pinned SDK give bit-identical output for everything under
`src/*/bin/Release/`?

## Setup

- Source: worktree `WS.Phoenix-repro`, branch `thesis/reproducible-builds`,
  HEAD `d850ccf8` (main `a2dc1d5b` + the dependency-graph tool).
- Lab: `/private/tmp/rb1-phoenix`, an rsync of the worktree without `.git`,
  `node_modules`, `bin`, `obj`, `.claude`, `.next`, `out`. 4304 files without
  ClientApp; tree hash `31b4bb11…` (`source-tree.sha256`).
- `global.json` in the lab overwritten to `9.0.120` + `rollForward: disable`.
  The same day, after the run, committed on `thesis/reproducible-builds` as
  `6b7a3254`, so the lab is from now on a plain rsync of the worktree.
- SDK: Microsoft's 9.0.120 in `~/.dotnet` (`DOTNET_ROOT`), not the Arch package.
  `csc.dll` `644a4d33…`, the same binary as Microsoft's linux-x64 archive in the
  9/9 table. `[V]` `environment.txt`.
- The frontend is skipped: `-p:SkipSpaBuild=true`. Layer 3 measures it
  separately.
- One run = `rm -rf */bin */obj` + `dotnet restore` + `dotnet build
  --no-restore`. One build at a time on the machine.

## Expectation, written before the run

1. The four own assemblies (`ApplicationCore`, `Infrastructure`, `WebAPI`,
   `BackgroundJobExecutor`) and their PDBs: identical. Same path, same compiler,
   and the 19/8 probe gave the same for one of them.
2. Copied dependencies: identical trivially (same bytes from the same package
   cache).
3. Unknown: the generated files alongside, `*.deps.json`,
   `*.runtimeconfig.json`, `staticwebassets.*`, possibly an EF migration bundle.
   If something fails, it is here.
4. The test projects are built along if the solution file is used. They count in
   the table but are not the question.

## Commands

In `kommando.txt` in the data directory, verbatim.

## Result

| | Run 1 | Run 2 |
| --- | --- | --- |
| Files under `bin/Release` (src + tests) | 1610 | 1610 |
| Differing files | 0 | |
| Warnings / errors | 14300 / 0 | 14300 / 0 |

All four own assemblies and their PDBs are in the list and identical, for example
`ApplicationCore.dll` `4c5341e2…`, `Infrastructure.dll` `20d96acb…`,
`BackgroundJobExecutor.dll` `679fe797…`. `[V]` `build1.sha256` (local).

The first attempt failed: the protocol was "restore once, build twice", but
`rm -rf obj` deletes `project.assets.json`, which is restore output. Build 1 and
2 both failed with NETSDK1004. The protocol was corrected to clean + restore +
build per run, and `kommando.txt` is the corrected one.

## Interpretation

Expectations 1-3 held: on the same path, the same machine and the same SDK
binary, the whole `dotnet build` output for Phoenix is bit-identical, including
the generated `deps.json`/`runtimeconfig.json`. That matches the 19/8 probe and
empty-class, now on 1610 files instead of 2.

A lesson about the apparatus: restore is part of the build. `obj/` holds both
restore output and compiler output, so "clean" always means "restore again". It
also means a layer-1 result presupposes that restore gives the same graph twice,
here from a warm cache. Whether the graph resolution itself is stable over time
and across machines is the dependency part's question, not answered here.

The result says nothing about other paths (PathMap is still missing in Phoenix),
other machines, or publish/zip/container. This is layer 1 green on one machine,
as expected.

## Caveats and not tested

- `arch` only. Cross-machine is layer 1 on `ubuntu-vm` and Peter's Mac.
- `dotnet build`, not `dotnet publish`. Publish output is layer 2.
- Restore with network. Offline restore from a pinned cache belongs to the
  dependency part.
- Run once (two builds). To be repeated another day before `[V]` on the numbers.
- Same path both times. The path axis (`+build_path`) has not been measured on
  Phoenix beyond the 19/8 probe on one project.
