# Status board: layers and axes

One screen. Where each layer stands on each axis, and what runs next. Edit a
cell and its date when a run finishes; the detail stays in the run's note and
in the [findings table](findings-table.md). The plan and the reasoning behind
the layers are in [the layer plan](2026-09-15-layer-plan.md).

Last run: 12 October 2026, the whole release on .NET 10 with the fix.
Last edit: 12 October 2026, 21:05. Also 12/10: the frontend lock's hashes filled
([phoenix-lock-fill](2026-10-12-phoenix-lock-fill.md), W41, W46).

## Last batch

On `arch`, 12/10 19:05-19:59
([phoenix-net10-release](2026-10-12-phoenix-net10-release.md); W26, W50,
W51): the WS branch moved to .NET 10 at `332752b9`, SDK 10.0.401 pinned, so
every earlier hash on this board was made with SDK 9.0.120. The whole
release with its zips (layer `Z`) under `none`, `all` and `locales`: the
job worker's zip was the same in all six builds. The WebAPI differed in one
file, the static assets' endpoints manifest, where SDK 10 dates the
compressed copies with the build time (W50). With compression off,
`e6ce3549`, 20:11-21:01, the whole release was the same in all six builds
of the three axes: 2121 files, `00dad37d…`. Under Estonian without the pin
every assembly was the same, so W26 is gone on SDK 10. `all` also showed a
rarer frontend race: two identical chunks whose ids two pages swapped
(W51), once in about 50 builds. The SDK 10 table below the grid has the
cells. Before the move, also on 12/10:

On `arch`, 12/10 09:32-11:36
([phoenix-fe-reprotest](2026-10-12-phoenix-fe-reprotest.md); finding W47):
the frontend of `a16eb506` under every reprotest axis that runs here, 13
runs, 26 builds. They gave exactly two exports, 12 and 14 times, which
differ only in the order of one table in the webpack runtime, and so in the
108 pages that name the runtime. Both occur under reprotest's fixed
conditions, so the export is not deterministic (W47); the likeliest cause,
read in the code, is a race in Next as it adds the pages to webpack's
entries. No axis changed a byte of its own: there was no third export, and
`all` gave the same bytes in both builds. Modes follow the umask except the
44 files of `public/`. Before that, on 7/10
([phoenix-app-version](2026-10-07-phoenix-app-version.md), W43-W45): one
`APP_VERSION` as build ID, all third-party CSS in `_app`, and layer 2 green
with the frontend in place, `2cd8c531…` (W42).

Then, 11:44-12:36
([phoenix-entry-order](2026-10-12-phoenix-entry-order.md)), on `e19ca414`
in a lab with a logging plugin: the client's entry order varied in six
builds, five orders, and the export followed it. With the entries sorted by
name, six builds with six different orders gave one export, also under
`all` and `build_path`. The sort also changes five shared chunks against A.
Then, 12:53-13:55
([phoenix-sorted-release](2026-10-12-phoenix-sorted-release.md)), the sort
as a WS commit, `a16f9a91`, pushed after the checks: six frontend builds identical,
and the whole release built end to end in one build, frontend included,
2227 files, `b72bbc3b…`, identical under `none` and `all`. The 13 pages
whose chunks changed behaved the same in a browser. Then, 14:21-14:51
([phoenix-zip](2026-10-12-phoenix-zip.md)), layer 4: the release zips as
CI packs them differ in every build, though every file inside is the same,
from times, entry order, modes and the owner; a normalised packing gave
the same two zips in four builds under `none` and `all` (W48).

## How we measure

- The lab is a `git archive` export of a branch commit, now `63129480` for
  layer 2 and `a16eb506` for layer 3, checked with `labcheck.py` before each
  batch. Nothing is built inside git.
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
  exports as built and with the build ID replaced. From 7/10 the commit is
  `COMMIT` and the version `APP_VERSION=v0.0.0-thesis`; layer 2 passes the
  same version through `FIXENV` with `VER=` from `5031c5af` on.
