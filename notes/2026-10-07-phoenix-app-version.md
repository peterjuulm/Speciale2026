# Phoenix: one APP_VERSION for every build

Experiment note, 7 October 2026, on `arch`. Private data in Leo's
`speciale-2026/data/phoenix-app-version/arch-2026-10-07/`; the public part is
in [data/2026-10-07-phoenix-app-version/arch/](../data/2026-10-07-phoenix-app-version/arch/).
Phoenix source and build output do not land in this repo.

## Question

The WS branch commit `5031c5af` gives every build one version, from the
environment variable `APP_VERSION`: the release sets it to the tag, and
everything else builds as `dev`. `Directory.Build.props` reads it for the .NET
projects, and `next.config.js` uses it as the Next.js build ID, which is the
fix for W37. The runs use the branch head `63129480`, which adds the Node
pin (W40) on top: a new `ClientApp/.nvmrc`, two workflows and the WebAPI
Dockerfile, none of which the local builds read. Two questions:

1. Does layer 2's release stay byte for byte the same when the version comes
   from `APP_VERSION` instead of the two `/p:` flags?
2. Are two builds of the frontend's export now identical as built?

## What the commit changes

- Before: the release passed the tag as `/p:Version` and
  `/p:InformationalVersion` to restore and the publishes. The Docker builds
  passed `InformationalVersion` only, the migration bundles got no version,
  the two programs defaulted to `dev` and the libraries to `1.0.0`. The
  frontend drew a random build ID for every build (W37).
- After: `Directory.Build.props` sets `InformationalVersion` to `APP_VERSION`,
  or `dev` when it is unset, and `Version` to the tag without its `v`, for
  tags only. The release workflow sets `APP_VERSION` once for every job and
  passes it to the reusable frontend workflow as an input. The Dockerfiles and
  the manual image script take it as a build argument.
- Checked before the run, by evaluation only `[V]` `dotnet msbuild
  -getProperty` and `node` on copies of the two files in a scratch project:
  unset, empty or `dev` give `InformationalVersion` `dev` and `Version`
  `1.0.0`. `v1.0.49` gives `v1.0.49` and `1.0.49`, the values the old flags
  gave. `v1.0.50-rc.1` gives `1.0.50-rc.1`, and `main` gives `main` and
  `1.0.0`. Next's build ID is `dev` when the variable is unset or empty, and
  the value otherwise.

## Expectation, written before the run

1. Layer 2: `run.sh 2 none` on `63129480` with `VER=` (no `/p:` flags) and
   `FIXENV='LC_ALL=C.UTF-8 APP_VERSION=v0.0.0-thesis'`. Green, and
   `release.sha256` is `9283b29e…`, as on 23/9 and 5/10 `[I]`. The same two
   values reach the same two properties in every project, restore included;
   only the route differs. If it differs, look first at the two `deps.json`
   (the restore's version, W24) and at the libraries' version stamps (W19).
2. Layer 3: `pilot.sh` on `63129480` with `APP_VERSION=v0.0.0-thesis`. Both
   builds have the build ID `v0.0.0-thesis`, and the two exports are identical
   as built: 998 files, none differing `[I]`. The ID names
   `_next/static/v0.0.0-thesis/` and the empty folder `_next/v0.0.0-thesis/`,
   and stands three times in each of the 108 pages, as the random ID did on
   6/10.
3. Today's build 1 against 6/10's build 1, with both build IDs replaced:
   identical `[I]`. Of the frontend, the commit changes only
   `next.config.js`.

## Commands

Verbatim in
[kommando.txt](../data/2026-10-07-phoenix-app-version/arch/kommando.txt).

## Result

| Check | Expected | Result |
| --- | --- | --- |
| 1. Layer 2 `none`, version from `APP_VERSION` | green, `9283b29e…` | green, `9283b29e…` in both builds, 11:40-11:48 |
| 2. Frontend pilot, as built | 998 of 998 identical | red: 1 CSS file renamed, 3 files differ |
| 3. Today's build 1 against 6/10's, IDs replaced | none differing | red: the webpack runtime renamed, 108 pages differ |

1. Held. The build commands carried `APP_VERSION=v0.0.0-thesis` and no
   `/p:Version`; `ApplicationCore.dll` carries `v0.0.0-thesis` and FileVersion
   `0.0.0.0`, and `WebAPI.deps.json` lists `ApplicationCore/0.0.0-thesis`
   `[V]` store of `L2-appver`. Leftover 0.
2. Failed. Both builds have the build ID `v0.0.0-thesis` `[V]` `build-id-1`,
   `build-id-2`, so W37 is closed. But one CSS file differs: the same 266
   rules, 24036 bytes, in another order. Two third-party stylesheets in it,
   the split-pane package `allotment` (34 rules) and `react-day-picker`'s
   (45 rules), swap places `[V]` rule-by-rule diff. The file's name is its
   content hash, so `_buildManifest.js` and the two pages that load the file
   differ as well. 6/10's two builds and today's build 1 have one order,
   today's build 2 the other `[V]`.
3. Failed. The webpack runtime chunk differs: 6872 bytes in both, the same
   code, only the minifier's short variable names assigned differently. All
   108 pages name the runtime by its hash, so all 108 differ; `alarms.html`
   is identical once the runtime's name is normalised `[V]`. Within each day
   the two builds had the same runtime.

## Interpretation

- The `APP_VERSION` route gives layer 2 exactly the bytes the `/p:` flags
  gave. The version mechanism can change without a new layer 2 baseline.
- W37 is fixed: the build ID is now an input. With it out of the way, the
  frontend shows two more sources of difference that the random ID hid on
  6/10:
  - The order of two stylesheets in one CSS chunk is not fixed. Both are
    imported in different modules, and Next's CSS extraction is configured
    to ignore order conflicts (`ignoreOrder: true`, Next 15.5.25
    `dist/build/webpack/config/blocks/css/index.js` line 559 `[V]`), so which
    comes first is probably decided by the order in which modules finish
    building `[I]`.
  - The webpack runtime's minified names differ between the two days.
    Either the commit's change reaches the minifier's input, or the names
    vary from build to build and both days' pairs agreed by chance. Two
    pairs cannot tell these apart `[I]`.

## Second round: third-party CSS in `_app`

The WS commit `eed6c240` moves 20 imports of twelve third-party stylesheets
out of 17 components and pages into `pages/_app.tsx`, after the app's own
`index.css`, in a fixed order. Only `reactflow/dist/style.css`, the default
theme, stays with the three flows that use it, because three other flows
load only `base.css` on purpose. The app's only own CSS was already in
`_app` (`utilities/styles/index.css`).

Why this should remove the swap: Next's CSS chunking plugin (on by default,
`cssChunking: true`, `server/config-shared.js` line 139 `[V]`) takes the
order of the CSS modules in each shared chunk from
`chunkGraph.getChunkModulesIterable`, the order in which modules were added
to the chunk (`css-chunking-plugin.js` lines 43-51 `[V]`), and that order
probably follows how fast modules finished building `[I]`. The plugin skips
chunks named `pages/…` (line 45 `[V]`), so `pages/_app`'s CSS keeps the
order of its imports. With every stylesheet but one in `_app`, no shared
chunk holds two CSS modules whose order could change.

