# A rebuild record in the release: build-manifest.json, and a dry run (24 November 2026)

Grounds: a change to the WS branch `thesis/reproducible-builds`, a dry
run of its release workflow on GitHub, and a rebuild of the same commit
on `arch`. Leo approved adding the record to `v0.0.0-thesis.7` that
morning ("Jeg synes helt klart, det er noget, vi skal have med"). Run by
Claude in a side session of the writing session. The design is "stage 0"
of section 5 in Leo's working note on build records
(`notes/2026-11-24-build-info-research.md` in his own repository, not
shared). This note records what was built and measured.

## Question

RQ1 ends with six steps a verifier must take that the release does not
record:

- (a) the SDK build;
- (b) the version string;
- (c) the publish commands;
- (d) the whole tree;
- (e) the Windows signatures;
- (f) the images' platform manifests.

Can the release carry a record of its inputs and outputs that:

- (1) the release workflow writes without changing any existing output;
- (2) a rebuild regenerates byte for byte, so that one `cmp` gives the
  verdict for the whole release?

## Setup

- **The change**, on the WS branch:
  - `scripts/release/build-manifest.py`, Python standard library only. It
    writes `build-manifest.json`, an in-toto Statement v1:
    - its subjects are every release file, and each image's
      `linux/amd64` manifest, by digest;
    - the predicate holds an SLSA `buildDefinition`: the source, the
      values a rebuild sets (`APP_VERSION`, `SOURCE_DATE_EPOCH`), which
      job made which output, and the SDK, Node, npm, BuildKit and SBOM
      scanner pins, read with `git show` from their files at the commit;
    - nothing from the run: no run ID, times, runner or actor.
  - `03-release.yml`:
    - the BuildKit and scanner pins move to the top-level `env`, with
      the same values;
    - the `release` job reads each image's index and writes the
      manifest after the `SHA256SUMS` check and before "Create Release",
      and publishes it as an asset;
    - the release notes get a paragraph on how to rebuild;
    - `SHA256SUMS` is unchanged.
  - `docs/release/build-manifest.md`: the predicate type.
  - Main CI: a job that runs `scripts/release/test_build_manifest.py` on
    a fake release.
  - `.gitignore`: the two new folders are source, not the `[Rr]elease/`
    build output.
- **The dry run on GitHub.** The October dry runs were started by a tag.
  This one could not have a tag, so a temporary commit added copies of
  `03-release.yml` and `00-reusable-windows-publish.yml`. Pushed to the
  branch, they run once, with the version fixed to `v0.0.0-dryrun.1`. As
  in October:
  - no tests, no `windows-smoke`, no GitHub Release, no registry login or
    push;
  - GitHub-hosted runners only;
  - the images as OCI tarballs uploaded as artifacts;
  - the Windows binaries signed with a throwaway CA and certificate made
    in the job.

  The release job writes `build-manifest.json` with the release's own
  step, from the images' OCI tarballs in place of their GHCR indexes, and
  uploads it with the release's files. The edit script quotes WS's
  workflows, so it stays in private data (`dryrun-edit-3.py`). A next
  commit removes the copies.
- **The rebuild on `arch`.** The same commit, through
  `rebuild-merge.sh`, D5's copy of the experiment repo's `rebuild.sh`
  for the merge. It runs alongside the run, in tmux `lab`, under the
  memory guard. Caches as D5 left them, since the question is equal
  outputs, not empty caches. The signing image is built from the
  commit's `deployment/signing`.
- **The comparison:**
  - `compare.sh` with `SIGNED=test`: every output, the Windows files after
    pasting the run's signatures;
  - then `build-manifest.py` from the commit, run on what `compare.sh`
    assembles: the rebuilt files, the pasted Windows files, `upgrade.sh`,
    a new `SHA256SUMS`, and the local images' OCI files;
  - its output against the run's `build-manifest.json`, with `cmp`.

## Expectation, written before the results

Written at 10:57. By then the run's first jobs and the rebuild had
started, and nothing had finished.

1. Every job of the dry run passes, the new steps in the `release` job
   among them. `[I]` The generator passed its tests on macOS (Python
   3.9). It picked GHCR's `linux/amd64` manifests (`e097c1aa…`,
   `7cd72eec…`) from thesis.6's real indexes.
2. Every output of the run equals the rebuild on `arch`, byte for byte:
   - the frontend export, all four zips (Windows after pasting), both
     migrators, the SQL script and `SHA256SUMS`;
   - all five images, by `linux/amd64` manifest.

   `[I]` As for D5 and for the thesis.6 rebuild. The change touches no
   build step.
3. The regenerated `build-manifest.json` is byte for byte the run's.
   `[I]` It follows from 2, if the generator is deterministic and reads
   nothing from the run.
