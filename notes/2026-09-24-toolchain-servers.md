# Do other toolchains leave a process behind for reprotest's second build?

Run 24 September 2026 on `arch`. Follows
[phoenix-layer2-reprotest](2026-09-24-phoenix-layer2-reprotest.md), where
.NET's compiler server survived reprotest's control build and did the
experiment's compiling without the variation.
Data: `data/2026-09-24-toolchain-servers/arch/`.

## Question

Benedetti et al. (ICSE 2025) ran reprotest the same way we did: locally, one
variation per run, both builds as the same user (their wrapper,
`external/benedetti-2025/`). Could their verdicts contain the same false
greens? For the build commands they used, does any process started by the
control build survive into the experiment build, and does each variation reach
every process that does the experiment's work?

## Setup

- Minimal projects in `experiments/toolchain-servers/`, one per toolchain,
  written for this run: npm, pip (setuptools), RubyGems, Maven, Go, and .NET as
  a positive control. No dependencies.
- Build commands verbatim from their wrapper, `src/reprotest/reprotest.go`:
  - npm: `mkdir dest && HOME=<home> npm pack --pack-destination='./dest'`,
    artefact `dest/*.tgz`. Their home is replaced by ours.
  - pip: `pip3 wheel -w dist --no-deps .`, artefact `dist/*.whl`, with
    `SOURCE_DATE_EPOCH=1709311372` in front for every variation except time.
  - RubyGems: `gem build *.gemspec`, artefact `*.gem`, with the same
    `SOURCE_DATE_EPOCH` rule.
  - Maven: `mvn clean install`, artefact `target/*`.
  - Go: their wrapper has no Go case. We use `go build -o out/rb1min .`,
    artefact `out/*`, with `GOTOOLCHAIN=local`.
  - .NET: `dotnet build -c Release`, as our layer 1 runs, no shutdown.
- reprotest invoked as theirs, `reprotest --variations=<axis> <command>
  <artefact>` in the project folder, plus `-v` and `--store-dir`, which do not
  touch the build. Two axes per toolchain, `umask` and `time`; .NET, the
  positive control, only `umask`.
- `PATH` is set to `/usr/local/bin:/usr/bin` plus the pip, Maven and .NET
  folders, so no personal paths reach the logs.
- `experiments/sample-tree.py` samples every process below the run script four
  times a second and keeps following them after they are reparented: name,
  start time, umask, CPU time, `FAKETIME` in the environment, libfaketime
  mapped. `experiments/analyze-tree.py` splits the samples into control and
  experiment by the variation's marker and lists every process from the
  control build that is still alive in the experiment's window.
- Tool versions: npm 12.0.2 on node 26.9.0, pip 26.2.1 on Python 3.14.7 (see below),
  RubyGems 3.6.9 on Ruby 3.4.10, Maven 3.9.16 on OpenJDK 26.0.2.1, Go 1.27.1,
  .NET SDK 9.0.120. Maven was downloaded for this run from Apache.
- `go`, `compile` and `link` are statically linked `[V]` `file`. node, ruby and
  python3 are dynamically linked.
- reprotest points `HOME` into the build directory. The user-installed pip
  26.0.1 then cannot find its own files, and the system pip 26.2.1 runs
  instead `[V]` `pip3 --version` with a changed `HOME`. Java ignores `$HOME`:
  `user.home` stays `/home/leos` `[V]` `java -XshowSettings:properties`, so
  Maven uses `/home/leos/.m2` in both builds, warm after the first.

## Expectation, written before the runs

1. **No survivors outside .NET.** For npm, pip, RubyGems, Maven and Go, no
   process of the control build is alive during the experiment build, and
   every process of the experiment carries the variation. None of these
   commands starts a server by default `[I]`. For .NET, the control's compiler
   server does the experiment's compiling, as in phoenix-layer2-reprotest
   run 0.
2. **`+time` does not reach Go.** node, python, ruby and java load libfaketime.
   Go's processes get `FAKETIME` in their environment but never load the
   library, because a statically linked program ignores `LD_PRELOAD`. So for
   Go, reprotest's time variation does not change the clock the toolchain sees
   `[I]`.
3. **Maven's cache is shared.** Java takes `user.home` from the password
   database rather than `$HOME`, so both Maven builds use `/home/leos/.m2`,
   and `install` writes into it, outside the build tree `[I]`. Weakly held.
4. Verdicts, weakly held and not the point: Maven red on both axes, from the
   times stored in the jar; pip red on both, from zip times and modes; gem red
   on `time`; npm, Go and .NET green.

