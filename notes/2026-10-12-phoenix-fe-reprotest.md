# Phoenix: the frontend under reprotest

Experiment note, 12 October 2026, on `arch`. Private data in Leo's
`speciale-2026/data/phoenix-fe-reprotest/arch-2026-10-12/`; the public part
is in [data/2026-10-12-phoenix-fe-reprotest/arch/](../data/2026-10-12-phoenix-fe-reprotest/arch/). Phoenix source and
build output do not land in this repo.

## Question

On 7/10 six builds of the frontend's static export were identical, on one
machine, at one path, with nothing varied
([phoenix-app-version](2026-10-07-phoenix-app-version.md)). Does the export
stay identical when reprotest varies one thing at a time: the build path,
the clock, the locale, the umask, `PATH`, the time zone, the environment,
`HOME`, the kernel, the number of CPUs, the user, and all of them at once?

The commit is `a16eb506` on `thesis/reproducible-builds`, the branch head:
the version as build ID (W37), all third-party CSS in `_app` (W43) and the
calendar fix.

## Setup

- `experiments/phoenix-fe/run.sh AXIS` runs reprotest 0.7.32 on an export of
  the whole commit in `/private/tmp/rb1-fe`, since the frontend imports code
  from `mcp/` (W39). `all-axes.sh` runs the axes after `none` in one batch.