4. The manifest has 14 subjects (nine files, five images) and five
   pinned inputs. `SHA256SUMS` keeps its eight lines and does not list
   the manifest.

## Part 2: stages 1 and 2

Leo widened the scope at about 11:00 ("Ja, alle tre"): stages 1 and 2 also
go in before thesis.7.

- **Stage 1.** Each release job's build commands move into
  `scripts/release/<job>.sh`, which the workflow runs, and a verifier runs
  them too:
  - `frontend-build.sh` (install, build);
  - `publish-linux.sh`;
  - `publish-windows.sh` (build, then pack after signing);
  - `migration-bundles.sh`;
  - `checksums.sh`;
  - `docker-images.sh` (push, or OCI files).

  `scripts/release/rebuild.sh <tag>` is the one-command verifier:
  1. it downloads the release and reads the manifest;
  2. it takes the manifest's commit (and refuses if the tag points
     elsewhere);
  3. it installs the SDK, Node and npm by hash, and checks them against
     the manifest;
  4. it runs the job scripts in fresh clones under `env -i`, with the
     manifest's `APP_VERSION` and `SOURCE_DATE_EPOCH`;
  5. it pastes the published Windows signatures;
  6. it builds the images on the pinned BuildKit;
  7. it regenerates the manifest and ends with `cmp`.

  The reusable frontend workflow calls the script for the same two
  commands it ran before, so Main CI is unchanged.
- **Stage 2.** The images are built without attestations
  (`--provenance=false --sbom=false`), so each is one `linux/amd64`
  manifest. The version tag is made with
  `imagetools create --prefer-index=false`, so it names the manifest
  itself, and the release job checks that the tag's digest is the
  manifest's.
  - Each image's SBOM comes from a second, cached build with the pinned
    scanner. It is a release asset (`<image>-<tag>.spdx.json`) and a
    subject of the manifest.
  - The scanner's clock and random namespace are set to the commit's time
    and the asset's URL. A test before this (`62-sbom-twice`) found them
    the only fields that differ between two `--no-cache` scans, for the
    chat server and the MCP server.
  - No provenance is made, so the GitHub event payload, with names and
    e-mail addresses, no longer goes onto the images.
  - The gha cache is dropped: the script builds with plain `docker buildx`
    in a `run:` step, which has no access to the cache's token.
- **The checks:**
  - dry run 2 of the release (a copy as before, with the images written as
    OCI files);
  - `rebuild.sh` on `arch` against dry run 2's outputs, twice, in two work
    folders;
  - the two rebuilds against each other;
  - a throwaway registry on `arch` for the tag test, since the dry run
    pushes nothing;
  - Main CI dispatched on the branch's final commit.

### Expectation for part 2, written before its results

Written at 11:34. By then the stage-0 dry run had passed. Dry run 2 had
just started, after a first push failed on an invalid workflow file (two
`env` keys in one step, fixed in `9192fd4db`). Nothing of part 2 had a
result.

5. Every job of dry run 2 passes.
6. `rebuild.sh` on `arch` ends with `SAME` against dry run 2's manifest,
   both times: 19 subjects (nine files, five SBOMs, five images).
7. The two rebuilds are identical: every release file, every image
   manifest and every SBOM.
8. On the throwaway registry, each image pushed by `docker-images.sh` is
   one image manifest. After `imagetools create --prefer-index=false` its
   tag's digest is that manifest's. Without the flag the tag would name
   an index around it. `[I]`, from buildx's documentation.
9. The pushed manifests equal the OCI files of the rebuild: the push and
   the OCI output give the same manifest.

### Stage 2 taken out again, 11:40

At about 11:38 the writing session relayed that stage 2 must wait for a
design. Leo had added the images' provenance and SBOM himself, and wants
their place decided from practice, for example OCI referrers or cosign
attestations, before the provenance is dropped. By then stage 2 was
already on the branch (`ab0815a50`), and dry run 2 was testing it. Dry
run 2 was cancelled.

`7bfc359d0` restores the images job and the release job's image steps to
what they were with the manifest alone (`6e10bdcab`): `build-push-action`
with provenance and SBOM, and tags by `imagetools create`. The generator
and its test go back too. `docker-images.sh` stays, for the verifier
only: OCI files, with the workflow's Dockerfiles, contexts and arguments,
without attestations, which do not change the `linux/amd64` manifest a
rebuild compares. Dry run 3 tests stages 0 and 1 (`1d7b50188`).

Expectations 6-9 above are replaced by these, written at 11:46, before
dry run 3 or the verifier had any result:

5'. Every job of dry run 3 passes.
6'. `rebuild.sh` on `arch` ends with `SAME` against dry run 3's manifest,
   both times: 14 subjects.
7'. The two rebuilds are identical: every release file and every image
   manifest.

