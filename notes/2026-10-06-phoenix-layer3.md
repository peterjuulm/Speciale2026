# Layer 3: Phoenix's frontend export, built twice

Run 6 October 2026 on `arch`. The first measurement of layer 3 in the
[layer plan](2026-09-15-layer-plan.md): the static export of Phoenix's
frontend. Data: `data/2026-10-06-phoenix-layer3/arch/`.

Phoenix is Weel-Sandvig's code and this repo is public. The exports, hash
lists and build logs stay locally with Leo.

## Why layer 3 comes before the zip

The release ships the export. `WebAPI.csproj` copies `ClientApp/out/**` into
the publish's `wwwroot/` `[V]` (`4e5237a3`, `src/WebAPI/WebAPI.csproj` lines
139-141), and both publish jobs first download the export from the release's
frontend job `[V]` (`.github/workflows/03-release.yml`). So the zips (layer
4) cannot be the same bytes before the export is. Our layer 2 lab had no
`out/`, so the release `9283b29e…` of 5/10 is the release without its
frontend.

## How CI builds it

The frontend job (`00-reusable-frontend-build.yml` at `4e5237a3`) sets up
Node `20.x` with `actions/setup-node`, runs `npm ci`, `npm run lint` and
`npm run build`, and uploads `out/` `[V]`. It names only Node's major
version, and no locale. The logs of the last release (v1.0.49, 30
September) have expired on GitHub (HTTP 410, 6/10), so the Node version CI
got cannot be read back.

The frontend is Next.js 15.5.25 (pages router, webpack) with
`output: "export"` in `next.config.js`, so `next build` writes `out/`. The
lock file has 1509 entries `[V]`. The config sets no `generateBuildId`;
Next's default returns `null`, and Next then takes a random `nanoid` as the
build ID `[V]` (`next/dist/server/config-shared.js` line 51,
`next/dist/build/index.js` line 358, `next/dist/build/generate-build-id.js`).

## Setup

- Node v20.20.2 with npm 10.8.2, the last release of Node 20 (24 March
  2026), from nodejs.org's tarball (sha256 `df770b2a…`, checked against
  `SHASUMS256.txt`), unpacked into `/opt/rb1-node`. CI's `20.x` most likely
  resolved to it `[I]`: Node 20 reached its end of life on 30 April 2026.
  Arch's own Node is 26.10.
- An npm cache of its own, `/private/tmp/rb1-npm`. Filled by one `npm ci`
  with network in an export of the frontend (1452 packages, 56 s, 313 MB);
  then `npm ci --offline` installed all 1452 from it (37 s) `[V]`.
- `experiments/phoenix-fe/pilot.sh` builds twice. Each build starts from a
  fresh `git archive` of the whole commit, always at `/private/tmp/rb1-fe`,
  and runs
  `npm ci --offline --no-audit --no-fund && npm run build` under `env -i`
  with `HOME`, `PATH` (Node 20 first), `LANG=C.UTF-8` and `CI=true` as on
  GitHub's runner, the cache, `npm_config_update_notifier=false` and
  `NEXT_TELEMETRY_DISABLED=1`.
- `experiments/phoenix-fe/compare-out.py` compares the two exports as built,
  and again with each build's ID replaced by `BUILD_ID` in paths and
  contents.

Deviations from CI, none of which writes into `out/` `[I]`: `npm run lint`
is not run, and nothing goes on the network (install from the cache, no
audit, no update check, no telemetry).

## Expectation, written before the run

Written before the first attempt (below), and unchanged for the second.

1. Both builds succeed on Node 20, despite the four packages that ask for
   Node 22 (below).
2. The two exports differ.
3. As built, the difference is the build ID: the folder
   `_next/static/<build ID>/` with `_buildManifest.js` and `_ssgManifest.js`
   has a different name in each export, and every HTML page differs.
4. With the build ID replaced, nothing differs: the JS and CSS are the same
   bytes, and no page carries a time, a path or any other random value.

The likeliest way for 4 to fail: Next prerenders the pages in a pool of
worker processes, one fewer than the CPUs, so 15 here `[V]`
(`config-shared.js` line 160). A library that numbers its instances with a
module-level counter would give a page numbers that depend on which pages
the same worker rendered before it, and that can change from build to
build.

If all four hold, a fixed build ID is the only fix layer 3 needs on one
machine and one path, and the reprotest axes come next.

## Commands

Verbatim in `kommando.txt`.

## Result

Attempt 2, 6/10 14:51-15:03, with the whole commit exported `[V]`
(`compare.txt`, `build-1.log`, `build-2.log`):

