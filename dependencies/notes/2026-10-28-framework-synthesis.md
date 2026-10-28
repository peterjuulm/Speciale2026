# The nupkg experiment in one frame: question, layers, findings, gaps

Written 28 October 2026, 08:05 to 08:45, for the working session with
Peter the same day. Basis: every note under `dependencies/notes/` from
21 to 28 October, the four `results.tsv` of the repository-build method,
the Windows runner run of this morning (its own note:
[2026-10-28-nupkg-repository-build-windows.md](2026-10-28-nupkg-repository-build-windows.md)),
and two independent reads of the same material by other agents whose
points were checked against the files before they were taken in. This
note proposes; nothing in it is decided.

## 1. The one question

> Given a shipped binary and the source commit it names, what else does
> a third party need to know to produce the same bytes, and does any
> record of the release name it?

Everything that was run in the past week is one attempt at answering
that question for one real product's dependency closure. The standards
in the domain (EN 17255, EN 14181, CEN/TS 17198) say "same source, same
build" and stop there. The experiment turns the unnamed remainder into a
list, with a measured size for each entry.

## 2. Three layers, no special cases

Every batch, method version, host and result lands in one of three
layers. The layers are the structure for the thesis chapter.

**Layer A, the observation.** One package-version pair, the one DLL of it
that Phoenix ships, rebuilt once from the declared commit and compared
with the DLL on nuget.org. The outcome is one of: *not derivable* (a rule
could not name the inputs), *did not build*, *built but no package*, or a
level 1 to 4. The levels stay as they are, but get names:

| level | name | what differs |
|---|---|---|
| 1 | identical | nothing |
| 2 | signed only | the Authenticode block, the strong-name slot, and what they move (checksum, size, hash) |
| 3 | same code | only the build identity: MVID, timestamp, PDB id and checksum |
| 4 | different code | something in IL, metadata tables, strings, blobs or resources; the note says which |

For a headline the four collapse to three: reproduced (1 and 2), same
code (3), differs (4). Level 2 is the practical ceiling for a signed
vendor ecosystem: the signature needs the vendor's key, nothing else.

**Layer B, what the rebuilder was allowed to read.** This is the axis the
two "methods" and the versions sit on. It is a ladder, and each step up
reads one more thing the publisher knew:

| rung | reads | our name until today |
|---|---|---|
| R | the release: nuspec, the DLL's attributes and PDB, Source Link, the source tree at the commit | release-only method |
| R+S | plus the repository's own build script at the commit | repository-build method, version 1 |
| R+S+P | plus the official pipeline definition (subset names, switches, which properties the official job passes) | repository-build versions 3 and 5 |
| R+S+P+H | plus the official host (Windows) | the Windows run |

Every version of either method is a rung, or a rule within a rung. The
"detours" of the week are this ladder being climbed one rung at a time,
each time because the rung below left a difference that only the next
rung could explain. Written this way the week reads as one procedure.

**Layer C, the input catalogue.** Every residual difference, and every
failure to build, is attributed to one named input. This layer is the
contribution: the list of inputs that "same source, same build" does not
name, with the bytes each one moved.

## 3. The input catalogue as it stands tonight

Each entry: what it is, what it did to the bytes, where it is read
(`[V]` in the notes), and whether any release record names it.

1. **The version string.** The dominant level-4 cause under rung R, in
   both third-party and Microsoft packages: assembly-info written by a
   script, MinVer, a date suffix, Arcade's dev-build `42.42.42.42424`,
   a clock in the version (IdentityModel), the build-year copyright, and
   today Roslyn's informational version that the official build leaves
   prerelease while the package is repacked to 5.0.0 (confirmed by
   version 5: without the stabilising properties the eight packages are
   level 2). Named nowhere; the
   version is a self-declared string. This is the entry that speaks
   directly to EN 17255's version requirement.
2. **The checkout's text conversion.** `core.autocrlf` on the official
   agent turns LF sources into CRLF; the compiler embeds some of them
   (multi-line descriptions, Razor literals, an embedded script). Named
   nowhere; read from the shipped bytes.
3. **The build host's OS.** Two effects, both read in the bytes and both
   closed by the Windows run: build-generated files get the platform
   newline (46 rows, one cause, down to the `FieldRVA` addresses the
   longer resource shifts), and MSBuild's glob hands the compiler the
   source files in the OS's walk order (9 rows: Roslyn, EFCore). Named
   nowhere. A third effect sits under it: on Linux the build identity
   (MVID, PDB id) never matched, on Windows it did, for the same code.
