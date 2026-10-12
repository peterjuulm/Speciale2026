# Phoenix: the entry sort as a commit, and the whole release in one build

Experiment note, 12 October 2026, on `arch`. Private data in Leo's
`speciale-2026/data/phoenix-sorted-release/arch-2026-10-12/`; the public part
is in [data/2026-10-12-phoenix-sorted-release/arch/](../data/2026-10-12-phoenix-sorted-release/arch/). Phoenix source
and build output do not land in this repo. Expectation written before the
first run.

## Question

In the lab, sorting the client's webpack entries made the frontend's export
the same in six builds ([phoenix-entry-order](2026-10-12-phoenix-entry-order.md),
W47). Three questions:

1. Does the sort do the same as a commit on the WS branch?
2. Is the whole release reproducible when one build does all of it: the
   frontend, then the .NET publishes with the export inside? Until now
   layer 2 was measured with one export copied in (W42), so the frontend's
   own variation never reached it.
3. Do the 13 pages whose chunks the sort changed still work?

The commit is `a16f9a91` on `thesis/reproducible-builds`, local and not
pushed when measured: `e19ca414` plus the sort in `next.config.js`, as a
plugin object in the existing `webpack` hook, for the client only.

## Setup

- Layer 3: `experiments/phoenix-fe/run.sh` on a fresh export of `a16f9a91`
  in `/private/tmp/rb1-fe`, axes `none`, `all` and `build_path`.
- The whole release: `experiments/phoenix-rt/run.sh` gets a layer `R`. One
  build installs and builds the frontend as layer 3 does, removes
  `node_modules` and `.next`, since CI's publish job gets only `out/` as an
  artifact (`03-release.yml` lines 279-282), and then runs layer 2's
  sequence: locked restore, both publishes with `/p:SkipSpaBuild=true`,
  which copies `out/` into `wwwroot/`. On a fresh export of `a16f9a91` in
  `/private/tmp/rb1-phoenix`, axes `none` and `all`, with
  `APP_VERSION=v0.0.0-thesis` and `LC_ALL=C.UTF-8` in `FIXENV`, as the
  release's Linux jobs set them, and `VER=`.
- The pages: the 13 pages opened in a browser, export C against export A.

## Expectation, written before the run

All `[I]` until measured.

1. Layer 3: all six builds give the lab's export C, `f0d03872b07a1140`. The
   commit sorts with the same comparator at the same hook, and
   `next.config.js` itself does not reach the export.
2. The whole release, `none` and `all`: each run's two builds identical,
   2227 files.
3. Both runs give the same hash list. Its 1237 files outside `wwwroot/` are
   those of `9283b29e…` (7/10), and its 990 files in `wwwroot/` are export
   C's.
4. The 13 pages load and look as they do with export A, with no new errors
   in the console.

## Commands

Run by Claude at Leo's request, in bash. Verbatim in `kommando.txt`.

## Result

`[V]` (`summary.tsv`, the stores' hash lists, the samples):

| Run | Start-end | Exit | Control | Experiment |
| --- | --- | --- | --- | --- |
| `F-none` | 12:53-13:01 | 0 | `f0d03872b07a1140` | `f0d03872b07a1140` |
| `F-all` | 13:01-13:08 | 0 | `f0d03872b07a1140` | `f0d03872b07a1140` |
| `F-build_path` | 13:08-13:16 | 0 | `f0d03872b07a1140` | `f0d03872b07a1140` |
| `R-none` | 13:16-13:29 | 0 | `b72bbc3b45eb9419` | `b72bbc3b45eb9419` |
| `R-all` | 13:29-13:41 | 0 | `b72bbc3b45eb9419` | `b72bbc3b45eb9419` |

- Both labs were checked against `a16f9a91`: 5479 files, 0 missing, 0
  differing, 0 extra.
- Layer 3: all six builds give the lab's export C, 990 files.
- The whole release: 2227 files in each of the four builds, one hash list.
  The 990 files of export C are in `wwwroot/`, byte for byte. The other
  1237, which include 187 static files of .NET's own under `wwwroot/`, are
  exactly the hash list `9283b29e…` of 5 and 7 October.
- `R-all`'s experiment had libfaketime, `LANG=et_EE.UTF-8` under the pinned
  `LC_ALL=C.UTF-8`, `TZ=GMT-14`, the captured `PATH`, the extra variable,
  14 CPUs, umask 0002, another path and `uname` 2.6. No process was left
  after any run.
- Modes in the release (`modes/R-all-*.txt`): 1091 files have 744 under
  either umask, the dependency DLLs that publish copies from the NuGet
  cache, where they have 744 `[V]` (`stat` in `/tmp/dch`); the two
  programs have 755. Under umask 0002, 1088 files get 664,
  and 46 keep 644: the 44 of `public/` and the two `appsettings.json`.

Expectations 1, 2 and 3 held.

The browser check, 13:42-13:55 `[V]` (page text, screenshots and console
in Claude's browser pane):

- Setup: the branch's WebAPI at `a16f9a91`, built in a scratch export, run
  twice on a copy of Leo's local dev database (`wsphoenix_rbview`), one
  instance with export A (`90fb5fe1…`, the morning's `none`) and one with
  export C. Both with email off, no background workers, test login, and the
  one external API in the Development settings pointed at a closed local
  port. The composed reports feature flag was switched on in the copy; the
  instance with A was restarted afterwards, since it caches the flags.
- On all 13 pages the two instances show the same text, compared in full,
  and the same screenshots, once the pages have finished loading. Two
  early readings differed, 200 against 133 table rows and 962 against 555
  characters; read again a few seconds later, both sides matched.
- Real data on the pipeline, asset pipeline, test pipeline and model
  configuration pages. The copy has no composed reports and no uncertainty
  workflows, so those pages ran with made-up ids, and both sides showed the
  same empty or error state: "Error loading composition", "Could not load
  the generated report", "Password required".
- Two pages crash with "Application error" on both sides, with the same
  error at the same place in the same chunk: `ReportViewerToolbar`, a
  component file in `pages/` that Next builds as a page, and the
  uncertainty workflow page with an unknown id, after a 500 from the API.

Expectation 4 held.

## Interpretation

**The fix works as a commit, and the whole release is reproducible.** With
the entry sort on the branch, six frontend builds and four builds of the
whole release came out the same, also with every variation reprotest has
on `arch` at once and at another path. The release's 2227 files split
exactly into export C and the 1237 files of the .NET release measured since
5 October, so the frontend's bytes and the .NET bytes each arrive unchanged.
Built end to end from one commit, the release has one checksum,
`b72bbc3b…`.

**The sort changes no behaviour that the check could see.** The 13 pages
whose chunks it rearranged look and act the same with export A and export
C, down to the same crash in the same place on the two pages that crash.

**File modes are the open part, for layer 4.** The dependency DLLs keep the
NuGet cache's 744 whatever the umask, the build's own files follow the
umask, and `public/`'s files and `appsettings.json` keep the checkout's
mode. A zip stores all three.

## Caveats and not tested

- The commit was local, not pushed, when measured. CI has not built it.
- The whole release was measured on Linux only. The Windows job, the
  migration bundles and the images are not part of it.
- `LC_ALL=C.UTF-8` was pinned for the frontend's part too, where CI's
  frontend job does not set it; the frontend is not affected by the locale
  (morning batch).
- The browser check covered page loads, not use: nothing was clicked,
  saved or generated. Composed reports and uncertainty workflows were seen
  only empty, since the database copy has none.
- One machine, as all of today's runs.
