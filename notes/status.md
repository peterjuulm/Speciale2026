# Status board: layers and axes

One screen. Where each layer stands on each axis, and what runs next. Edit a
cell and its date when a run finishes; the detail stays in the run's note and
in the [findings table](findings-table.md). The plan and the reasoning behind
the layers are in [the layer plan](2026-09-15-layer-plan.md).

Last run: 5 October 2026, the full rerun. Last edit: 5 October 2026, 16:10.

## Last batch

The full rerun on `arch`, 5/10 11:41-15:55: every reprotest axis on layers 1
and 2, 32 runs, all as expected. Expectations and results are in
[phoenix-rerun of 5/10](2026-10-05-phoenix-rerun.md); findings W32-W36.

## How we measure

- The lab is a `git archive` export of a branch commit, now `4e5237a3`,
  checked with `labcheck.py` before each batch. Nothing is built inside git.
- `experiments/phoenix-rt/run.sh` runs reprotest 0.7.32. Every build starts
  and ends with `dotnet build-server shutdown`, MSBuild node reuse is off,
  both builds get two CPUs, and a sampler checks that the variation reached
  every build process.
- `user_group` builds as a second user, `rb1b`, with a copy of the SDK in
  `/opt/rb1-dotnet`. Set up once with `setup-user-group.sh`.
- reprotest checked against itself on 5/10 ([probe](2026-10-05-reprotest-probe.md),
  R1-R8): `aslr` alone changes nothing, `kernel` also switches ASLR off,
  `build_path` moves `HOME`, `user_group` replaces `PATH`. The builds inherit
  the environment of the shell that starts reprotest (R4).
- Not possible on `arch`: `domain_host` (no `domainname`), `fileordering` (no
  `disorderfs`), and a second machine.

## The grid

Cells: **green** measured and holds, **red** measured and open, **fix** red
then closed with a fix, **no-op** run, but the axis changed nothing, **-** not run. Date and finding ids point to
the measurement. All on `arch` with Microsoft's SDK unless stated. Layers 3
(frontend), 4 (zip) and 5 (container) have no runs yet.

| Axis | Layer 1 build | Layer 2 publish |
| --- | --- | --- |
| Same path (`none`) | green 5/10, 638 files | green 5/10, the release of 23/9 W16 |
| `build_path` | red 5/10, the two dev json only W8 W9 | green 5/10 W25 |
| `time` | green 5/10, replaces W10 | green 5/10 W29 |
| `locales` | fix 5/10 W26 with `LC_ALL` | fix 5/10 W26 with `LC_ALL`, the pin not yet run in CI |
| `umask` | green 5/10, 29 modes follow the umask W30 | green 5/10, 142 modes follow the umask W30 |
| `exec_path` | green 5/10, replaces W10 | green 5/10 W29 |
| `timezone` | green 5/10 | green 5/10 |
| `environment` | green 5/10 | green 5/10 |
| `home` | green 5/10 | green 5/10 |
| `kernel` | green 5/10, with ASLR off R2 | green 5/10, with ASLR off R2 |
| `aslr` | no-op 5/10 R1 | no-op 5/10 R1 |
| `num_cpus` | green 5/10, 2 against 4 CPUs | green 5/10, 2 against 12 CPUs |
| `user_group` | green 5/10, as `rb1b` | green 5/10, as `rb1b` |
| `all` | red 5/10: locale and the two dev json; with `LC_ALL` the dev json only W8 W9 | fix 5/10: red from the locale alone, green with `LC_ALL` |
| `fileordering` | - needs a VM with `disorderfs` | - |
| `domain_host` | - cannot run on `arch` | - cannot run on `arch` |
| Machine | - VM too small W14 | - |
| SDK binary | - empty-class only, 8/9 | - |
| Network | - | - lock files in place W22 |
| Windows | - | - later work, part of the WS delivery |

## Open, by layer

- Layer 1: W8 and W9, two dev-only json files that carry the build path,
  stay open. They also make layer 1's hash lists differ between reprotest
  runs, so layer 1 is compared within a run only.
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
- Method: ASLR alone is untested; reprotest cannot vary it (R1). The builds'
  base environment depends on who starts reprotest (R4). Why no later build
  used the MSBuild nodes left over on 24/9 is not established.

## Next up

1. Start reprotest under `env -i` (R4), then two confirmation runs: L2 `none`
   and L2 `all` with the fix. The same release means the inherited
   environment changed no result.
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