4. **Companion toolchains the repository build pulls in by itself.**
   Node (aspnetcore 8.0 wants Node 18), the Razor compiler (the VMR builds
   with its own, standalone with the pinned one: Identity.UI), clang
   (clang 23 rejects runtime shims below 9.0.11). Named only in the
   repository's own pins, never in the release.
5. **Orchestration above the repository.** The VMR passes the inner
   repository two identity properties it cannot know (18 rows moved from
   4 to 3 when passed). The release names the VMR commit, not what the
   VMR passed.
6. **The set of source roots.** One path-map index (`/_3/` against `/_1/`)
   in Build.Framework on Linux; gone on Windows. Named nowhere.
7. **Inputs the public cannot obtain.** Compilers from internal SDK
   builds (25 packages under rung R), internal feeds, Arcade tool
   packages that left the feeds (symreader, Razor 6.0.24), the signing
   keys, optimization data. These are the hard floor of third-party
   verification, and a finding in themselves.
8. **The runtime under the compiler.** The compiler records the version
   of the runtime it ran on in the PDB's compiler record, and the PDB
   feeds the identity hash. Where the repository pins its SDK the value
   is fixed; where the build uses the desktop engine (msbuild) it is the
   host's .NET Framework patch level (4.8.9315 on the official agent,
   4.8.9363 on the runner: Microsoft.Build 17.11.48, read 08:10). Named
   nowhere.
9. **Nondeterminism proper.** Only the IdentityModel clock. Everything
   else in the catalogue is an uncontrolled input, in Lamb and
   Zacchiroli's sense, not randomness.

## 4. What the week's numbers say, by rung

| rung | packages tried | 1 | 2 | 3 | 4 | no package or did not build | not derivable |
|---|---|---|---|---|---|---|---|
| R, third-party (batch 2, version 3) | 59 | 14 | 3 | 9 | 16 | 12 | 5 |
| R, Microsoft (batch 3, version 3) | 139 | 0 | 5 | 0 | 39 | 59 | 36 |
| R+S and R+S+P, Linux (repository build, best of versions 1 to 4) | 96 | 0 | 0 | 35 | 57 | 4 | 0 |
| R+S+P+H, windows-2022 (standalone repositories, best of versions 3 and 5) | 42 | 0 | 35 | 4 | 0 | 3 | 0 |
| best rung per package (the 198 tried) | 198 | 14 | 43 | 38 | 68 | 22 | 13 |

`[V]` computed 28 October 09:40 (final) from the five `results.tsv` (release-only
batch 2 v3 and batch 3; repository-build v1 to v4; Windows), keyed by
package and version. The census (`2026-10-13-dependency-census/mac/census.csv`)
has 341 package-versions; 198 entered a batch (59 third-party,
139 Microsoft) and 143 did not, by the census's own classes: 29 ship no
files (meta or build-time packages), 8 native code only, 9 name no
repository, 13 a repository but no commit, 45 no PDB at all, 36 a PDB
that is neither in the package nor was found, 2 a PDB without a
compiler record, 1 runtime pack (`census.md`, classes N0 to C2c). Those
are the first finding of the chapter: for 143 of 341 the release names
nothing a rebuild could start from. The "best rung" row counts each package once at its best level;
of the 57 reproduced (level 1 or 2), 22 were reproduced
at rung R and 35 only on the official host; the
earlier "75 of 139", "62/56/54" and "33/34" figures in the notes should
be replaced by this table's numbers.

Read down the table: the same packages move from "differs" to "same
code" to "reproduced" as the rebuilder is allowed to read more of what
the publisher knew. That is the red thread in one table.

## 5. What the Windows run settled this morning

- The Linux level-3 rows were a host effect: the same recipes on
  windows-2022 give identical MVID, timestamp and PDB identity. The
  plan's prediction of 07:40 (that they would stay at 3) was wrong and
  is recorded as such in the Windows note.
- All resource rows (reading 2) and the glob-order rows (reading 3)
  closed as predicted: Roslyn's IL and table order match on Windows.
