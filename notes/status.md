# Status board: layers and axes

One screen. Where each layer stands on each axis, and what runs next. Edit a
cell and its date when a run finishes; the detail stays in the run's note and
in the [findings table](findings-table.md). The plan and the reasoning behind
the layers are in [the layer plan](2026-09-15-layer-plan.md).

Last run: 6 October 2026, the layer 3 pilot. Last edit: 6 October 2026,
15:20.

## Last batch

Layer 3's pilot on `arch`, 6/10 14:51-15:03: the frontend built twice at the
same path with Node 20.20.2, installed offline from a filled npm cache. Only
Next's random build ID differs; with it replaced, all 998 files of `out/`
are identical ([phoenix-layer3](2026-10-06-phoenix-layer3.md); findings
W37-W42). Before that, on 5/10, the full rerun of layers 1 and 2
([phoenix-rerun](2026-10-05-phoenix-rerun.md), W32-W36) and the clean-launch
check ([clean launch](2026-10-05-phoenix-clean-launch.md), R4).

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
  `build_path` moves `HOME`, `user_group` replaces `PATH`.
- reprotest starts under `env -i` with five listed variables, since the
  builds inherit whatever it starts with (R4, from 5/10 after the rerun).
- Layer 3: `experiments/phoenix-fe/pilot.sh` builds the frontend from an
  export of the whole commit, since it imports code from `mcp/` (W39), with
  Node 20.20.2 from `/opt/rb1-node` and `npm ci --offline` from the cache in
  `/private/tmp/rb1-npm`, under `env -i`. `compare-out.py` compares two
  exports as built and with the build ID replaced.
- Not possible on `arch`: `domain_host` (no `domainname`), `fileordering` (no
  `disorderfs`), and a second machine.

## The grid

Cells: **green** measured and holds, **red** measured and open, **fix** red
then closed with a fix, **no-op** run, but the axis changed nothing, **-** not run. Date and finding ids point to
the measurement. All on `arch` with Microsoft's SDK unless stated. Layer 3
(frontend) has its pilot on the same path; layers 4 (zip) and 5 (container)
have no runs yet.

| Axis | Layer 1 build | Layer 2 publish | Layer 3 frontend |
| --- | --- | --- | --- |
| Same path (`none`) | green 5/10, 638 files | green 5/10, the release of 23/9 W16, without the frontend W42 | red 6/10, the random build ID only W37; the rest green W38 |
| `build_path` | red 5/10, the two dev json only W8 W9 | green 5/10 W25 | - |
| `time` | green 5/10, replaces W10 | green 5/10 W29 | - |
| `locales` | fix 5/10 W26 with `LC_ALL` | fix 5/10 W26 with `LC_ALL`, the pin not yet run in CI | - |
| `umask` | green 5/10, 29 modes follow the umask W30 | green 5/10, 142 modes follow the umask W30 | - |
| `exec_path` | green 5/10, replaces W10 | green 5/10 W29 | - |
| `timezone` | green 5/10 | green 5/10 | - |
| `environment` | green 5/10 | green 5/10 | - |
| `home` | green 5/10 | green 5/10 | - |
| `kernel` | green 5/10, with ASLR off R2 | green 5/10, with ASLR off R2 | - |
| `aslr` | no-op 5/10 R1 | no-op 5/10 R1 | - |
| `num_cpus` | green 5/10, 2 against 4 CPUs | green 5/10, 2 against 12 CPUs | - |
| `user_group` | green 5/10, as `rb1b` | green 5/10, as `rb1b` | - |
| `all` | red 5/10: locale and the two dev json; with `LC_ALL` the dev json only W8 W9 | fix 5/10: red from the locale alone, green with `LC_ALL` | - |
| `fileordering` | - needs a VM with `disorderfs` | - | - |
| `domain_host` | - cannot run on `arch` | - cannot run on `arch` | - |
| Machine | - VM too small W14 | - | - |
| SDK binary | - empty-class only, 8/9 | - | - Node pinned to `20.x` only W40 |
| Network | - | - lock files in place W22 | - offline from a filled cache; 391 lock entries without a hash W41 |
| Windows | - | - later work, part of the WS delivery | built once, on Linux, for both releases |

## Open, by layer

- Layer 1: W8 and W9, two dev-only json files that carry the build path,
  stay open. They also make layer 1's hash lists differ between reprotest
  runs, so layer 1 is compared within a run only.
- Layer 2: file modes follow the umask (W30), decided in layer 4. The locale
  pin `LC_ALL=C.UTF-8` is on the WS branch (`4e5237a3`) but has not run in CI.
  Measured without the frontend: the lab had no `out/`, so no `wwwroot/`
  (W42). The EF migration bundle is not measured.
- Windows: the `win-x64` publish is not measured. Later work for the thesis,
  part of the WS delivery. Open points in the layer plan.
- Layer 3: the random build ID (W37). Fix: `generateBuildId` from the
  release tag on the WS branch, then the reprotest axes. CI pins Node only to
  `20.x`, which is past its end of life (W40); 391 lock entries carry no
  hash (W41).
- Layer 4: nothing yet. Expected red on mtimes and order, plus W30 and the
  empty folder named after the build ID (W37).
- Layer 5: nothing yet.
- Cross-machine and file order: paused until a VM with several GB of RAM
  exists (W14). Peter's Azure VM is the candidate.
- Dependency tree: lock files done (W22). Rebuilding packages from their
  declared commits not started.
- Method: ASLR alone is untested; reprotest cannot vary it (R1). Why no
  later build used the MSBuild nodes left over on 24/9 is not established.

## Next up

1. Layer 3: `generateBuildId` on the WS branch, a new export, the pilot
   again, then the reprotest axes for the frontend.
2. One layer 2 publish with `out/` in place (W42). Then layer 4, the zip.
3. Draft the dotnet/roslyn issue for W26. Brief Magnus: the locale defect, the
   dependency warnings, the SDK pin; from layer 3, Node 20's end of life
   (W40) and the PR filter that misses the frontend's code in `mcp/` (W39).
4. Cross-machine and file order once the VM exists.
5. For the WS delivery: one run of the release workflow on a test tag, since
   the branch also changes the Windows job.

## Keeping this file

- Change a cell only after the run's note exists. The note is the source.
- One line per axis in the grid, one bullet per open item. If an entry needs
  more than a line, it belongs in a note, linked from the findings table.
- Update the two dates at the top.
