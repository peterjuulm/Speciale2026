# reprotest checked against itself: what each axis changes in a build

Run 5 October 2026 on `arch`, alongside the
[full rerun](2026-10-05-phoenix-rerun.md). Its caveats list what a reading of
reprotest's code found; this note tests it.
Data: `data/2026-10-05-reprotest-probe/arch/`.

## Question

reprotest is our measuring instrument. For each axis: does it change what we
think in the build, and nothing else? What does a build under reprotest
inherit from the shell that starts it? And is any axis a no-op?

## Setup

- `experiments/reprotest-probe/probe.sh` is the "build": shell commands that
  write down what they see, one file per property: the environment, umask,
  the mode of a new file, CPUs, the date, the time zone offset, `uname`, the
  process personality, whether ASLR is on (from the stack address), user and
  group, the working directory, host and domain name, glibc's `locale`, ICU's
  default locale and time zone (`icuinfo`; .NET reads ICU's on Linux), and
  whether libfaketime is loaded. No compiler, no network, no Phoenix.
- `experiments/reprotest-probe/run.sh` runs it under reprotest 0.7.32 as the
  Phoenix runs do: null backend, `--min-cpus 2`, one axis at a time, plus
  `none` and `all`. But with `-vv`, so the log holds the exact script
  reprotest executes. Lab `/private/tmp/rb1-probe`, holding only `probe.sh`.
- Two rounds. `inherited`: reprotest started from Claude Code's shell, as the
  Phoenix batch was. `clean`: started under `env -i` with only `HOME`, `USER`,
  `LOGNAME`, `SHELL` and `PATH`, for `none`, `user_group` and `all`.
- The stores hold every build's whole environment, session tokens included,
  so they stay in Leo's private folder. `summarize.py` writes what may be
  published: values only for locale, time, user, home and path variables,
  the rest by name. It stops if a hidden value would be written.
- It runs while the Phoenix batch runs. It starts no dotnet process and uses
  its own lab, so it cannot reach the batch's build servers or sampler.

## Expectation, written before the run

From the code of reprotest 0.7.32 (`build.py`, `__init__.py`):

1. `none`: nothing differs. Both builds get `LANG=C.UTF-8`,
   `LANGUAGE=en_US:en`, `TZ=GMT+12`, `HOME` in the build folder, umask 0022,
   two CPUs, and the calling shell's other variables, the ten `LC_*`
   (`da_DK.UTF-8`) included. ICU's default locale is `en_US_POSIX`.
   Personality `00000000`, ASLR on: without the `kernel` axis there is no
   `setarch`, so the fixed `-R` is never applied.
2. `build_path`: the working directory, and with it `HOME` and `PWD`.
3. `time`: the date, 398 or 399 days later; libfaketime loaded; `FAKETIME`,
   `LD_PRELOAD` and `NO_FAKE_STAT=1` in the environment.
4. `locales`: `LANG`, `LC_ALL` and `LANGUAGE` (`et_EE.UTF-8`, and
   `et_EE.UTF-8:fr`); glibc's `locale`; ICU's default `et_EE`.
5. `umask`: umask 0002 against 0022, a new file 664 against 644.
6. `exec_path`: `PATH` gains `/i_capture_the_path`.
7. `timezone`: `TZ=GMT-14` against `GMT+12`, the offset `+1400` against
   `-1200`, and ICU's time zone.
8. `environment`: `REPROTEST_CAPTURE_ENVIRONMENT` added.
9. `home`: `HOME=/nonexistent/second-build`.
10. `kernel`: `uname` reports a 2.6 kernel, the personality gains UNAME26,
    and ASLR turns off: `setarch` now runs, with the fixed `-R`. Two things
    vary under this axis.
11. `aslr`: nothing differs. ASLR is on in both builds; the axis is a no-op
    on its own. This is the main thing to settle: today's Phoenix samples
    show ASLR on in every process `[V]` `aslr=on` in 3541 samples.
12. `num_cpus`: two CPUs against 3 to 16.
13. `user_group`: user and group `rb1b`. Weakly held: whether `sudo` also
    changes `USER`, `LOGNAME` or `PATH` under `-E`.
14. `all`: the differences of 2-10 and 12 together, but ASLR on in both
    builds: the varied `aslr` drops the `-R` that `kernel`'s `setarch` would
    get.
15. `domain_host`: fails. Arch has no `domainname`.
16. `fileordering`: fails, with reprotest's warning that it needs
    `disorderfs`.
17. `clean` round: the same differences as `inherited` for `none`,
    `user_group` and `all`. The base environment loses the `LC_*`, the
    desktop session's and the `CLAUDE_*` variables. ICU's default is still
    `en_US_POSIX`.

## Commands

Verbatim in `kommando.txt`.

## Result

Run 13:10-13:13. 19 runs, all `[V]` `summary.txt` (from the stores) and the
build scripts in `scripts/`.

Every run that completed reported differences, `none` included, because the
CPU set differs in every run: with the CPU count fixed at two, reprotest
still picks the two CPUs at random for each build, e.g. CPUs 9 and 15 for the
control and 5 and 14 for the experiment. The table leaves that out.

| Run | What else differs between the two builds | Expectation |
| --- | --- | --- |
| `none` | nothing | 1 held, except the CPU set |
| `build_path` | working directory, `HOME`, `PWD` | 2 held |
| `time` | date 2026-10-05 against 2027-11-07; libfaketime loaded; `FAKETIME`, `FAKETIME_SHARED`, `LD_PRELOAD`, `NO_FAKE_STAT=1` | 3 held; `FAKETIME_SHARED` not foreseen |
| `locales` | `LANG`, `LANGUAGE`, `LC_ALL`; glibc cannot load `et_EE.UTF-8` and says so; ICU's default `et_EE` | 4 held |
| `umask` | umask 0002, a new file 664 | 5 held |
| `exec_path` | `PATH` gains `/i_capture_the_path` | 6 held |
| `timezone` | `TZ`, offset `-1200` against `+1400`, ICU's zone | 7 held |
| `environment` | `REPROTEST_CAPTURE_ENVIRONMENT` added | 8 held |
| `home` | `HOME=/nonexistent/second-build` | 9 held |
| `kernel` | `uname -r` 2.6.62; personality `00060000` (UNAME26 and ADDR_NO_RANDOMIZE); ASLR off | 10 held |
| `aslr` | nothing | 11 held: the axis is a no-op |
| `num_cpus` | 2 CPUs against 7 | 12 held |
| `user_group` | user and group `rb1b`; `USER`, `LOGNAME`; `PATH` replaced by sudo's `/usr/local/sbin:/usr/local/bin:/usr/bin`; `SUDO_HOME` and `TERM` added | 13 held; the `PATH`, `SUDO_HOME` and `TERM` changes were the open part |
| `all` | the differences of `build_path` to `kernel` and `num_cpus` together; personality `00020000`, ASLR on in both builds | 14 held |
| `domain_host` | exit 125: the build stops with status 127 | 15 held |
| `fileordering` | exit 125, after reprotest's warning that it needs `disorderfs` | 16 held |
| `clean` round | the same differences for `none`, `user_group` and `all` | 17 held |

In both rounds the control's ICU default is `en_US_POSIX`, and ASLR is on in
both builds of every run except `kernel`'s experiment.

The control's base environment: 105 variables in the `inherited` round, 14
in the `clean` round. The 92 missing ones are the nine other `LC_*`
(`da_DK.UTF-8`), the desktop session's (`DBUS_*`, `XDG_*`, `WAYLAND_DISPLAY`
...), 27 `CLAUDE*`, and `OUT`, a variable of our own `run.sh`. The clean round
gains one: `LC_CTYPE=C.UTF-8`.