Expectation, written before the run: four builds of `eed6c240`, two
pilots in a row with `APP_VERSION=v0.0.0-thesis`. All four exports are
identical as built `[I]`. Fewer CSS files than the 14 before. The webpack
runtime is the same in all four; if its names varied by chance, four builds
would likely show it `[I]`.

| Builds | Expected | Result |
| --- | --- | --- |
| Pilot 1, builds 1 and 2 | identical | identical, 990 of 990 files, 12:17-12:30 |
| Pilot 2, builds 3 and 4 | identical | identical, 990 of 990 files, 12:30-12:41 |
| Build 1 against build 3 | identical | identical |

All three held `[V]` `compare-out.py`. The export has 2 CSS files instead
of 14: one of 379600 bytes that all 108 pages load (the global CSS was
225513 bytes) and reactflow's theme, 7026 bytes, on 3 pages. The webpack
runtime is the same in all four builds.

Interpretation: at the same path, two builds of the frontend now give the
same export, byte for byte, with nothing replaced. The four clean builds
alone prove little, since the swap came once in four builds before; the
argument is that no shared chunk holds two CSS modules any more. The
runtime's names never differed within a commit, in eight builds of three
commits, so the change between 6/10 and today most likely came from the
commit or its environment, not from chance `[I]`. What reaches the
minifier is not established. The price of the fix is about 150 KB more CSS
on every page, before compression, and a changed cascade where a component
uses a library's classes without its stylesheet: the Tremor calendar
renders `react-day-picker`'s root and button classes and now gets its CSS.
Not checked in a browser.

## Third round: the Tremor calendar

A visual check of `eed6c240` against `63129480` in a browser, both served
by the branch's WebAPI on a copy of the local dev database, found one
change: the Tremor calendar in the Data Explorer lost the orange fill of
its selected days, and its month arrows moved next to the month names
`[V]` screenshots, 7/10. That calendar renders `react-day-picker`'s own
class names for its root and buttons (`react-day-picker` 8.10.2,
`dist/index.esm.js` lines 624 and 2059 `[V]`), and with that library's
stylesheet now on every page, its button reset overrides the calendar's
Tailwind classes. The next WS commit gives those three elements empty
class names in `TremorCalendar.tsx`.

Expectation, written before the run: two builds of that commit are
identical as built `[I]`, and the calendar looks as it did before
`eed6c240` `[I]`.

Result: both held. The WS commit is `a16eb506`. Its two builds, 12:58-13:14,
are identical, 990 of 990 files, though they ran under load from the
browser check `[V]` `compare-out.py`. Served on the same backend, the
calendar shows the selected day filled and the arrows at its edges, as
before the CSS move `[V]` screenshots. A scan for other components that
render a library's class names without importing its stylesheet found no
other case: `react-data-grid`'s 16 such files import only column types and
cell editors, `allotment`'s three sit on the five pages that already loaded
its CSS, and the facility map looked the same in the browser. No rule for a
bare element became global; the only new `:root` variables are
`allotment`'s five, which nothing else uses. Class names assembled at run
time would escape the scan.

## Caveats and not tested

- Not run: the Docker builds (build argument, then environment, then MSBuild
  and npm), the migration bundles, the Windows job and the manual image
  script. Only a release run on a test tag covers the workflow itself.
- In a git checkout the SDK still appends `+<commit>` to
  `InformationalVersion`. Unchanged by the commit, and not measured.
- Layer 1's hash lists change by design: built without a version, the
  libraries now carry `InformationalVersion` `dev` instead of `1.0.0`.