- Layer 3 under reprotest: `experiments/phoenix-fe/run.sh` builds the same
  way in reprotest, with phoenix-rt's protocol minus the .NET parts, and
  hashes `out/`. `user_group` uses a copy of the npm cache in
  `/private/tmp/rb1-shared/npm-cache`. One run takes 8 to 11 minutes.
- Not possible on `arch`: `domain_host` (no `domainname`), `fileordering` (no
  `disorderfs`), and a second machine.

## The grid

Cells: **green** measured and holds, **red** measured and open, **fix** red
then closed with a fix, **no-op** run, but the axis changed nothing, **-** not run. Date and finding ids point to
the measurement. All on `arch` with Microsoft's SDK unless stated. In layer
3 every cell carries W47: the export comes out in one of two orders
whatever the axis, so "green" there means the axis changed nothing else.
Layer 5 (container) has no runs yet.

| Axis | Layer 1 build | Layer 2 publish | Layer 3 frontend | Layer 4 zip |
| --- | --- | --- | --- | --- |
| Same path (`none`) | green 5/10, 638 files | green 7/10 with the frontend in `wwwroot/`: 2227 files, `2cd8c531…` W42; without it the same `9283b29e…` as on 5/10, now with the version from `APP_VERSION` W45; 12/10 built end to end with its frontend at `a16f9a91`: 2227 files, `b72bbc3b…`, also under `all` | fix 12/10 `a16f9a91`: the entries sorted W47; before it one of two exports, 12 and 14 of 26 builds | red 12/10 as CI packs: times, order, owner W48; normalised packing identical |
| `build_path` | red 5/10, the two dev json only W8 W9 | green 5/10 W25 | green 12/10 beyond W47 | - |
| `time` | green 5/10, replaces W10 | green 5/10 W29 | green 12/10 beyond W47; no page carries a date | - |
| `locales` | fix 5/10 W26 with `LC_ALL` | fix 5/10 W26 with `LC_ALL`, the pin not yet run in CI | green 12/10 beyond W47, `et_EE.UTF-8` reaches Node | - |
| `umask` | green 5/10, 29 modes follow the umask W30 | green 5/10, 142 modes follow the umask W30 | green 12/10 beyond W47; 946 modes follow the umask, the 44 `public/` files keep the checkout's W30 | covered by `all` 12/10: modes reach the CI zip W30; not the normalised one |
| `exec_path` | green 5/10, replaces W10 | green 5/10 W29 | green 12/10 beyond W47 | - |
| `timezone` | green 5/10 | green 5/10 | green 12/10 beyond W47 | - |
| `environment` | green 5/10 | green 5/10 | green 12/10 beyond W47 | - |
| `home` | green 5/10 | green 5/10 | green 12/10 beyond W47 | - |
| `kernel` | green 5/10, with ASLR off R2 | green 5/10, with ASLR off R2 | green 12/10 beyond W47, with ASLR off R2 | - |
| `aslr` | no-op 5/10 R1 | no-op 5/10 R1 | - not run, no-op alone R1 | - |
| `num_cpus` | green 5/10, 2 against 4 CPUs | green 5/10, 2 against 12 CPUs | green 12/10 beyond W47, 2 against 4 CPUs | - |
| `user_group` | green 5/10, as `rb1b` | green 5/10, as `rb1b` | green 12/10 beyond W47, as `rb1b` | - |
| `all` | red 5/10: locale and the two dev json; with `LC_ALL` the dev json only W8 W9 | fix 5/10: red from the locale alone, green with `LC_ALL` | green 12/10 beyond W47, both builds the same order | red 12/10 as CI packs, also modes and time zone W48; normalised identical, across runs too |
| `fileordering` | - needs a VM with `disorderfs` | - | - | - |
| `domain_host` | - cannot run on `arch` | - cannot run on `arch` | - | - |
| Machine | - VM too small W14 | - | - | - |
| SDK binary | - empty-class only, 8/9 | - | - Node pinned to 20.20.2 on the branch, not yet run in CI W40 | - |
| Network | - | - lock files in place W22 | - offline from a filled cache; lock hashes filled 12/10 W41; npm 10.8.2 drops `libc` W46 | - |
| Windows | - | - later work, part of the WS delivery | built once, on Linux, for both releases | - |

