# Phoenix: the frontend under reprotest

Experiment note, 12 October 2026, on `arch`. Private data in Leo's
`speciale-2026/data/phoenix-fe-reprotest/arch-2026-10-12/`; the public part
will be in `data/2026-10-12-phoenix-fe-reprotest/arch/`. Phoenix source and
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

Typed by Leo, in fish. Verbatim in `kommando.txt` after the run.

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
| `none` | | | | | |
| `build_path` | | | | | |
| `time` | | | | | |
| `locales` | | | | | |
| `umask` | | | | | |
| `exec_path` | | | | | |
| `timezone` | | | | | |
| `environment` | | | | | |
| `home` | | | | | |
| `kernel` | | | | | |
| `num_cpus` | | | | | |
| `user_group` | | | | | |
| `all` | | | | | |

## Interpretation

## Caveats and not tested

- One machine. `fileordering` needs `disorderfs`, which only the shared VM
  has, and that VM is too small (W14).
- `npm ci` runs offline from a filled cache, so the network is not varied
  here; W41 belongs to that axis.
- Only `out/` is compared. `node_modules` and `.next` do not ship.