The kernel axis picks its `setarch` architecture at random: `uname26` in
the `kernel` run, `linux64` in both `all` runs. Both report `x86_64`.

## Interpretation

**reprotest does what its code says.** All 17 expectations held, with one
detail wrong in the first: the CPU set. The code reading can be trusted for
the rest of the axes.

**Two axes are not what their names say.** `aslr` on its own changes
nothing: both builds run with ASLR on. ASLR is only switched off by the fixed
setting `-R`, and that reaches the build only when the `kernel` axis puts
`setarch` in front of it. So `kernel` varies two things at once, the kernel
version and ASLR, and `all` varies neither ASLR nor leaves it off. For our
Phoenix runs: the `aslr` runs test nothing, the `kernel` runs test both, and
ASLR off is never tested alone.

**Most axes change more than one variable.** `build_path` moves `HOME` with
the folder, `user_group` changes `PATH`, `USER` and `LOGNAME` and adds
`SUDO_HOME`, `time` adds four variables, and the CPU set is random in every
build. None of this is in reprotest's descriptions of the axes. A red result
on one of these axes names a group of changes, not one.

**The base environment belongs to whoever starts reprotest.** Started from
our shell, the builds carry 105 variables, among them our own scripts'. A
launch under `env -i` cuts that to 14 listed ones. This matters for .NET:
MSBuild makes every environment variable a property, and Phoenix's own
`Directory.Build.props` switches locked restore on `GITHUB_ACTIONS` `[V]`
the branch. The environment is an input to the build, and reprotest's
`environment` axis tests only the addition of one unknown variable. The
`LC_CTYPE=C.UTF-8` in the clean round is most likely Python's coercion of
the C locale (PEP 538), since reprotest runs on Python `[I]`.

## Caveats and not tested

- The probe's commands are shell tools. A .NET process could read something
  differently; that ICU's `en_US_POSIX` becomes .NET's invariant culture is
  not measured.
- One run per axis. The random picks (the CPU set, the hours of the time
  shift, the `setarch` architecture) differ from run to run.
- It ran while the Phoenix batch ran. They share only the CPUs.
- The personality and ASLR are read by the probe's own processes, which
  inherit them from the build shell.
