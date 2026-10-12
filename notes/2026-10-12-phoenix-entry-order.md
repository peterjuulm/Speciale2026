# Phoenix: does Next's entry order decide the frontend's export?

Experiment note, 12 October 2026, on `arch`. Private data in Leo's
`speciale-2026/data/phoenix-entry-order/arch-2026-10-12/`; the public part
is in [data/2026-10-12-phoenix-entry-order/arch/](../data/2026-10-12-phoenix-entry-order/arch/). Phoenix source and
build output do not land in this repo. Expectation written at 11:44, before
the first run; not committed before the run, at Leo's request.

## Question

The morning's reprotest batch
([phoenix-fe-reprotest](2026-10-12-phoenix-fe-reprotest.md)) found that the
same commit gives one of two exports, 12 and 14 times in 26 builds (W47).
They differ in the order of the webpack runtime's map from chunk id to file
name. Read in the code, the likeliest cause is that Next adds the pages to
webpack's entries in the order their reads finish
(`next/dist/build/entries.js` lines 608-651), and the runtime keeps the
order it meets the chunks in. Two questions:

1. **T2:** does the entry order vary between builds, and does it decide
   which export comes out?
2. **T4:** with the entries sorted by name before webpack makes any chunk,
   do all builds give one export?

The commit is `e19ca414`, the branch head: `a16eb506` plus Peter's filled
lock hashes (W41), which change nothing but `package-lock.json`.

## Setup

- `experiments/phoenix-fe/entry-lab.sh e19ca414` exports the commit to
  `/private/tmp/rb1-fe-entry`, checks it with `labcheck.py`, and wraps the
  frontend's `next.config.js`: the commit's config is renamed
  `next.config.orig.js`, and `next.config.wrap.js` takes its place. The
  wrapper keeps every setting, runs the original's `webpack` hook, and adds
  `entry-order-plugin.js` to each compiler. The original already has a
  `webpack` hook, so Next's build worker stays off, as in the real build
  `[V]` (`next/dist/build/index.js` line 835).
- The plugin taps `compilation.hooks.seal`, which webpack calls before it
  creates chunks `[V]` (`bundle5.js`: `this.hooks.seal.call()` comes before
  "create chunks"). It writes the entry names in order to a file, and with
  `ENTRY_SORT=1` sorts the client compilation's entries by name.
- `entry-runs.sh` runs `run.sh` on that lab six times: T2 is three runs of
  `none` with logging only; T4 is `none`, `all` and `build_path` with the
  client's entries sorted. Everything else is as in the morning's batch.

## Expectation, written before the run

All `[I]` until measured.

1. `npm ci --offline` succeeds on `e19ca414`: Peter's 391 filled hashes
   match the tarballs in the cache, which npm checks on install.
2. **T2:** every export is exactly one of the morning's two, `90fb5fe1…` or
   `4094a6db…`. Neither the lock fill nor the logging plugin changes a byte.
3. **T2:** the client's entry order differs between some of the six builds,
   and builds with the same entry order give the same export. If the order
   is the same in all six while the exports differ, the race is elsewhere
   and the explanation fails.
4. **T4:** all six builds give one export, a third one, neither A nor B. It
   differs from them in the runtime and the 108 pages only. If the race were
   unaffected, six builds falling the same way would happen about 3% of the
   time.
5. **T4:** the logged order, before the sort, still varies.

## Commands

Run by Claude at Leo's request, in bash. Verbatim in `kommando.txt`.

## Result