## Commands

`experiments/toolchain-servers/run.sh <toolchain> <axis>`, eleven runs in a row
at 13:34-13:37. The command each run passed to reprotest is in
`rt-<toolchain>-<axis>.cmd`; `kommando.txt` has the sequence.

## Result

| Toolchain | Axis | reprotest | Survivor from the control build | libfaketime in the experiment |
| --- | --- | --- | --- | --- |
| .NET (control) | umask | successful | **`VBCSCompiler`**, umask 0022, still alive at the end | |
| npm | umask | successful | none | |
| npm | time | successful | none | npm: yes |
| pip | umask | differences | none | |
| pip | time | **build failed** | none | pip3, python: yes |
| RubyGems | umask | successful | none | |
| RubyGems | time | successful | none | gem: yes |
| Go | umask | successful | none | |
| Go | time | successful | none | **go, compile: no** |
| Maven | umask | differences | none | |
| Maven | time | differences | none | java: yes |

`[V]` samples and logs in the data folder, `experiments/analyze-tree.py`.

- **.NET, the positive control.** The sampler finds the compiler server: a
  `dotnet` process started in the control build at 13:34:37, umask 0022,
  working in the experiment's window and alive after reprotest exits. Its
  command line is `VBCSCompiler.dll` `[V]` `ps`.
- **No survivors elsewhere.** For npm, pip, RubyGems, Go and Maven, nothing
  from the control build is alive in the experiment's window, and nothing is
  left when reprotest ends.
- **Go never loads libfaketime.** Under `+time`, all five of Go's sampled
  processes, `go` and four `compile`, have `FAKETIME` in their environment and
  no libfaketime mapped. The processes of the four dynamically linked
  toolchains have it.
- **pip `+time` failed in the experiment build.** With the clock 398 days ahead,
  pip could not fetch setuptools: "certificate has expired" from PyPI's TLS
  certificate `[V]` log. reprotest ended with exit 125. This is the failure
  Benedetti et al. report in their threats to validity; they narrowed the
  time range.
- **The red verdicts are archive metadata.** pip's wheel stores `-rw-rw-r--`
  instead of `-rw-r--r--` under umask 0002. Maven's jar stores the modes too
  (`drwxrwxr-x`, `-rw-rw-r--`), and entry times: under `+time`, `MANIFEST.MF`
  carries the shifted date, 28 October 2027.
- **Maven's `install` writes outside the build tree.** Both builds used
  `/home/leos/.m2`, and the experiment's jar landed in
  `~/.m2/repository/rb1/rb1min/1.0.0/` at 13:37:39 `[V]` `ls`.

Per expectation:

1. Held. Only .NET leaves a process behind.
2. Held. `+time` sets `FAKETIME` for Go but does not change its clock.
3. Held.
4. Held for Maven, pip `+umask`, npm, Go and .NET. pip `+time` did not build.
   RubyGems was green on `+time` too, against the expectation; not examined.

## Interpretation

**Benedetti et al.'s toolchains do not have our .NET problem.** None of the
five commands their wrapper uses leaves a process that reprotest's second build
could reuse. Their setup ran both builds as the same user on one machine, so a
server would have been shared. There was none to share. Their verdicts are not
false greens for that reason.

**But `+time` does not reach Go.** reprotest shifts the clock by preloading
libfaketime, and Go's toolchain is statically linked, so it never loads it. Go
reads the real clock in both builds. A green Go verdict on `+time` says nothing
about time. Their published wrapper has no Go case, so whether the paper's Go
numbers include a time variation is not established here. The general point is
the same as with .NET's server: a variation counts only if it reaches the
process that writes the bytes, and reprotest does not check that.

**Network in the build is a variation reprotest does not intend.** pip's
isolated builds fetch their build backend from PyPI during the build, and a
shifted clock breaks the TLS check. A build that needs the network is exposed
to what the network serves that day.

## Caveats and not tested

- Minimal projects, not their sampled packages. A real package can start
  other processes: a test server, a Gradle wrapper, a Kotlin compiler.
- Cargo is not tested: Rust is not installed on `arch`.
- The sampler looks four times a second. A process shorter than that can be
  missed, but a survivor, by definition, lives through both builds.
- Newer tool versions than theirs: npm 12, pip 26, RubyGems 3.6.9, Maven
  3.9.16, Java 26. RubyGems' green on `+time` may come from such a change;
  not examined.
