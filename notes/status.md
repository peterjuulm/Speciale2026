# Status board: layers and axes

One screen. Where each layer stands on each axis, and what runs next. Edit a
cell and its date when a run finishes; the detail stays in the run's note and
in the [findings table](findings-table.md). The plan and the reasoning behind
the layers are in [the layer plan](2026-09-15-layer-plan.md).

Last run: 12 October 2026, layer 3's entry order. Last edit: 12 October
2026, 12:37. Also 12/10: the frontend lock's hashes filled
([phoenix-lock-fill](2026-10-12-phoenix-lock-fill.md), W41, W46).

## Last batch

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
Layers 4 (zip) and 5 (container) have no runs yet.

| Axis | Layer 1 build | Layer 2 publish | Layer 3 frontend |
| --- | --- | --- | --- |
| Same path (`none`) | green 5/10, 638 files | green 7/10 with the frontend in `wwwroot/`: 2227 files, `2cd8c531…` W42; without it the same `9283b29e…` as on 5/10, now with the version from `APP_VERSION` W45 | red 12/10: the same commit gives one of two exports, 12 and 14 of 26 builds W47; 7/10's six identical builds all fell one way |
| `build_path` | red 5/10, the two dev json only W8 W9 | green 5/10 W25 | green 12/10 beyond W47 |
| `time` | green 5/10, replaces W10 | green 5/10 W29 | green 12/10 beyond W47; no page carries a date |
| `locales` | fix 5/10 W26 with `LC_ALL` | fix 5/10 W26 with `LC_ALL`, the pin not yet run in CI | green 12/10 beyond W47, `et_EE.UTF-8` reaches Node |
| `umask` | green 5/10, 29 modes follow the umask W30 | green 5/10, 142 modes follow the umask W30 | green 12/10 beyond W47; 946 modes follow the umask, the 44 `public/` files keep the checkout's W30 |
| `exec_path` | green 5/10, replaces W10 | green 5/10 W29 | green 12/10 beyond W47 |
| `timezone` | green 5/10 | green 5/10 | green 12/10 beyond W47 |
| `environment` | green 5/10 | green 5/10 | green 12/10 beyond W47 |
| `home` | green 5/10 | green 5/10 | green 12/10 beyond W47 |
| `kernel` | green 5/10, with ASLR off R2 | green 5/10, with ASLR off R2 | green 12/10 beyond W47, with ASLR off R2 |
| `aslr` | no-op 5/10 R1 | no-op 5/10 R1 | - not run, no-op alone R1 |
| `num_cpus` | green 5/10, 2 against 4 CPUs | green 5/10, 2 against 12 CPUs | green 12/10 beyond W47, 2 against 4 CPUs |
| `user_group` | green 5/10, as `rb1b` | green 5/10, as `rb1b` | green 12/10 beyond W47, as `rb1b` |
| `all` | red 5/10: locale and the two dev json; with `LC_ALL` the dev json only W8 W9 | fix 5/10: red from the locale alone, green with `LC_ALL` | green 12/10 beyond W47, both builds the same order |
| `fileordering` | - needs a VM with `disorderfs` | - | - |
| `domain_host` | - cannot run on `arch` | - cannot run on `arch` | - |
| Machine | - VM too small W14 | - | - |
| SDK binary | - empty-class only, 8/9 | - | - Node pinned to 20.20.2 on the branch, not yet run in CI W40 |
| Network | - | - lock files in place W22 | - offline from a filled cache; lock hashes filled 12/10 W41; npm 10.8.2 drops `libc` W46 |
| Windows | - | - later work, part of the WS delivery | built once, on Linux, for both releases |

## Open, by layer

- Layer 1: W8 and W9, two dev-only json files that carry the build path,
  stay open. They also make layer 1's hash lists differ between reprotest
  runs, so layer 1 is compared within a run only.
- Layer 2: file modes follow the umask (W30), decided in layer 4. The locale
  pin `LC_ALL=C.UTF-8` is on the WS branch (`4e5237a3`) but has not run in CI.
  With the frontend in place it is measured on the same path only (W42);
  the reprotest axes ran without it. The EF migration bundle is not measured.
- Windows: the `win-x64` publish is not measured. Later work for the thesis,
  part of the WS delivery. Open points in the layer plan.
- Layer 3: the build ID (W37) and the CSS order (W43) are fixed on the WS
  branch, and the CSS held on every axis. Open: the export comes out in one
  of two orders (W47), why the runtime's minified names changed between
  commits (W44), the Node pin not yet run in CI (W40), and npm 10.8.2
  dropping `libc` from the lock (W46). The lock's 391 missing hashes are
  filled (W41, `e19ca414`).
- Layer 4: nothing yet. Expected red on mtimes and order, plus W30 and the
  empty folder named after the build ID, now the tag (W37).
- Layer 5: nothing yet. The images' version stamps (W45) and the Dockerfile's
  Node pin (W40) are on the branch, not built.
- Cross-machine and file order: paused until a VM with several GB of RAM
  exists (W14). Peter's Azure VM is the candidate.
- Dependency tree: lock files done (W22). Rebuilding packages from their
  declared commits not started.
- Method: ASLR alone is untested; reprotest cannot vary it (R1). Why no
  later build used the MSBuild nodes left over on 24/9 is not established.

## Next up

1. Layer 3, W47: the entry sort as a commit on the WS branch (Leo's call),
   then measured as a commit, and the 13 pages whose chunks changed opened
   in a browser.
2. Layer 4, the zip. Layer 2 with `out/` in place is green on the same path
   (W42).
3. Upstream: the dotnet/roslyn issue for W26, and Next.js issues for the CSS
   order's missing tie-break (W43) and the entry order (W47). Brief Magnus: the locale defect, the
   dependency warnings, the SDK pin; Node 20's end of life and Node 23 in the
   Dockerfile (W40); the PR filter that misses `mcp/` (W39); from 7/10 the
   one version variable (W45) and the CSS move's cost, about 150 KB per page.
4. Cross-machine and file order once the VM exists.
5. For the WS delivery: one run of the release workflow on a test tag. It
   checks the Windows job, the version variable, the Node pin and the
   calendar fix together.

## Keeping this file

- Change a cell only after the run's note exists. The note is the source.
- One line per axis in the grid, one bullet per open item. If an entry needs
  more than a line, it belongs in a note, linked from the findings table.
- Update the two dates at the top.
