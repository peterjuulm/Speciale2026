# Status board: layers and axes

One screen. Where each layer stands on each axis, and what runs next. Edit a
cell and its date when a run finishes; the detail stays in the run's note and
in the [findings table](findings-table.md). The plan and the reasoning behind
the layers are in [the layer plan](2026-09-15-layer-plan.md).

Last run: 5 October 2026, the full rerun, in progress. Last edit: 5 October
2026.

## Running now

The full rerun on `arch`: every reprotest axis on layers 1 and 2, 32 runs,
started 5/10 at 11:41, about 3 hours. It replaces the six runs of 24/9, since
the machine was updated on 4/10 and the protocol changed. Expectations and
results are in [phoenix-rerun of 5/10](2026-10-05-phoenix-rerun.md). The grid
changes when it is done.

## How we measure

- The lab is a `git archive` export of a branch commit, now `4e5237a3`,
  checked with `labcheck.py` before each batch. Nothing is built inside git.
- `experiments/phoenix-rt/run.sh` runs reprotest 0.7.32. Every build starts
  and ends with `dotnet build-server shutdown`, MSBuild node reuse is off,
  both builds get two CPUs, and a sampler checks that the variation reached
  every build process.
- `user_group` builds as a second user, `rb1b`, with a copy of the SDK in
  `/opt/rb1-dotnet`. Set up once with `setup-user-group.sh`.
- Not possible on `arch`: `domain_host` (no `domainname`), `fileordering` (no
  `disorderfs`), and a second machine.

## The grid

Cells: **green** measured and holds, **red** measured and open, **fix** red
then closed with a fix, **redo** an earlier result was rejected and must be
rerun, **-** not run. Date and finding ids point to the measurement. All on
`arch` with Microsoft's SDK unless stated. Layers 3 (frontend), 4 (zip) and
5 (container) have no runs yet.

| Axis | Layer 1 build | Layer 2 publish |
| --- | --- | --- |
| Same path (`none`) | green 15/9 W1 | green 23/9 W16 |
| `build_path` | fix 15/9 W3-W7, two dev json open W8 W9 | green 23/9 W25 |
| `time` | redo W10 | green 24/9 W29 |
| `locales` | redo W10 | fix 24/9 W26, the pin not yet run in CI |
| `umask` | redo W10 | green 24/9 W29, modes follow the umask W30 |
| `exec_path` | redo W10 | green 24/9 W29 |
| `timezone` | - | - |
| `environment` | - | - |
| `home` | - | - |
| `kernel` | - | - |
| `aslr` | - | - |
| `num_cpus` | - | - |
| `user_group` | - | - |
| `all` | - | - |
| `fileordering` | - needs a VM with `disorderfs` | - |
| `domain_host` | - cannot run on `arch` | - cannot run on `arch` |
| Machine | - VM too small W14 | - |
| SDK binary | - empty-class only, 8/9 | - |
| Network | - | - lock files in place W22 |
| Windows | - | - later work, part of the WS delivery |

## Open, by layer

- Layer 1: every axis is in the rerun, the four `redo` cells included. W8 and
  W9, two dev-only json files that carry the build path, stay open.
- Layer 2: file modes follow the umask (W30), decided in layer 4. The locale
  pin `LC_ALL=C.UTF-8` is on the WS branch (`4e5237a3`) but has not run in CI.
  The EF migration bundle is not measured.
- Windows: the `win-x64` publish is not measured. Later work for the thesis,
  part of the WS delivery. Open points in the layer plan.
- Layer 3: nothing yet. Expected red on `BUILD_ID`.
- Layer 4: nothing yet. Expected red on mtimes and order, plus W30.
- Layer 5: nothing yet.
- Cross-machine and file order: paused until a VM with several GB of RAM
  exists (W14). Peter's Azure VM is the candidate.
- Dependency tree: lock files done (W22). Rebuilding packages from their
  declared commits not started.
- Method: why no later build used the MSBuild nodes left over on 24/9 is not
  established. `kernel` can only be checked in reprotest's log, not per
  process.

## Next up

1. Let the rerun finish. Write its results into its note and the findings
   table, then update the grid.
2. Draft the dotnet/roslyn issue for W26. Brief Magnus: the locale defect, the
   dependency warnings, the SDK pin.
3. Layer 4, the zip. Then layer 3.
4. Cross-machine and file order once the VM exists.
5. For the WS delivery: one run of the release workflow on a test tag, since
   the branch also changes the Windows job.

## Keeping this file

- Change a cell only after the run's note exists. The note is the source.
- One line per axis in the grid, one bullet per open item. If an entry needs
  more than a line, it belongs in a note, linked from the findings table.
- Update the two dates at the top.
