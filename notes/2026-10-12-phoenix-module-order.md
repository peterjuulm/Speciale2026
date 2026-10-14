# Phoenix: the frontend's module order (W51)

Experiment note, 12 October 2026, on `arch`. Private data in Leo's
`speciale-2026/data/phoenix-module-order/arch-2026-10-12/`; the public part
will be in `data/2026-10-12-phoenix-module-order/arch/`. Phoenix source and
build output do not land in this repo. Expectation written before the
first build.

## Question

In [phoenix-net10-release](2026-10-12-phoenix-net10-release.md), one build
of about 50 had two pages swap the ids of two byte-identical chunks (W51),
although the client's entries are sorted (W47). The suspected cause: the
order of webpack's `compilation.modules`, which is the order in which
modules finished resolving. When two chunks get the same deterministic-id
key, webpack breaks the tie by order. Two questions:

1. Does the export follow the module order: when the order is perturbed on
   purpose, do the two pages swap ids?
2. Does sorting the modules by identifier at the start of seal, as W47's
   fix sorts the entries, give one export whatever the order?

## Setup

- Lab: an export of the WS branch's `e6ce3549` with the frontend's
  `next.config.js` wrapped (`experiments/phoenix-fe/module-lab.sh`), so that
  `module-order-plugin.js` runs in every compiler, after the commit's own
  webpack hook (which sorts the client's entries).
- The plugin: `MODULE_JITTER_SEED` makes every module request wait 0-15 ms
  before it resolves, the wait taken from a hash of the seed, the context
  and the request, so each seed gives another timing. `MODULE_SORT=1` sorts
  the client compilation's modules by identifier at `compilation.hooks.seal`.
  Each compilation logs a hash of its module order as it reached seal,
  before any sort.
- Builds: plain builds one after another at the same path, not under
  reprotest (`module-runs.sh`): each removes `node_modules`, `.next` and
  `out`, runs `npm ci --offline` from the filled cache and `npm run build`
  under `env -i`, with `APP_VERSION=v0.0.0-thesis`. B0 without jitter or
  sort; J1-J6 with seeds 1-6; S1-S4 with seeds 1-4 and the sort.
- What tells the two assignments apart: the page chunk that is
  `…-34bede13301a474d.js` in every earlier build and `…-4978a9725aac8d15.js`
  in the one odd build.

## Expectation, written before the run

All `[I]` until measured.

1. The client compilation's module-order hash differs between J1-J6 and
   from B0; the jitter reaches the order.
2. If the cause is the module order, some of J1-J6 give the swapped
   assignment, maybe with other differences in the same pages; if none
   does, the suspicion is not supported, or the jitter does not reach the
   order that matters.
3. S1-S4 give one export, whatever their module-order hash before the sort.
   It may differ from B0's, since the sorted order is another order.

## Commands

Run by Claude at Leo's request, in bash. Verbatim in `kommando.txt`.

## Result

`[V]` (`module-runs.out`, the hash lists of the exports, the module-order
logs), 21:01-21:35, eleven builds of about three minutes, each export 990
files:

| Build | Seed | Sort | Client's module order at seal | Export | Against B0 |
| --- | --- | --- | --- | --- | --- |
| B0 | - | no | `b3e4298a…` | `f0d03872…` | |
| J1 | 1 | no | `9dba7254…` | `f0d03872…` | the same |
| J2 | 2 | no | `6e6a0e6a…` | `6694b084…` | A and B |
| J3 | 3 | no | `328baf69…` | `c3fa0085…` | A |
| J4 | 4 | no | `5d53fcf0…` | `c3fa0085…` | A |
| J5 | 5 | no | `54eb9378…` | `c3fa0085…` | A |
| J6 | 6 | no | `39d2fb05…` | `c3fa0085…` | A |
| S1 | 1 | yes | `46cf4bd2…` | `f0d03872…` | the same |
| S2 | 2 | yes | `72b966cb…` | `14aeffed…` | B |
| S3 | 3 | yes | `1f733768…` | `f0d03872…` | the same |
| S4 | 4 | yes | `bc4e540c…` | `f0d03872…` | the same |

- Every build's client compilation had 9591 modules, and every jittered
  build reached seal with another module order.
- B0 is the export the commit gives without the plugin's jitter or sort,
  the same `f0d03872…` as in
  [phoenix-sorted-release](2026-10-12-phoenix-sorted-release.md).
- A is W51's swap, file for file as in `Z-all`'s odd build: the same two
  page chunk names, `_buildManifest.js` and the two pages' HTML.
- B: one shared chunk has id 3002 instead of 5631, so its file has another
  name, and the 102 page chunks that load it, `_buildManifest.js` and the
  pages' HTML change with it, 103 names and 103 contents in all. J2 has A
  and B together; S2 has B alone.

Where the expectation failed: 1 and 2 held. 3 held for A, which no sorted
build showed, but not for B, which seed 2 gave with the sort as without.

### Where B comes from

`[V]` 21:35-21:52, five more builds with the sort and a log of every client
chunk once its id is set (`MODULE_CHUNK_LOG`): D1 (seed 1), D2 and D2r
(seed 2 twice), R1 and R2 (as D1 and D2, also listing each unnamed chunk's
root modules). `compare-chunks.py` on the logs:

- D1 gives `f0d03872…`, D2 and D2r both `14aeffed…`, the same as S2: with
  the jitter, a seed gives the same export each time.
- D1 and D2 have the same 229 chunks, 128 named and 101 unnamed, with the
  same module sets. One chunk differs: an unnamed chunk of 25 modules, id
  5631 in D1 and 3002 in D2. Its modules are the same, but its root modules
  are not: in R1 one, a layout component; in R2 two, the layout component
  and one of the pages, which the chunk also holds.
- For an unnamed chunk, webpack's deterministic id is a hash of its root
  modules' identifiers (`getFullChunkName`), so other roots give another id.
  The roots come from `findGraphRoots` over the chunk's modules and their
  outgoing connections (`ChunkGraph._getGraphRoots`). Its cycle detection
  is a depth-first walk that follows the order of the modules and of their
  connections, and it can count a node into a cycle or leave it out
  depending on that order `[V]` (the code in Next's `bundle5.js`). The
  connections are kept in the order their dependencies finished resolving
  `[I]`, which the module sort does not touch.

### Two candidate fixes

Both keep the entry sort and the module sort. Written down before these
builds: each candidate must give one export for every seed.

- C: every client module's outgoing and incoming connections are also
  sorted at seal, by the module at the other end, then the dependency's
  type, location and index in its block (`MODULE_SORT_CONNECTIONS=1`).
  The connections are webpack's internal sortable sets, which the public
  `getOutgoingConnections` hands out.
- I: unnamed client chunks get their ids before webpack's own numbering,
  from a hash of all their sorted module identifiers and the names of their
  chunk groups (`CHUNK_IDS_BY_CONTENT=1`), so roots no longer matter.

`[V]` 21:54-22:13, seed 0 meaning no jitter:

| Build | Seed | Export |
| --- | --- | --- |
| C0 | - | `f0d03872…` |
| C1 | 1 | `f0d03872…` |
| C2 | 2 | `f0d03872…` |
| I0 | - | `d6104ad7…` |
| I1 | 1 | `d6104ad7…` |
| I2 | 2 | `d6104ad7…` |

Both give one export over these seeds, seed 2 included. C's is B0's,
byte for byte: sorting the connections changes nothing when nothing
perturbs them, and the export that passed the browser check on 12/10
stays. I's renumbers every unnamed chunk. Codex, asked for a second
opinion with these results, preferred C for the branch, and asked to try
the outgoing connections alone before keeping the incoming sort, and not
to claim more than the seeds tested.

`[V]` 22:13-22:36, C with seeds 3-8, and C2p: seed 2 in a lab at another
path, `/private/tmp/rb1-fe-module-alt/x`. All seven gave `f0d03872…`.
So C gave one export in ten builds: nine timings and two paths.

`[V]` 22:36-22:49, O0-O3: as C, but only the outgoing connections sorted
(`MODULE_SORT_CONNECTIONS=out`). All four gave `f0d03872…`, seed 2
included. The incoming sort is not needed for anything these builds show,
so the branch leaves it out.

### The fix on the branch

WS commit `61870435`, "Sort webpack's modules and links before chunking",
pushed: the plugin in `next.config.js` that sorted the client's entries
(W47) now also sorts the modules by identifier and each module's outgoing
links by the module they lead to, then the dependency's type, location and
index in its block, all at `compilation.hooks.seal`. If webpack hands out
links that cannot be sorted, the build fails. Its checks `[V]`:

- CI's frontend steps on the change, offline: `npm ci`, `npm run lint`
  (no warnings), `npm test` (123 suites, 1330 tests passed),
  `npm run build`, whose export is `f0d03872…`, 990 files.
- The commit itself in the lab, with the probe plugin adding only the
  jitter (`commit-c6b57330/`; `c6b57330` is the same tree as `61870435`,
  before the commit message was amended): B0 and J1-J6 all gave
  `f0d03872…`. Without the fix, J2-J6's seeds gave two other exports.

### A follow-up after review

Codex reviewed the pushed plugin and found two weak spots `[V]` (webpack's
`SortableSet` in Next's bundle). `sortWith` clears only the caches webpack
keeps for order-dependent views, not those it treats as order-free, such as
the links grouped by module: a view taken before the sort would keep the
old order. And the key could tie: `getParentBlockIndex` is an index within
one block, so two blocks can hold a dependency at the same index, and a
location's JSON text is not a source position.

WS commit `acbea21c`, pushed: the set is emptied and refilled in sorted
order, which clears all its caches; the key is the target plus the chain
of blocks down to the dependency (`block.parent`, `parent.blocks`) and its
index there, unique within the module; the guard checks for a `Set`.
`[V]` CI's frontend steps pass (1330 tests), the build gives `f0d03872…`,
and the commit in the lab with only the jitter (`commit-acbea21c/`, B0 and
J1-J6, 23:52-00:14) gave `f0d03872…` in all seven builds.

## Interpretation

**The export followed the order in which webpack's inputs arrived.** `[V]`
The jitter changes nothing but timing, and it changed the export in five
of six builds, in two ways. With the entries sorted (W47), two orders were
left. The order of `compilation.modules` decided which of two identical
chunks a page got (A): sorting the modules removed it in every build. The
order of each module's outgoing links decided which root modules webpack
found for one chunk, and so its id (B): sorting the links removed it in
every build, seed 2 included.

**Why W51 showed once in about 50 builds.** `[I]` Ordinary timing varies
less than the jitter: most builds resolve modules in nearly the same
order, so the same export comes out, and only a rare build crosses one of
the ties. The jitter makes those crossings common, which is what made the
cause measurable in an evening.

**The fix changes no shipped byte.** `[V]` The sorted builds give the
export that the natural builds gave in about 50 of 51 builds, the one
checked in a browser on 12/10. The fix only removes the other outcomes.

**Upstream.** `[I]` Two webpack behaviours are order-dependent where an
order-free answer exists: `findGraphRoots`' cycle detection depends on the
walk order, and so does every unnamed chunk's deterministic id; and
`SplitChunksPlugin` keeps the first of two equal candidates. Neither is
reported.

## Caveats and not tested

- The jitter delays module resolution only. Other timing, such as when a
  loader finishes, moves with it but is not perturbed on its own `[I]`.
- Nine timings (seeds 0-8) and two paths are evidence, not a proof that
  no order is left: another webpack consumer of make-phase order could still tie
  (Codex's point). The jitter test is the check to repeat after every
  Next.js or webpack upgrade.
- The fix depends on webpack keeping each module's links in a `Set` that
  it reads in insertion order. The build fails if they stop being a `Set`;
  a change of meaning behind the same shape would not be caught.
- Only the client compilation is sorted. The server's output reaches the
  export only through the rendered HTML, which did not differ here.
- The incoming links are left unsorted, since no build needed them sorted.
- One machine.
- The lab `/private/tmp/rb1-fe-module-alt` was no longer on `arch` by 14
  October 2026.

## The whole release on the fix

`[V]` 23:17-23:47, `run.sh Z` under `none` and `all` on `61870435`
(`ZEPOCH` 1791839809, the lab checked file by file): all four builds give
the release `00dad37d…`, 2121 files, the same as on `e6ce3549` before the
fix, and the same two normalised zips (`ed5d36ff…` for the job worker,
`5a66c09e…` for the WebAPI; another `ZEPOCH`, so other bytes than on
`e6ce3549`). Only the CI zips differ, as always (W48). So the fix changes
no shipped byte, end to end.

`[V]` 13/10 00:33-00:50, `Z` under `none` on the branch head `acbea21c`,
the follow-up (`head-acbea21c/`; `ZEPOCH` 1791841936): both builds give
`00dad37d…` again, with identical normalised zips.
