# Phoenix layer 1, file order: reprotest `+fileordering` on ubuntu-vm

Run 23 September 2026 on `ubuntu-vm`. The one environment axis from
[phoenix-reprotest](2026-09-15-phoenix-reprotest.md) that could not run on
`arch`, because it needs `disorderfs`.
Data: none; the run did not happen.

## Question

Does Phoenix's build output depend on the order in which the filesystem lists
directory entries? reprotest builds once on the normal filesystem and once
through `disorderfs`, which shuffles every directory listing.

The empty-class run on 14/9 was green on this axis, but it had one source file,
so there was nothing to shuffle. ApplicationCore has 1569.

## Setup

- Lab `/private/tmp/rb1-phoenix` on `ubuntu-vm`, the same tree as in
  [phoenix-cross-machine](2026-09-23-phoenix-cross-machine.md), with `bin` and
  `obj` cleared before the run.
- reprotest 0.7.32 and diffoscope 329 from `/root/.local/bin`, disorderfs from
  apt. `PATH` is set explicitly so reprotest finds diffoscope 329, not apt's
  259.
- Build command and artefact pattern as in the 15/9 reprotest runs, with the
  VM's paths: the two root projects; our own DLLs, PDBs and json in
  `WebAPI/bin`; `BackgroundJobExecutor.*`.
- `--store-dir` keeps the artefacts, so their hashes can be compared with the
  plain builds in phoenix-cross-machine.
- NuGet cache warm from phoenix-cross-machine.
- Added 23/9 at 12:00, before the run: both build commands pass
  `-p:UseSharedCompilation=false`, for memory. See the protocol change in
  [phoenix-cross-machine](2026-09-23-phoenix-cross-machine.md).

## Expectation, written before the run

The same as point 2 in phoenix-cross-machine, for the same reason. **Green** if
MSBuild orders the source files independently of the filesystem. **Red** if it
does not, and then `ApplicationCore.dll`, `Infrastructure.dll` and
`WebAPI.dll` differ with reordered metadata, and the difference propagates to
`BackgroundJobExecutor` through the reference MVIDs in its PDB. The two json
files are identical either way, because both builds use the same path.

No strong prior in either direction.

## Commands

Prepared but not run. The script stays locally with Leo
(`phoenix-fileordering/run.sh`).

## Result

Not run. The run was queued twice on `ubuntu-vm`, behind the two
phoenix-cross-machine attempts, and stopped with them when the VM could not
build Phoenix. See [phoenix-cross-machine](2026-09-23-phoenix-cross-machine.md).

## Interpretation

Nothing measured. The `arch` probes in phoenix-cross-machine answer part of
the question from the other side: MSBuild sorts wildcard results with an
ordinal comparison before the compiler sees them, so a shuffled directory
listing cannot reorder the `Compile` items `[V]`. What the run would still
test is everything that enumerates directories on its own: MSBuild targets,
source generators, the static web assets pipeline.

## Caveats and not tested

- **Paused**, decided by Leo on 23/9, until a VM with enough memory exists.
  It needs Linux with FUSE and `disorderfs`, so `arch` cannot run it without
  installing `disorderfs`.
- When it runs, the build command should follow the release's current
  sequence (locked restore, publishes with `--no-restore`), not the 15/9
  `dotnet build` of the two programs.