- One build is the release's frontend build, as in `pilot.sh`: `npm ci
  --offline` from the filled cache in `/private/tmp/rb1-npm`, then `npm run
  build` (`next build`), with Node 20.20.2 from `/opt/rb1-node` and
  `APP_VERSION=v0.0.0-thesis`. Then a sorted hash list and a mode list of
  `out/`.
- The protocol is phoenix-rt's without the .NET parts: reprotest starts
  under `env -i` with five variables (R4), the control build gets two CPUs,
  `sample-dotnet.py` follows Node's processes, and any Node process left
  after a run is listed. The build sets nothing reprotest varies: no `LANG`,
  `TZ` or `HOME`.
- `user_group` builds as `rb1b` with a copy of the npm cache in
  `/private/tmp/rb1-shared/npm-cache`, since npm writes a log into its cache
  folder and rb1b cannot write in Leo's.
- `aslr` is not run: alone it changes nothing (R1). `fileordering` and
  `domain_host` cannot run on `arch`.

## Expectation, written before the run

All `[I]` until measured.

1. **`none`**: the two builds are identical, and the hash list is the one
   from 7/10, `4094a6dbe0aa2591` (990 files). That one was built at another
   path, with 16 CPUs, Leo's `HOME` and no `TZ`, so a match already says
   those four do not reach the export.
2. **Every control build has that hash list.** reprotest's control builds in
   a new random folder each run, so this is a second path test across runs.
3. **`build_path`**: green. Webpack names modules and chunks from paths
   relative to the project and from contents. The likeliest way to fail: an
   absolute path in a chunk, or a name derived from one. W44, the webpack
   runtime's minified names that changed between commits, is the candidate.
4. **`time`**: green. None of the 108 pages from 7/10 contains the year
   `[V]` (`grep -l 2026` on `fe-cal/out-1`: 0 of 108), and the three
   scripts that do hold constants: time zone data, help text and a fixed
   date. reprotest moves the clock 398 days ahead, so a page that rendered
   the current date or year at build time would show it. Risk to the run,
   not the result: Node under libfaketime may hang, which would show as a
   timeout.
5. **`locales`** (`et_EE.UTF-8`): green. Node's ICU takes its default locale
   from `LANG`, so a build step that sorts with `localeCompare` and no locale
   would sort differently in Estonian, as Roslyn did (W26). Next's and
   webpack's build code has such sorts `[V]` (grep in `node_modules/next`),
   but the ones in Next are in the app router's plugins, which Phoenix's
   pages router does not use `[I]`.
6. **`umask`**: the contents are green, and the modes of all 990 files
   follow the umask, 644 against 664, as in W30.
7. **`exec_path`, `environment`, `home`, `kernel`, `timezone`**: green. Next
   builds only `NEXT_PUBLIC_` variables into the export, and
   `next.config.js` lists none of its own (no `env` key) `[V]`. No page
   renders a date.
8. **`num_cpus`**: green. Next sizes its worker pools from `os.cpus()`, which
   ignores the CPU affinity reprotest sets `[I]`, so both builds run the
   same 15 workers on different numbers of CPUs. The axis then changes only
   timing, which is what moved the CSS order in W43. A red here would mean
   a timing-dependent order remains after the move to `_app`.
9. **`user_group`**: green.
10. **`all`**: green if 3-9 are.

Timing guess: a build took 5.5 minutes with all 16 CPUs on 6/10 and 8
minutes on 7/10 `[V]` (`pilot-cal.out`). With two CPUs and 15 workers, 15-20
minutes, about 40 minutes per run, and 8 hours for the twelve axes after
`none`.

## Commands

Planned for Leo to type, in fish; run instead by Claude at Leo's request,
in bash, with the same commands. Verbatim in `kommando.txt`.

```fish
rm -rf /private/tmp/rb1-fe; mkdir -p /private/tmp/rb1-fe
git -C ~/Dev/Weel-Sandvig/WS.Phoenix-repro archive a16eb506 -- . ':(exclude).claude' | tar -x -C /private/tmp/rb1-fe
python3 ~/Dev/Speciale2026/experiments/labcheck.py ~/Dev/Weel-Sandvig/WS.Phoenix-repro a16eb506 /private/tmp/rb1-fe
set -x OUT ~/Dev/speciale-2026/data/phoenix-fe-reprotest/arch-2026-10-12
~/Dev/Speciale2026/experiments/phoenix-fe/run.sh none
~/Dev/Speciale2026/experiments/phoenix-fe/all-axes.sh
```

## Result

| Axis | Start-end | Exit | Control | Experiment | Leftover |
| --- | --- | --- | --- | --- | --- |
| `none` | 09:32-09:41 | 0 | `90fb5fe1e063a4b0` | `90fb5fe1e063a4b0` | 0 |
| `build_path` | 09:42-09:53 | 1 | `90fb5fe1e063a4b0` | `4094a6dbe0aa2591` | 0 |
| `time` | 09:53-10:04 | 1 | `90fb5fe1e063a4b0` | `4094a6dbe0aa2591` | 0 |
| `locales` | 10:04-10:15 | 1 | `4094a6dbe0aa2591` | `90fb5fe1e063a4b0` | 0 |
| `umask` | 10:15-10:25 | 1 | `90fb5fe1e063a4b0` | `4094a6dbe0aa2591` | 0 |
| `exec_path` | 10:25-10:35 | 0 | `4094a6dbe0aa2591` | `4094a6dbe0aa2591` | 0 |
| `timezone` | 10:35-10:45 | 1 | `90fb5fe1e063a4b0` | `4094a6dbe0aa2591` | 0 |
| `environment` | 10:45-10:53 | 1 | `4094a6dbe0aa2591` | `90fb5fe1e063a4b0` | 0 |
| `home` | 10:53-11:02 | 0 | `90fb5fe1e063a4b0` | `90fb5fe1e063a4b0` | 0 |
| `kernel` | 11:02-11:10 | 1 | `90fb5fe1e063a4b0` | `4094a6dbe0aa2591` | 0 |
| `num_cpus` | 11:10-11:18 | 0 | `4094a6dbe0aa2591` | `4094a6dbe0aa2591` | 0 |
| `user_group` | 11:18-11:27 | 1 | `90fb5fe1e063a4b0` | `4094a6dbe0aa2591` | 0 |
| `all` | 11:27-11:36 | 0 | `4094a6dbe0aa2591` | `4094a6dbe0aa2591` | 0 |

Against 7/10 (`none`, both builds 990 files `[V]`, `diff` of the hash
lists against `fe-cal/out-1.sha256`):

- 109 of 990 files differ from the 7/10 export of the same commit: the
  webpack runtime `_next/static/chunks/webpack-<hash>.js`, under another
  name (`1033bc45…` against `675a945b…`), and the 108 pages, which name it.
  The other 881 files are identical.
- The two runtimes have the same length, 6729 bytes. They differ in one
  place: the map from chunk id to file name, a chain of `id===e?"file":`
  conditions, lists chunk 4427 two places earlier today.
- Webpack's `GetChunkFilenameRuntimeModule` collects the chunks in Maps and
  Sets in the order it meets them and writes the chain in that order, with
  no sort `[V]` (`next/dist/compiled/webpack/bundle5.js`, Next 15.5.25).
- What differed from 7/10: 2 CPUs against 16, `/tmp` (tmpfs) against
  `/private/tmp` (disk), the path, `HOME` (the build folder against Leo's),
  `TZ=GMT+12` and `LANGUAGE`.
- One run took 8.7 minutes for both builds, against the guess of 40.

`build_path` `[V]` (`diff` of the stores' hash lists; the paths from
`rt-L3-build_path.log`):

- The control, at `/tmp/reprotest.sMQNJz/const_build_path`, has the hash
  list of `none`, which built at `/tmp/reprotest.wHBe4m/const_build_path`.
- The experiment, at `/tmp/reprotest.sMQNJz/build-experiment-1`, has exactly
  the hash list of 7/10, which built at `/private/tmp/rb1-fe`.
- The two differ in the same 109 files: the runtime and the 108 pages.

`time` `[V]` (`rt-L3-time.log`, `samples-L3-time.txt`): both builds at
`/tmp/reprotest.F0kvJh/const_build_path`, the experiment under libfaketime,
`+398days+4hours+7minutes`. The control again has `none`'s hash list, and
the experiment again has 7/10's, in the same 109 files. So the folder name
is not what separates the two orders: a build with the same folder and a
moved clock also gets 7/10's.

`locales` `[V]` (`samples-L3-locales.txt`: the experiment's Node processes
have `LANG` and `LC_ALL` `et_EE.UTF-8`): this time the control has 7/10's
hash list, and the Estonian experiment has `none`'s, in the same 109 files.
So both orders occur under reprotest's fixed conditions: the control had
`none`'s order in three runs and 7/10's in one. The Estonian build is
byte for byte one of the two orders a C.UTF-8 build gives.

`umask` `[V]` (`modes/L3-umask-*.txt`): the contents differ in the same 109
files, control and experiment again on opposite orders. With umask 0002,
946 of the 990 files get mode 664 and 44 keep 644. The 44 are exactly the
files of `public/`, which Next copies into the export with the mode they
have in the checkout. The other 946 are written by the build and follow its
umask.

`all` `[V]` (`rt-L3-all.log`, `samples-L3-all.txt`): the experiment's Node
processes had libfaketime (`+398days+9hours+37minutes`), `et_EE.UTF-8`,
`TZ=GMT-14`, the captured `PATH`, `HOME=/nonexistent/second-build`,
reprotest's extra variable, 7 CPUs and umask 0002, at another path and with
`uname` 2.6. ASLR stayed on: in `all`, reprotest's `aslr` variation keeps it
on, where `kernel` alone turns it off (R2). Both builds have the same hash
list, and the modes split as under `umask`, 946 files 664 and 44 at 644.

Over the batch `[V]` (`summary.tsv`, the stores' hash lists, the samples):

- 13 runs, 26 builds, two hash lists: `90fb5fe1e063a4b0` 12 times and
  `4094a6dbe0aa2591` 14 times. No third one.
- Every red run differs in the same 109 files, the runtime and the 108
  pages. Both hash lists occur in control builds, which reprotest builds
  under its fixed conditions.
- The samples show each variation in the experiment's Node processes. No
  Node process was left after any run.
- A run took 8 to 11 minutes.

Where the expectation failed:

- 1 and 2: `none` did not give 7/10's hash list, and the control builds did
  not agree across runs. Both orders occur under the same conditions.
- 3-5, 7 and 9: those runs are red, but only from the same two orders. No
  axis changed a byte of its own.
- 6: 44 of the 990 files keep 644 under umask 0002.
- 8 and 10 held. The timing guess was five times too long.

## Interpretation

**The frontend's export is not deterministic: the same commit, built the
same way, gives one of two outputs (W47).** The 26 builds split 12 to 14
between two orders of one table in the webpack runtime, and the order came
out both ways under reprotest's fixed conditions. So the six identical
builds of 7/10 did not show determinism; they all fell the same way. Why the
odds were so one-sided then and are even now is not established `[I]`: those
builds ran from disk with 16 CPUs, these from tmpfs with 2 to 7.

**Apart from that order, the export is reproducible on every axis that ran
on `arch`.** An axis that changed the output would have shown up as a third
hash list, and none did in 26 builds. The `all` run, with every variation at
once, gave the same bytes in both builds. The locale, which broke the
release in W26, reaches the frontend's build and changes nothing in it.

**The likeliest cause is a race in Next's own code, read but not yet
measured `[I]`.** Before webpack starts, Next reads the pages in parallel
and adds each one to webpack's entries when its read finishes `[V]`
(`next/dist/build/entries.js` lines 608-651: a `Promise.all` over the pages,
`client[...]` set after an `await`). Webpack numbers the chunk groups in
entry order `[I]` (the research pass's reading of `buildChunkGraph`), and
the runtime writes its table in the order it meets them, with no sort `[V]`.
If two pages finish in a different order, two chunks change places.
Webpack's main branch still collects the chunks unsorted `[V]`
(`lib/runtime/GetChunkFilenameRuntimeModule.js` lines 166-171 on 12/10), and
the newest Next canary vendors the same webpack 5.98.0 as 15.5.25 `[I]` (its
`package.json`, read by the research pass, not by us). The planned checks:
print Next's entry order repeatedly (T1), then build with the entries sorted
by name and see whether the two orders become one (T4).

**The export's file modes depend on two things (W30 for the frontend).** The
files the build writes follow its umask. The 44 files of `public/` keep the
mode they have in the checkout. That matters for the zip (layer 4), which
stores modes.

## Caveats and not tested

- One machine. `fileordering` needs `disorderfs`, which only the shared VM
  has, and that VM is too small (W14).
- `npm ci` runs offline from a filled cache, so the network is not varied
  here; W41 belongs to that axis.
- Only `out/` is compared. `node_modules` and `.next` do not ship.
- Each axis ran once. A run whose two builds fell the same way would also
  hide an axis that only changes the order; no axis is expected to, but
  that is not shown.
- The cause is read in the code, not measured. T1 and T4 come next.
- Whether CPUs, load or the file system shift the odds between the two
  orders is not measured. 26 builds are too few to tell.