The SBOM test (`62-sbom-twice`) stays as a finding for stage 2's design:
two scans differ only in `creationInfo.created` and `documentNamespace`.

## Commands

Verbatim in `data/2026-11-24-phoenix-build-manifest/<machine>/kommando.txt`.

### Stage 2 back, 12:00

At about 12:00 Leo chose stage 2 for thesis.7 ("Jeg tænker bare, at vi skal
have trin 2 med os"), as the image design note recommends.

- `924bb1d63` reverts the take-out.
- `956b361aa` adds four things:
  - each image's BuildKit provenance as a file,
    `<image>-<tag>.provenance.json`, from buildx's metadata file. buildx
    0.38.0 still writes it with `--provenance=false` (lab step 66).
  - Those files are release assets, but outside `build-manifest.json`'s
    subjects and outside `SHA256SUMS`.
  - `provenance-add-gha=false` on the builder.
  - The generator skips the SBOM and provenance files that sit beside the
    OCI files. The research session found that `rebuild.sh` would
    otherwise have read an SBOM as an image.

  Dry run 4 tested this.
- Then the verifier on `arch` found three faults of its own. Each was
  fixed in turn:
  - `84fd09390`: the SDK installer read `global.json` from the current
    folder.
  - `d615bb7a6`: `zip` is not in `/usr/bin` on `arch`.
  - `0ce1a3c06`: the paste compared file modes from NuGet's extraction
    (744) with the zips' (755), though packing sets every mode anyway.
- It also found one real difference, `0e497595d` (Result, 7). Dry run 5
  tests the lot.

## Result

`[V]` throughout, from the runs and lab logs in
`data/2026-11-24-phoenix-build-manifest/`.

1. **Stage 0, dry run 1**
   ([run 45369603779](https://github.com/Weel-Sandvig/WS.Phoenix/actions/runs/45369603779)):
   all seven jobs passed, the release job's manifest step among them.
2. **Rebuild of dry run 1 on `arch`** (the experiment repo's `rebuild.sh`
   adapted for the merge): identical to the run in every output.
   - The export: 1034 files.
   - All four zips: the Windows ones after pasting, 2180 files and 115
     folders.
   - Both migrators, the SQL and `SHA256SUMS`: 8 lines, which do not
     name the manifest.
   - The five image manifests.

   The manifest regenerated from the rebuilt files is the run's, byte for
   byte: `31645a1a…`, 14 subjects, 5 pinned inputs. Expectations 1-4 held.
3. **Stages 0 and 1, dry run 3**
   ([run 45376256394](https://github.com/Weel-Sandvig/WS.Phoenix/actions/runs/45376256394)):
   all seven jobs passed with the job scripts. Dry run 2 was cancelled
   minutes in, when stage 2 was first stopped.
4. **Stages 0-2, dry run 4**
   ([run 45377928508](https://github.com/Weel-Sandvig/WS.Phoenix/actions/runs/45377928508)):
   all seven jobs passed.
   - The manifest has 19 subjects: 9 files, 5 SBOMs and 5 images. No
     provenance file is among them.
   - Each SBOM artifact's SHA-256 equals its subject.
   - The five provenance files (79-140 kB, SLSA v0.2) hold no `github_`
     key, no e-mail address and no actor, login or author field, and
     `builder.id` is empty.
   - They do hold the build's start and finish times, BuildKit's
     invocation ID, the commit and the repository URL.
5. **SBOMs** (lab steps 62 and 63, the chat server and the MCP server):
   two `--no-cache` scans with the pinned scanner differ only in
   `creationInfo.created` and `documentNamespace`. With those set as
   `docker-images.sh` sets them, both pairs are byte-identical.
6. **Main CI on the branch:**
   - failed on `a1750acfd` and `84fd09390`;
   - passed on `d615bb7a6`
     ([run 45389396091](https://github.com/Weel-Sandvig/WS.Phoenix/actions/runs/45389396091)).

   The failures were each the one timing test
   `EntityFrameworkPerformanceTests.BatchQuery_VsIndividualQueries`
   (batch measured 1.27× and 1.65× faster, at least 2× required). The
   other 965 integration and 6449 unit tests passed. The test has not
   failed in Main CI on `main` recently. The new job,
   `test-release-manifest`, passed every time.
7. **`rebuild.sh` against dry run 4 on `arch`** (`64e`, after the three
   fixes to the verifier):
   - Up to the paste, everything matched. The rebuilt Linux zip of the
     WebAPI is the run's (`7ac6f6df…`).
   - The paste put on 184 signatures with none failed.
   - One file differed: the WebAPI's Windows `web.config`, release
     `9cc15fff…`, rebuild `d4807256…`, the same in both work folders. The
     release's has one more last line,
     `<!--ProjectGuid: 10FDF702-C229-4E81-AC60-73EA4A9139AB-->`, the
     WebAPI's GUID in `src/WebAPI/WebAPI.sln`.
   - The cause, by three publishes on `arch` (lab steps 67 and 68): the
     line is there with `GITHUB_ACTIONS=true`, and there without it. It is
     gone with `DOTNET_CLI_TELEMETRY_OPTOUT=1`, which `rebuild.sh` set and
     the release's runners do not.
8. **Dry run 5**
   ([run 45403522195](https://github.com/Weel-Sandvig/WS.Phoenix/actions/runs/45403522195),
   commit `8491a0d63`, with the telemetry fix): all seven jobs passed.
   - The WebAPI's Windows `web.config` ends at `</configuration>`, with no
     ProjectGuid line.
   - The manifest has 19 subjects: 9 files, 5 SBOMs and 5 images, with no
     provenance file. The SBOMs and both Windows zips match their
     subjects.
   - The five provenance files hold no `github_` key, no e-mail address
     and no actor, login or author field.

   The verify-twice against it waits until `arch` is back on the office
   network.
9. **The branch's final tip:** `c9e9022d0`, after dry run 5's workflows
   were removed. Its tree has no `zz-*` file. Main CI on it:
   [run 45407527249](https://github.com/Weel-Sandvig/WS.Phoenix/actions/runs/45407527249).

## Interpretation

**A new cause: the .NET CLI's telemetry setting changes an output.** `[V]`

- The WebAPI's Windows `web.config` ends with
  `<!--ProjectGuid: 10FDF702-C229-4E81-AC60-73EA4A9139AB-->` when the CLI's
  telemetry is on, and without that line when
  `DOTNET_CLI_TELEMETRY_OPTOUT=1`.
- The evidence: the same restore and win-x64 publish of the WebAPI on SDK
  10.0.401, on `arch`, three times. The line was there with
  `GITHUB_ACTIONS=true` and there without it (lab step 67). It was gone
  with the opt-out (lab step 68).
- The GUID is the WebAPI's in `src/WebAPI/WebAPI.sln`, a solution file
  beside the project, not the root `WS.Phoenix.sln` the restore uses.
  The Publish SDK's web.config transform writes `$(ProjectGuid)` whenever
  it is set, and no SDK targets or props file sets it, so it reaches
  MSBuild from the CLI. `[I]` That the CLI reads the GUID for its
  telemetry is inferred from the effect; the CLI's code was not read.
- GitHub's runners and WS's office runners leave telemetry on. A
  verifier who turns it off, as `rebuild.sh` did, as many CI templates
  do, and as the WS Dockerfiles do, gets a different `web.config` and a
  different Windows zip.

In the codebook's terms it is an environment cause: a setting of the
building machine, read by a tool, written into an output. It is unlike
the earlier ones in one way. The setting has nothing to do with building:
it is a privacy setting of the CLI. The earlier rebuilds matched only
because every builder happened to leave it on (thesis.6 on `arch` and on
the Mac, and the dry run 1 rebuild through the experiment repo's
`rebuild.sh`).

The fix, `0e497595d`, sets the opt-out in the three .NET job scripts, so
the release and every rebuild build alike. The Windows `web.config` of
thesis.7 therefore has no GUID line. That is a change from thesis.6's,
made before thesis.7 exists.

**What else the verifier taught.** `[V]` Its first real runs failed three
times on the verifier's own environment before reaching any output: the
working folder, a missing `zip`, and file modes from NuGet's extraction.
Each is a step a person rebuilding by hand would have to find too. The
script now encodes them: it checks its tools, passes `zip` on, and gives
the Windows tree the modes packing gives it.

## Caveats

- The `*.log.gz` build logs are not in this public repository (they hold WS source paths and names); they are kept privately with Leo.
- The dry runs had no tag and no secrets. They signed with a throwaway CA,
  skipped `windows-smoke`, and pushed no images. Those parts were first
  run by the real `v0.0.0-thesis.7` release
  ([phoenix-thesis7-release](2026-11-24-phoenix-thesis7-release.md)).
- The manifest is not signed. It says what to rebuild and compare, not
  who built the release.
- "Nothing from the run" holds for the fields the generator writes. The
  provenance files, which do hold the run's times and IDs, are kept out
  of the subjects. From thesis.8 they are out of the release too
  ([phoenix-sbom-zip](2026-11-24-phoenix-sbom-zip.md)).
- The verifier's two fixes found this afternoon (`--global-json`, the
  modes before the paste) and the telemetry finding came from running it.
  An earlier review of the script alone missed them.

## Not tested

- The verifier as tagged, unpatched, on any host but Linux x86-64. On the
  Mac Studio it ran with two local patches (see the thesis.7 note).
- A verifier outside WS: the source and the releases are private.