On SDK 10.0.401, from `332752b9`: the whole release with its zips in one
build (layer `Z`), the cells of the grid above being SDK 9.0.120's.

| Axis | `332752b9` | `e6ce3549`, compression off |
| --- | --- | --- |
| `none` | red 12/10: the endpoints manifest only W50; job worker zip identical | green 12/10: 2121 files, `00dad37d…`; normalised zips identical |
| `all` | red 12/10: the manifest W50 and five frontend files W51 | green 12/10: `00dad37d…`, also across runs; W51 not hit |
| `locales` | red 12/10: the manifest only; every assembly the same without the pin, W26 gone | green 12/10 without the pin: `00dad37d…` |

## Open, by layer

- Layer 1: W8 and W9, two dev-only json files that carry the build path,
  stay open. They also make layer 1's hash lists differ between reprotest
  runs, so layer 1 is compared within a run only.
- Layer 2: file modes follow the umask (W30), decided in layer 4. The locale
  pin `LC_ALL=C.UTF-8` is on the WS branch (`4e5237a3`) but has not run in CI;
  on SDK 10 it is no longer needed for W26. On SDK 10 the endpoints manifest
  dates compressed copies with the build time (W50); with compression off
  (`e6ce3549`) the whole release is green under `none`, `all` and `locales`.
  With the frontend in place it is measured on the same path only (W42);
  the reprotest axes ran without it. The EF migration bundle is not measured.
- Windows: the `win-x64` publish is not measured. Later work for the thesis,
  part of the WS delivery. Open points in the layer plan.
- Layer 3: the build ID (W37), the CSS order (W43) and the entry order
  (W47, `a16f9a91`) are fixed on the WS branch. Open: why
  the runtime's minified names changed between commits (W44), the Node pin not yet run in CI (W40), and npm 10.8.2
  dropping `libc` from the lock (W46). The lock's 391 missing hashes are
  filled (W41, `e19ca414`). New on 12/10: two pages swap the ids of two
  identical chunks, once in about 50 builds (W51); cause suspected, not
  measured.
- Layer 4: the zips as CI packs them are red (W48); the normalised packing
  is in the release workflow since `06cb5397` but has not run in CI.
  Windows' `Compress-Archive` zips are not measured.
- Layer 5: nothing yet. The images' version stamps (W45) and the Dockerfile's
  Node pin (W40) are on the branch, not built.
- Cross-machine and file order: paused until a VM with several GB of RAM
  exists (W14). Peter's Azure VM is the candidate.
- Dependency tree: lock files done (W22). Rebuilding packages from their
  declared commits not started.
- Method: ASLR alone is untested; reprotest cannot vary it (R1). Why no
  later build used the MSBuild nodes left over on 24/9 is not established.

## Next up

1. W51: perturb the module order on purpose, and sort it at seal if that
   is the cause (running 12/10 evening). The EF migration bundle, never
   measured. Then the test-tag run in CI and layer 5, the images.
2. Upstream: the dotnet/roslyn issue for W26 (fixed in SDK 10, so only for
   9.0), a dotnet/sdk issue for W50, and Next.js issues for the CSS order's
   missing tie-break (W43) and the entry order (W47). Brief Magnus: the locale defect, the
   dependency warnings, the SDK pin; Node 20's end of life and Node 23 in the
   Dockerfile (W40); the PR filter that misses `mcp/` (W39); from 7/10 the
   one version variable (W45) and the CSS move's cost, about 150 KB per page.
3. Cross-machine and file order once the VM exists.
4. For the WS delivery: one run of the release workflow on a test tag. It
   checks the Windows job, the version variable, the Node pin and the
   calendar fix together.

## Keeping this file

- Change a cell only after the run's note exists. The note is the source.
- One line per axis in the grid, one bullet per open item. If an entry needs
  more than a line, it belongs in a note, linked from the findings table.
- Update the two dates at the top.