T2, the entries logged only `[V]` (`summary.tsv`, `entry-log/`, the
stores' hash lists):

| Run | Start-end | Exit | Control | Experiment |
| --- | --- | --- | --- | --- |
| `E-log-1` | 11:44-11:52 | 0 | `90fb5fe1e063a4b0` | `90fb5fe1e063a4b0` |
| `E-log-2` | 11:52-12:02 | 1 | `4094a6dbe0aa2591` | `90fb5fe1e063a4b0` |
| `E-log-3` | 12:02-12:10 | 1 | `4094a6dbe0aa2591` | `90fb5fe1e063a4b0` |

- Every `npm ci --offline` installed 1452 packages; no integrity error in
  any log.
- Every export is one of the morning's two: A (`90fb5fe1…`) 4 times, B
  (`4094a6db…`) 2 times.
- The client compilation's entries, 110 names, came in 5 different orders
  in the 6 builds. Only the two builds of `E-log-1` share one. The order is
  near alphabetical with pages out of place, mostly near the end.
- Builds with the same order gave the same export. Different orders also
  gave the same export: 4 orders gave A.
- Of the 5995 pairs of entries, 2 are in one relative order in all A builds
  and in the other in both B builds: in A, `test-pipeline` (under
  `pipeline-manager/[pipelineid]/`) comes before `settings/feature-flags`
  and before `workflow-manager`.
- The server compiler's entries vary too. For the names the two compilers
  share, the server's order is the client's; the server also has
  `pages/_document`, and its place is what differed in `E-log-1`.

T4, the client's entries sorted by name `[V]`:

| Run | Start-end | Exit | Control | Experiment |
| --- | --- | --- | --- | --- |
| `E-sort-none` | 12:10-12:20 | 0 | `f0d03872b07a1140` | `f0d03872b07a1140` |
| `E-sort-all` | 12:20-12:27 | 0 | `f0d03872b07a1140` | `f0d03872b07a1140` |
| `E-sort-build_path` | 12:27-12:36 | 0 | `f0d03872b07a1140` | `f0d03872b07a1140` |

- All six builds gave one export, C, 990 files. The six logged orders,
  taken before the sort, were all different.
- The `all` experiment ran with every variation that runs here
  (`samples-E-sort-all.txt`: libfaketime, `et_EE.UTF-8`, `TZ=GMT-14`, the
  captured `PATH`, the extra variable, 9 CPUs, umask 0002), and
  `build_path`'s experiment at `build-experiment-1`.
- C has A's runtime, byte for byte. Against A it differs in 21 files: five
  shared chunks and two page chunks under the same chunk ids with other
  contents, `_buildManifest.js`, and the 13 pages that load those chunks,
  under `reports/composed-reports`, `pipeline-manager`,
  `model-manager/configuration/[id]/update` and `uncalibration-workflow`.
  Against B it differs in the runtime and all 108 pages as well.
- No Node process was left after any run. A run took 7 to 10 minutes.

Where the expectation failed: 4 held for the export, but C differs from A
and B in more than the runtime and the pages. 1, 2, 3 and 5 held.

## Interpretation

**Next's entry order decides the export, and sorting it makes the export
deterministic (W47).** Without the sort, the client's 110 entries came in a
new order in almost every build, and the export followed: different orders
can give the same export, but every B build had an order of its own. With
the sort, six builds with six different orders gave one export, also with
every variation at once and at another path. Six builds falling the same way
by chance, with the race left alone, would happen about 3% of the time.

**The order reaches more than the runtime's table.** Sorting changed five
shared chunks and two page chunks as well: webpack places modules in some
shared chunks in the order it meets the entries `[I]`. A and B happen to
agree on those, so they differed only in the runtime. The sort settles both
at once, but the release's bytes change in 21 files beyond the runtime.
Module order inside a chunk does not change what the code does in webpack,
which registers modules by id `[I]`; a check in a browser of the 13 pages
would show it.

**Where a fix belongs.** In Phoenix, the plugin's sort is about 10 lines in
`next.config.js`, at `compilation.hooks.seal`, a public webpack hook.
Upstream, Next could sort the client's entries in `createEntrypoints`; a
few lines above the race it already sorts the app router's parallel
routes, "to make the result deterministic" `[V]`
(`next/dist/build/entries.js` line 602).

## Caveats and not tested

- Twelve builds in all. The 3% assumes the race's odds stayed near even,
  as in the morning's 26 builds and these six.
- The pages of C were not opened in a browser.
- Only the client's entries were sorted. The server's vary too, but the
  server's bundles do not ship in `out/`, and the export was the same in
  every sorted build.
- The lab, not a commit: the wrapper, the original config and the plugin are
  three files on top of `e19ca414`. A fix on the WS branch must be measured
  again as a commit.
- Which pages' order decides the runtime's table is not established. In T2
  two pairs of pages separate A from B, and with 5995 pairs and six builds,
  that can be chance.
