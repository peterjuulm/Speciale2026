# Status board: layers and axes

One screen. Where each layer stands on each axis, and what runs next. Edit a
cell and its date when a run finishes; the detail stays in the run's note and
in the [findings table](findings-table.md). The plan and the reasoning behind
the layers are in [the layer plan](2026-09-15-layer-plan.md).

Last run: 13 October 2026, the release workflow on GitHub against a local
rebuild. Last edit: 13 October 2026, 23:50. Also 12/10: the frontend lock's hashes filled
([phoenix-lock-fill](2026-10-12-phoenix-lock-fill.md), W41, W46).

## Last batch

On GitHub and `arch`, 13/10 22:57-23:39
([phoenix-ci-dry-run](2026-10-13-phoenix-ci-dry-run.md); W58): the
release workflow as a dry run on a throwaway commit on `fa60ea97`, tag
`v0.0.0-thesis.2`: no tests, release, pushes, signing or cache. All five
jobs passed, the smoke test with 160 migrations. Against a local rebuild
of each job, the release's first comparison across machines: the
frontend export and both images identical; in the zips and migrators
only our own assemblies differ, because their PDBs record the runtime the
compiler ran on, 10.0.13 on GitHub (setup-dotnet installs the newest
LTS runtime) and 10.0.12 here. With 10.0.13 added here, every output is
CI's byte for byte. The fix is open. Run, artifacts and tag deleted, and
the morning test tag's 3.1 GB of build caches.

On `arch`, 13/10 22:17-22:49
([phoenix-images](2026-10-13-phoenix-images.md); W56, W57): layer 5,
the WebAPI and job worker images of `100e3912`, each built twice the way
the release job builds them, without cache. They differ in times only:
the config, the index, and the file times in the layers the build adds;
every file's content is the same. With `SOURCE_DATE_EPOCH` at the
commit's time and `rewrite-timestamp=true` both images are byte for byte
the same, and the base layers keep their digests. The release job does
that since `fa60ea97` (pushed; Codex reviewed). One builder hides part of
the difference: `WORKDIR` comes from its cache despite `--no-cache` (W57).

On `arch`, 13/10 21:31-22:16
([phoenix-windows-release](2026-10-13-phoenix-windows-release.md); W55):
the Windows release as the Windows job builds it since the merge, on
Linux: the locked restore, three `win-x64` publishes and both zips with
the packing script, on `100e3912`. Two builds gave the same 4256 files
and zips under `none`, `all`, and `locales` without the locale pin, which
the job does not set. Unsigned: signing, which the job does before
packing, is what is left between two of its runs.

On `arch`, 13/10 20:59-21:33
([phoenix-dev-workflows](2026-10-13-phoenix-dev-workflows.md), follow-up;
W53, W54): five fixes on the WS branch, pushed as `100e3912`. The Makefile
names the solution, `make db-migrate` restores first, the bash migration
scripts restore for themselves and stop when `dotnet ef` fails, the docs
follow, and the migrator keeps the host's runtime out of its restore.
On a fresh clone every developer command passes; W54's NU1004 is
reproduced on Linux and gone with the fix, and the release's migrator is
byte for byte unchanged. Codex reviewed the series twice.