- Roslyn's one remaining difference named a new catalogue entry (the
  repack route of the version string); version 5 tested it at 07:47 and
  all eight packages reached level 2, whole-file equal without the
  signatures, packed under the prerelease version the official build
  also produced before repacking.
- Four packages stay at level 3 on Windows (Microsoft.Build 17.11.48,
  CodeDom 6.0.0, IO.Hashing 7.0.0, IO.Ports 5.0.0). Microsoft.Build's
  PDB was read at 08:10: one field, the runtime under the compiler
  (entry 8 above). The other three ship no PDB; not read.

## 6. What to present, and where

Main text, one section each: the question and the ladder (sections 1
and 2 here); the catalogue (section 3) with one paragraph per entry and
the bytes it moved; the table of section 4; the host comparison as a
controlled one-factor experiment (same recipes, Linux against Windows,
per package); repeatability (A equals A2 everywhere except the clock)
in one paragraph; the floor of unobtainable inputs as the limit of what
a third party can ever verify.

Appendix or tables: the rules of both rungs in full; the OfficialBuildId
decoding; the level classifier and its one correction; the script
faults; the toolchain findings (clang, Node, OpenSSL 1.1, NETSDK1188,
Arcade's `--ci` exit code); mirrors, disk guards, long paths; the
`FieldRVA` and source-root mechanics.

## 7. Threats and honest caveats to write down

- **Injected attributes.** OfficialBuildId, RepositoryUrl, the VMR commit
  and the assembly version are read from the shipped DLL and passed in.
  A match on those fields proves nothing; the evidence is IL, tables and
  resources, and the text must say so.
- **No held-out set.** Rules were refined on the same packages they were
  then measured on. Each version is written before its run and earlier
  rows are kept, which makes the iteration auditable, not blind. Say it.
- **Case study, not a sample.** The population is one product's
  dependency closure; Benedetti's random samples generalise, ours
  describes.
- **Counts to reconcile before writing.** The VMR package count appears
  as 62, 56 and 54 across notes; the plan says "75 of 139 did not
  build" where the batch note gives 55 plus 36 skipped; the runtime
  packs are in the 99 denominator although rule R8 puts them out of
  scope. One denominator figure (census, declared, derived, built,
  level) fixes all of these.
- **The CI files became an input.** The plan said pipeline definitions
  are cited, not executed; versions 3 and 5 take their switches from
  them. That is rung P, and it should be named as a rung rather than
  denied.
- **Glob order within Linux.** The Windows run shows the shipped order is
  the Windows walk; whether the Linux walk is stable across filesystems
  was not tested (reprotest's `fileordering` axis).

## 8. Against the neighbours

Benedetti et al. keep one default build command per ecosystem, one
outcome, cumulative intervention categories (as is, with configuration,
with patched tooling, external causes) and one figure per research
question. The ladder of section 2 is their cumulative categories with
the categories named by what is read, and the table of section 4 is
their one figure. They explicitly do not compare against the uploaded
artifact, because the commit is hard to identify and environment
differences are orthogonal to their question; in .NET the nuspec commit
and Source Link remove the first reason, and the second reason is our
object of study. That paragraph is the positioning.

Lamb and Zacchiroli's reader expects, up front: their definition (same
source and designated build dependencies give bit-identical output
"regardless of the environment"); what artifact, source, build
dependencies and environment mean here; that levels 2 and 3 are not
reproducible in their sense; and that nearly everything found is an
uncontrolled input, not nondeterminism. Their `.buildinfo` is the record
NuGet lacks, and rung R is a reconstruction of an implicit buildinfo
from forensic traces in the release.

## 9. Closed state, 28 October 2026 09:45

The experiment is closed. Every item that was open this morning has a
decision; none is carried forward as work.

| item | decision | reason |
|---|---|---|
| The 54 VMR packages on the official host | closed, Linux result stands (level 3 or 4, causes read) | a `dotnet/dotnet` build does not fit the free runners; a larger runner is a cost decision, not an experiment |
| Three level-3 rows without a shipped PDB (CodeDom 6.0.0, IO.Hashing 7.0.0, IO.Ports 5.0.0) | closed as level 3 | no symbols package on nuget.org; the mechanism is read on Microsoft.Build (the runtime under the compiler) and stated for all four |
| The three unread Identity.Web rows of batch 3 | closed as level 4, cause unread | release-only rung, outside the repository-build scope; the catalogue does not depend on them |
| reprotest beyond two runs, `fileordering` | closed, not run | variation is a different question (Benedetti's); repeatability was measured as A = A2 in the release-only batches |
| A2 build of an Arcade repository | closed, not run | the Windows run gives level 2 against the publisher, which subsumes repeat-against-self |
| Sorted-Compile build | closed, superseded | the Windows run reproduced the shipped type order |
| MSAL, IdentityModel, SqlClient rebuilds | closed, not derivable | .NET Framework compiler, commits not in the public repository, no compiler record |
| Runtime packs, SkiaSharp/HarfBuzz, packages with no declared source | closed, out of scope by rule | full product build, Apple workloads, nothing to start from (the count is the finding) |
| The hung runtime 9.0.0 job | closed | a one-off; the rerun built in 18 minutes with all eight packages at level 2 |
| Count reconciliation | closed | the table of section 4 is the one set of numbers; the earlier figures in the notes are superseded by it |
| Instrument validation (fixtures for exception handlers, static data) | closed, not needed | level 2 is now checked on the whole file (`stripsign.cs`); level 3 and 4 are read per row, not trusted from the report |

What remains is writing: the catalogue into the thesis, the clause-level
reading of the standards for the regulatory claim, and the figures from
the table of section 4.

## 10. The two second opinions, checked (08:05)

Two independent reads of the notes were asked the questions of sections
1 to 9 (one Claude agent, one Codex run). Their points, kept where they
held up against the files:

- **Level 2 rested on report fields, not on the file.** Codex read
  `level.py` and `dllreport.cs`: the report hashes IL and the streams,
  and level 2 was "the differing report lines are the signature lines".
  Fixed the same hour: `stripsign.cs` compares the whole file with the
  signatures removed, and all 19 Windows level-2 pairs hash equal
  (`signature-stripped.txt`). Level 2 now means what it says.
- **Level 3 is a symptom, not a class** (both): under deterministic
  compilation the identity is a hash of content that the report does not
  compare (the PDB above all). The Windows run showed it: the Linux
  level-3 rows closed. For the four rows still at 3, diff the PDBs.
- **The ladder, not two methods** (both, in different words): present
  release-only and repository-build as rungs of what the rebuilder may
  read; name rung P, because versions 3 and 5 took their switches from
  the official pipeline files although the plan said those are "cited,
  not executed".
- **Versions are protocol revisions, not Benedetti's variations** (both):
  a variation perturbs the environment with the protocol fixed; our
  versions changed the protocol. Report each package at the first rung
  where it reaches level 2, and keep refuted versions (version 4) in a
  protocol log.
- **No held-out set, and injected attributes** (Claude): rules were
  refined on the packages they were measured on; OfficialBuildId,
  RepositoryUrl, the VMR commit are read from the shipped DLL and passed
  in, so a match on those fields is not evidence. Both go into the
  threats section.
- **Counts to reconcile** (both): the VMR count (62, 56, 54), "75 of 139"
  against 55 plus 36, build 5 as 33 against 34, the runtime packs in the
  99 denominator. One manifest table fixes it.
- **Wording that overclaims** (both, verified in the files): "every VMR
  package came out at level 4" while the same sentence says efcore 1 of
  9; "no build log records" the source order (unsupported: say the
  publisher's ordered compiler inputs are unavailable); "the decoding
  is right" for the build id (the decoding admits two ids; the file
  version is consistent with one, not proof); "the public cannot obtain;
  no rule can fix that" for the internal compilers (say: not found by
  this search). To be edited in the Linux note.
- **The regulatory claim needs clause-level evidence** (Codex): that the
  standards do not name the build's inputs must be shown from the
  clauses (EN 17255-2 §6.5.1, §6.8.5, §6.7.2 and the others in the
  thesis repository's notes), not inferred from the experiment.
- **Positioning against Benedetti** (both): they exclude publisher
  matching and hold toolchain, dependencies and OS fixed; our question is
  the one their design sets aside. Do not copy their replacement of
  failed builds; a product's closure is a census, not a sample.
- **Not taken over:** Claude's suggestion to extend reprotest beyond two
  runs before writing (a separate question, Codex agrees); Codex's call
  for fixtures with exception-handler and static-data changes to
  validate the report (worth doing for the instrument appendix, not
  before the meeting).