| Build | Time | Exit | Compiled in | Build ID | Files in `out/` |
| --- | --- | --- | --- | --- | --- |
| 1 | 14:51:55-14:57:37 | 0 | 101 s | `lTVqBUn0v8xesq55_elHE` | 998 |
| 2 | 14:57:44-15:03:10 | 0 | 87 s | `urTNvpc80dd_35qqySlHy` | 998 |

- As built, each export has two files the other lacks, `_buildManifest.js`
  and `_ssgManifest.js` under `_next/static/<build ID>/`, and all 108 HTML
  pages differ. The other 888 files are identical.
- Each page carries its build ID three times `[V]`.
- With the build ID replaced, 0 of the 998 files differ.
- Each export also holds one empty folder, `_next/<build ID>/` `[V]`
  (`find -type d -empty`). The comparison works on files and does not see
  it.
- An export is 38 MB. Among its 998 files are 548 SVG, 227 JS, 108 HTML and
  14 CSS; the rest are images and fonts.

All four expectations held. The module-counter risk did not show.

## Interpretation

**On one machine and one path, the export is deterministic except for the
build ID.** Next draws a random ID for each build and writes it into a
folder name and three times into every page. With the ID replaced, all 998
files are the same bytes. So layer 3 needs one fix: a `generateBuildId` in
`next.config.js` on the WS branch. The ID should still change from release
to release, because the pages load `_buildManifest.js` from a path that
contains it, and a browser could keep an old one `[I]`. The release tag
fits, as `/p:Version` does for the publishes. The empty folder takes its
name from the same ID, so the fix covers it too. That matters for the zip
(layer 4), where `zip -r` stores folders as entries.

## Observations from the setup

- The frontend's build reads code outside its own folder. The first attempt
  of the pilot exported only `src/WebAPI/ClientApp`, and `next build`
  stopped in its lint step with 22 unresolved imports `[V]`
  (`attempt1-clientapp-only-build-1.log`, 6/10 14:38-14:39): 18 into
  `mcp/shared` and `mcp/chat-server/src/shared` at the repo root, and 4
  into `src/WebAPI/utilities/api`, a second copy of the generated API client
  that differs from the one in `ClientApp/utilities/api` `[V]`
  (`git diff --stat` between the two trees: 3 files). `pilot.sh` now exports
  the whole commit, as CI's checkout has it.
- In the whole commit, `ClientApp`'s 1083 source files import 7 files
  outside it, directly or through each other: 4 in `mcp/` and 3 in
  `src/WebAPI/utilities/api`. 34 `ClientApp` files import them, 10 of them
  tests `[V]` (`import-closure.py` on the lab). Webpack built 3 of the 7, the
  code files in `mcp/`, into both the browser bundle and the prerender `[V]`
  (`trace-modules.py` on build 2's `.next/trace`), so they ship inside
  `out/`. The API client is imported only for interfaces (`api.ts` lines
  2170, 6474, 6739), which the compiler erases: the type check and lint read
  it, but it is not bundled. So the frontend is bounded by its import graph,
  not by its folder.
- PR validation runs the frontend checks only for changes under
  `src/WebAPI/ClientApp/**` `[V]` (`01-pr-validation.yml` lines 43-45). A PR
  that changes those three `mcp/` files changes the shipped frontend, yet
  the frontend is not linted, type-checked or built in that PR. A change to
  `src/WebAPI/utilities/api/*.ts` matches none of the filters.

- Four packages in the lock file declare that they need Node 22 or newer;
  `npm ci` on Node 20 warns `EBADENGINE` for each `[V]` (6/10). CI's Node 20
  gets the same warnings, and npm only warns. Two are a code generator for
  the API client and a helper it uses, one is the command-line part of a
  maths renderer, and one is bundled for the browser. None is expected to
  run in `next build` `[I]`. The dependencies have moved past the Node that
  builds the release.
- The frontend's `.npmrc` sets `min-release-age=7`. npm 10.8.2 has no such
  setting (no occurrence in its source; npm 12.2.0's config definitions have
  it) `[V]`, so on CI it is ignored without a warning. `npm ci` takes its
  versions from the lock file either way; the setting only matters when the
  lock file is updated, and only with an npm that knows it.
- 391 of the 1509 lock entries carry neither `resolved` nor `integrity`
  `[V]`. They are pinned by version only: npm has to ask the registry where
  each one is and what its hash should be. So an online `npm ci` depends on
  the registry beyond the lock file.
- Offline, `npm ci` ends with "found 0 vulnerabilities". The audit needs the
  network, so there the line means nothing.

## Caveats and not tested

- CI's Node version is inferred, not read.
- One machine, one path, nothing varied: this is the determinism check that
  comes before the reprotest axes.
- Two builds back to back on an otherwise quiet machine. The module-counter
  risk could still show when the number of CPUs or the load changes.
- `node_modules` is not compared; it does not ship.
- The lint step is left out.