On `arch`, 13/10 15:16-15:33
([phoenix-dev-workflows](2026-10-13-phoenix-dev-workflows.md); W46, W53,
W54): the Makefile's targets on a fresh clone of `5ec085ac`, two runs.
After a build of the solution the developers' path works: 160 migrations
applied, a migration added and removed, the lock files as CI expects them,
`npm install` leaving the lock alone, the dev server answering. A fresh
clone fails three ways: `make setup` and `make db-migrate` with NETSDK1004
(W53's cause, the branch's), `make build` with MSB1011 (main's too), and
the migration scripts report success after a failure (main's too). Adding
a migration changes only EF's version number in the snapshot, 9.0.0 to
10.0.12. Two untracked `.local` folders appeared; the cause is unknown.
Codex checked five claims and corrected two: W53's mechanism, also in the
bundle note, and "npm 11 keeps `libc`" (11.6.2 does not). Peter's macOS
lock failure is now W54. Nothing fixed yet.

On `arch`, 13/10 14:43-15:15
([phoenix-merge-main](2026-10-13-phoenix-merge-main.md), result 13): both
release jobs now pack their zips with one script (`5ec085ac`, not pushed).
It gives the Linux zips of the merge's release byte for byte, the Windows
step packs the same way, and it refuses links, a zip inside the folder and
names with a newline. Not yet run in CI.

On `arch`, 13/10 13:50-14:32
([phoenix-merge-main](2026-10-13-phoenix-merge-main.md), results 11 and 12):
the whole release built twice under `all`, and under `locales` without the
`LC_ALL` pin, on the merged head `79cb67a7`. Both times all 2124 files and
the normalised zips identical, the hash list the same as under `none`. Read in the merged code: main's lock has lost its `libc`
fields (W46), the Windows zips are packed with plain `zip -qr` (W48),
PR validation's migration guard runs in the reusable .NET build that
passed in main's CI (W53), and main's CI set the frontend up with Node
22.23.3 (W40).

On GitHub, 13/10 11:07-11:27 UTC
([phoenix-merge-main](2026-10-13-phoenix-merge-main.md), result 10):
main's CI workflow started by hand on the merged branch (`79cb67a7`).
Every job passed: the backend's tests on WS's office runner with the same
counts as on `arch`, the frontend's 1610 tests, the Node services' tests,
and all five images built, not pushed.

On `arch`, 13/10 10:34-12:29
([phoenix-merge-main](2026-10-13-phoenix-merge-main.md); W40, W41, W52):
main merged into the branch, 122 commits (`459de87e`; pushed with three
follow-ups as `79cb67a7`). On the head CI's .NET steps pass, the migrator
is identical in two builds for linux-x64 and win-x64, and the whole
release, 2124 files, is identical in two builds under `none`, with the
normalised zips. Main's design-time guard (#619) stops a migrator built
main's way in both deployment paths; the branch's migrator now creates its
context with its own factory (`805275c4`). Node 22.23.3 pinned (W40);
main's lock filled again (W41). Nothing of the merge had run on GitHub yet.

On GitHub, 13/10 07:53-08:21 UTC
([phoenix-release-run](2026-10-13-phoenix-release-run.md)): the release
workflow on the test tag `v0.0.0-thesis.1` (`82ea130a`). Every job passed
but the Linux tests: all 678 integration tests failed at setup, where
Testcontainers found no `postgres:15.1` image on the GitHub-hosted runner;
main runs those tests on WS's office runner since it reworked that workflow
after the branch left it on 14/9. So no pre-release was made. The migrator's
smoke test applied all 150 migrations, the Windows migrator was signed, the
zips were packed the normalised way. Tag and run deleted afterwards; 15
private image versions remain (deleting them needs more rights than Leo's).

On `arch`, 13/10 08:31-09:41 ([phoenix-bundle](2026-10-13-phoenix-bundle.md),
the fix; W52): the release's migrator as a project in the repository,
`src/DbMigrator`. Two builds at two paths are identical for linux-x64 and
win-x64; on scratch PostgreSQL databases it leaves the same history and
rows as the old bundle; CI's .NET steps pass. On the way: since
`c2a77964` (10 July) EF created the context with a second design-time
factory that reads the WebAPI's development settings, so the branch's
migrator failed outside a checkout; there is one factory now (`d1500897`). Pushed
with a smoke test in the release job (`82ea130a`).

On `arch`, 13/10 07:36-07:38 ([phoenix-bundle](2026-10-13-phoenix-bundle.md),
the follow-up; W53): PR validation's migration guard, run as its job runs
it, fails like the bundle job, NETSDK1004; with a restore first it exits 0.
Codex found it while reviewing the restore, before the push.

On `arch`, 13/10 00:14-00:33 ([phoenix-bundle](2026-10-13-phoenix-bundle.md);
W52, W53): the release's Linux database migrator, built twice with the
job's commands. On .NET 10 the job no longer builds it at all: dotnet-ef
10 needs the projects restored first (W53, a side effect of the move to
.NET 10). The restore is in both workflows since `21360193`, not yet run
in CI. With a restore first, the two bundles differ only in the bundle's own small assembly, which
`dotnet ef` builds in a random folder under `/tmp`, and in the bundle ID
(W52). Phoenix's assemblies and the runtime inside are identical.

On `arch`, 12/10 21:01 to 13/10 00:50
([phoenix-module-order](2026-10-12-phoenix-module-order.md); W51): plain
frontend builds with delays added on purpose to module resolution. Five of
six changed the export, in two ways: webpack's module order and the order
of each module's links. Sorting both at seal, next to the entry sort,
gave one export in 21 builds over nine timings and two paths, the same
export as before; on the branch as `61870435`, with CI's frontend lint,
tests and build passing. After Codex's review, `acbea21c` refills the link
sets and keys them by block position: seven more builds, the same export.
The whole release is `00dad37d…` on both, as on `e6ce3549`.

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
Layer 5 (container) is below the SDK 10 table.

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
| Machine | - VM too small W14 | red 13/10 on SDK 10, GitHub against `arch`: the compiler's runtime patch only W58; identical with the same patch | green 13/10 on SDK 10: GitHub's export is `arch`'s, 994 files | red 13/10 on SDK 10 through W58 only; identical with the same patch |
| SDK binary | - empty-class only, 8/9 | - | - Node pinned to 22.23.3 since the merge, ran in main's CI 13/10 W40 | - |
| Network | - | - lock files in place W22 | - offline from a filled cache; lock hashes filled 12/10 W41; npm 10.8.2 drops `libc` W46, main's lock has none since 17/9 | - |
| Windows | - | green 13/10 on SDK 10, built on Linux as the job builds it, unsigned: layer `W` below W55 | built once, on Linux, for both releases | green 13/10 on SDK 10: both Windows zips identical before signing, layer `W` below W55 |

On SDK 10.0.401, from `332752b9`: the whole release with its zips in one
build (layer `Z`), and on `100e3912` the Windows release as its job builds
it on Linux (layer `W`), the cells of the grid above being SDK 9.0.120's.

| Axis | `332752b9` | `e6ce3549`, compression off | `79cb67a7`, after the merge | `100e3912`, Windows (`W`) |
| --- | --- | --- | --- | --- |
| `none` | red 12/10: the endpoints manifest only W50; job worker zip identical | green 12/10: 2121 files, `00dad37d…`; normalised zips identical | green 13/10: 2124 files, `113c707d…`; normalised zips identical | green 13/10: 4256 files, `3f4539bc…`; both zips identical, unsigned W55 |
| `all` | red 12/10: the manifest W50 and five frontend files W51 | green 12/10: `00dad37d…`, also across runs; W51 not hit | green 13/10: `113c707d…`, the same as `none`; W51 not hit | green 13/10: `3f4539bc…`, the same as `none` W55 |
| `locales` | red 12/10: the manifest only; every assembly the same without the pin, W26 gone | green 12/10 without the pin: `00dad37d…` | green 13/10 without the pin: `113c707d…` | green 13/10 without the pin: `3f4539bc…` W55 |

Layer 5, the WebAPI and job worker images on SDK 10.0.401, `100e3912`,
under `none` only (13/10): red as the release job builds them, times only
(W56); identical with `SOURCE_DATE_EPOCH` and `rewrite-timestamp`, on the
WS branch since `fa60ea97`.

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
  the reprotest axes ran without it. The release's migrator is
  reproducible as `src/DbMigrator` (W52, `cd36f241`), measured here, also
  after the merge with its own factory (`805275c4`); CI built and ran it
  on the test tag but compared no builds. On .NET 10 the release job and
  PR validation's migration guard need a restore before `dotnet ef`
  (W53); it is in both since `21360193` and ran in the release job on
  the test tag. The Makefile's EF targets have none and fail on a fresh
  clone (13/10). Since the merge, PR validation's guard runs in the
  reusable .NET build after its restore and build (#787), and passed
  there in main's CI. After the merge the whole release is identical in
  two builds under `none`, `all` and `locales` (`79cb67a7`).
- Windows: the release as its job builds it on Linux is identical in two
  builds before signing (13/10, W55). Open: signing, which makes two runs
  differ by design, CI's Windows job against a local build, and a build on
  Windows. Open points in [windows](windows.md).
- Layer 3: the build ID (W37), the CSS order (W43) and the entry order
  (W47, `a16f9a91`) are fixed on the WS branch. Open: why
  the runtime's minified names changed between commits (W44), the
  Dockerfile's half of the Node pin (W40; 22.23.3 since the merge, which
  main's CI ran), and npm dropping `libc` from the lock (W46): main's lock
  has none since 17/9, so the merged branch's has none either. The lock's
  391 missing hashes are filled (W41, `e19ca414`), and main's 362 again
  after the merge (`bc0c52f6`). W51, the module and link order, is fixed
  on the branch (`61870435`); the jitter test is the check to repeat after
  a Next.js or webpack upgrade, and the merge kept Next.js 15.5.25.
- Layer 4: the zips as CI packs them are red (W48); the normalised packing
  is in the release workflow since `06cb5397` and ran on GitHub on the
  test tag; after the merge its zips are identical in two builds here.
  The Windows publish that came with the merge packed with plain
  `zip -qr`; since `5ec085ac` both jobs pack with one script, tested here
  on Linux trees. The Windows zips themselves, and `SHA256SUMS`, which
  lists them with the Linux zips, are not measured.
- Layer 5: the WebAPI and job worker images differ in times only and are
  identical with the fix (W56, `fa60ea97`), on `arch` with one builder.
  Open: the fix in CI, the three MCP images (base images without digests),
  the manual image script `scripts/docker-build-push.sh`, which pushes
  release images too, and the provenance attestation's times. The
  images' assemblies carry `APP_VERSION` as their informational version
  (W45, read in `P2`'s WebAPI). The Dockerfile's Node pin (W40) is not
  built, as CI skips the SPA build.
- Cross-machine: GitHub's runner against `arch` on 13/10, identical but
  for the compiler's runtime patch (W58). The fix is open: only the
  `global.json` SDK in a folder of its own, or a pinned roll-forward on the
  build steps; Leo's and Peter's choice. File order still needs a VM with
  several GB of RAM (W14); Peter's Azure VM is the candidate.
- Versions: the zips' assemblies carry the commit (`APP_VERSION+<sha>`,
  the SDK's `SourceRevisionId` in a git checkout), the images' do not, as
  `.dockerignore` keeps `.git` out (13/10, phoenix-ci-dry-run).
- Dependency tree: lock files done (W22). Plan, census and repository lookup
  redone on 13/10 for `79cb67a7` (.NET 10, three programs, `dotnet-ef`)
  ([dependency-plan](2026-10-12-dependency-plan.md),
  [declared-env](2026-10-13-declared-env.md)): 341 packages in scope; 53
  declare commit and compiler; 181 keep the PDB outside the package; 126 get
  an exact SDK from the repository. On macOS `DbMigrator` failed a locked
  restore (`NU1004`, host RID added; W54, fixed in `0b52e115`). Symbol servers on 13/10
  ([symbol-servers](2026-10-13-symbol-servers.md)): 474 of 493 missing PDBs
  found; 198 packages now declare commit and compiler. No rebuild yet.
- Developer path (13/10,
  [phoenix-dev-workflows](2026-10-13-phoenix-dev-workflows.md)): fixed on
  the branch (`3e4fbc48`..`100e3912`) and green on a fresh clone. Open:
  the PowerShell migration scripts (not run here), EF snippets in two docs
  without `--context` (as before), W54 on a real Mac, and the untracked
  `.local/share/NuGet/Migrations` folders, which only the test script's
  steps leave in the checkout.
- Method: ASLR alone is untested; reprotest cannot vary it (R1). Why no
  later build used the MSBuild nodes left over on 24/9 is not established.

## Next up

1. Peter: W54's fix on the Mac (`100e3912`, a locked restore of
   `src/DbMigrator`).
2. W58: choose how CI installs .NET, so that the compiler's runtime is
   the SDK's own; then a release run with signing, to measure the signed
   Windows outputs ([phoenix-ci-dry-run](2026-10-13-phoenix-ci-dry-run.md)).
3. PR validation has not run on the merged branch; a draft pull request
   would run it (Leo's call). The release workflow ran on it as the dry run
   of 13/10, the version check and the migrator's smoke test included.
4. Upstream: the dotnet/roslyn issue for W26 (fixed in SDK 10, so only for
   9.0), a dotnet/sdk issue for W50, and Next.js issues for the CSS order's
   missing tie-break (W43) and the entry order (W47). Brief Magnus: the locale defect, the
   dependency warnings, the SDK pin; Node 20's end of life and Node 23 in the
   Dockerfile (W40); the PR filter that misses `mcp/` (W39); from 7/10 the
   one version variable (W45) and the CSS move's cost, about 150 KB per page.
5. File order once the VM exists; across machines, GitHub against `arch` is done (W58).

## Keeping this file

- Change a cell only after the run's note exists. The note is the source.
- One line per axis in the grid, one bullet per open item. If an entry needs
  more than a line, it belongs in a note, linked from the findings table.
- Update the two dates at the top.
