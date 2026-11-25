# One SBOM per shipped file, in one zip: the thesis.8 layout, dry runs 6 and 7 (24-25 November 2026)

Grounds: two commits on the WS branch `thesis/reproducible-builds` that
evening, a local trial on the Mac Studio, and a dry run of the release
workflow on GitHub. Leo decided the layout after `v0.0.0-thesis.7` shipped
20 files ("Ja det synes jeg. Men først efter thesis 7 er gennemkørt og
testet."), on a recommendation by the Fable supervisor (Leo's working note
`notes/2026-11-24-supervisor-release-assets.md` in his own repository, not
shared). Its rule: a file belongs in the release if it is installed, or if
`build-manifest.json` vouches for it. Run by Claude in a side session of
the writing session, after thesis.7's Mac rebuild was recorded
([phoenix-thesis7-release](2026-11-24-phoenix-thesis7-release.md)). No
tag.

This layout was tagged `v0.0.0-thesis.8` on 25 November (on `1c90ad428`, which adds the Mac
fixes to `rebuild.sh`). Its release run was cancelled and nothing was published; thesis.8 waits
until December: [phoenix-thesis8-release](2026-11-25-phoenix-thesis8-release.md).

## Question

1. Can each file the release ships (four zips, two single-file
   migrators) get its own SBOM, made by the scanner the images already
   use, so that two builds make the same SBOMs?
2. Does the scanner see into the single-file migrators?
3. With the SBOMs and the five image SBOMs in one deterministic zip, does
   the release workflow still write a `build-manifest.json` that names
   everything, now with 15 subjects instead of 19?

## Setup

- **`aafae131e`**: the images' build provenance leaves the release.
  - `03-release.yml`: no download into the release folder, no line in
    `files:`. The `image-provenance` artifact is kept 90 days (GitHub's
    maximum; it was 1).
  - `docs/release/build-manifest.md`: the paragraph on provenance says so.
  - The subjects and `SHA256SUMS` are unchanged.
- **`758cd3f06`**: the SBOM zip.
  - `scripts/release/sboms.sh RELEASE IMAGES OUT`, the new `sboms` job's
    script:
    - for each zip, its contents; for each migrator, the file alone;
    - copied into an empty image (`FROM scratch`, `COPY . /`) that BuildKit
      builds with `--sbom=generator=<SBOM_GENERATOR>`, on a builder of the
      pinned BuildKit;
    - the SPDX document taken out by `scripts/release/sbom-extract.py`
      (moved out of `docker-images.sh`, shared by both), with the
      scanner's clock set to the commit's time and its random UUID
      replaced by the document's place in the zip;
    - each named after its file plus `.spdx.json`;
    - with the five image SBOMs, packed by `scripts/pack-release-zip.sh`
      at `SOURCE_DATE_EPOCH` into `ws-pems-sbom-<tag>.zip`, one folder
      `ws-pems-sbom-<tag>/`.
  - The SQL and `upgrade.sh` get no SBOM: scripts, no components.
  - `build-manifest.py`: the zip is an asset of job `sboms`; a loose
    `.spdx.json` among the assets now fails as unknown (new test).
  - `rebuild.sh`: makes the zip from the rebuilt files with the tag's
    `sboms.sh` on its own builder. A tag without `sboms.sh` (thesis.7 and
    earlier) keeps the loose SBOMs.
  - The release job publishes `release/sbom/ws-pems-sbom-*.zip`, which
    `SHA256SUMS` does not list.
- **Dry run 6** (`dryrun-edit-8.py`, private: it quotes WS's workflows),
  as dry run 5, version `v0.0.0-dryrun.6`, plus a second copy of the
  `sboms` job (`sboms-again`) on another runner. The release job compares
  the two zips with `cmp` and fails if they differ.

## Expectation, written before the results

- The local trial (below) already ran when this was written, so for the
  dry run:
  - `sboms` and `sboms-again` green; the two zips identical.
  - `build-manifest.json`: 15 subjects (8 product files, `SHA256SUMS`,
    the SBOM zip, 5 images); no `.spdx.json` or `.provenance.json`
    subject.
  - The zip: 12 entries (the folder, 6 file SBOMs, 5 image SBOMs).
- Not certain: whether a GitHub runner's scan (linux/amd64 builder) lists
  the same packages as the Mac's native (linux/arm64) trial. It should not
  matter for reproducibility, which is runner against runner.

## The local trial (lab step 72)

`lab/72-mac-sboms-twice.sh`, 21:05-21:11 `[V]`:
- `sboms.sh` from `758cd3f06` on thesis.7's published files and image
  SBOMs, run twice on two fresh builders of the pinned BuildKit (native
  arm64);
- both zips `c2ecca68…`: identical;
- package counts (`data/2026-11-24-phoenix-thesis7-release/macstudio/72-*`):
  - Linux zips: WebAPI 220, job worker 144;
  - Windows zips: WebAPI 251, job worker 175;
  - migrators: Linux 145, Windows 144.

**The migrators.** The scanner sees into both single-file migrators. Each
SBOM lists 144 NuGet packages (EF Core, Npgsql and the rest) and the
runtime packs `runtimepack.Microsoft.NETCore.App.Runtime.linux-x64` and
`…AspNetCore.App.Runtime…` 10.0.12 `[V]`. `[I]` That suggests it reads the
bundle's embedded `deps.json`.

**The runtime.** It is named in every .NET SBOM `[V]`:
- the Linux zips: as runtime packs from `deps.json`;
- the Windows zips: also nine further ".NET Runtime …" components, read
  from the DLLs' version resources, with the file version (`10,0,1226,…`).

## Dry run 6

[Run 45486782488](https://github.com/Weel-Sandvig/WS.Phoenix/actions/runs/45486782488)
on `c6c622731` (`758cd3f06` plus the two temporary files), 22:16-22:35:
green in every job, `sboms` and `sboms-again` included `[V]`. Data in
`data/2026-11-24-phoenix-sbom-zip/github/`.

- The two runners' zips: both `68926ca8…`; the release job's `cmp` passed.
  Each of the 11 SPDX files has the same SHA-256 on both runners
  (`dryrun6-sboms-jobs.txt`) `[V]`.
- Package counts on the runners equal the Mac trial's for every file:
  144, 175, 220, 251, 145, 144 `[V]`.
- The zip: the folder and 11 SPDX files, 6 named after the shipped files
  and 5 after the images (`dryrun6-sbom-zip-listing.txt`) `[V]`.
- `build-manifest.json` (`27893be9…`): 15 subjects `[V]`:
  - the four zips;
  - both migrators;
  - the SQL;
  - `upgrade.sh`;
  - `SHA256SUMS`;
  - `ws-pems-sbom-v0.0.0-dryrun.6.zip`;
  - the five images.

  Job `sboms` names the zip.
- The release folder holds no `.spdx.json` and no `.provenance.json`
  `[V]`.
- The temporary files were removed in `48c5b3cba`, whose tree equals
  `758cd3f06`'s. Main CI on it, run 45493420324, failed: see dry run 7.

### The new rebuild.sh against dry run 6 (Mac Studio)

`lab/70-mac-verify.sh` with `RUN=45486782488 T=v0.0.0-dryrun.6
TIP=48c5b3cba PATCH=1`, 22:54-23:35: `rebuild.sh` from `48c5b3cba`, with
the two Mac patches, in the x86-64 container.

- Result: `DIFFERENT`. 14 of the 15 subjects equal the run's `[V]`:
  - the 8 files;
  - `SHA256SUMS`;
  - the 5 image manifests.

  Only the SBOM zip differs (`73df8614…`, run `68926ca8…`).
- Inside the zip, only the Linux migrator's SPDX differs, in one line:
  the `comment` with the scanned layer's ID `[V]`
  (`data/…/macstudio/70-dry6-linux-migrator-sbom.diff`).
- Cause `[V]`:
  - the layer holds the file's mode;
  - `rebuild.sh` took the migrator from the build, mode 0755;
  - the runner took it from an artifact download, 0644.

  The Windows migrator matched, because `rebuild.sh` already sets it to
  0644 for the paste. The zips matched, because their entries carry
  `pack-release-zip.sh`'s modes.
- **Fix, `37fef01d4`:** `sboms.sh` gives a single file mode 0644 before
  the scan, as the published migrators have.
- Lab step 73 (`lab/73-mac-sboms-dry6.sh`) remade the zip on the Mac from
  the same rebuilt files with the fixed script. Result: `68926ca8…`, with
  all 11 SPDX hashes equal to the runners' `[V]`. So with the fix, all 15
  subjects of dry run 6 reproduce on the Mac.
- Step 70b, 23:43-00:22: the whole `rebuild.sh` from `37fef01d4` against
  dry run 6 again. Result: `DIFFERENT`, with the same zip `73df8614…`
  `[V]`. This is as designed. `rebuild.sh` runs the job scripts of the
  commit it rebuilds (dry run 6's `c6c622731`, without the fix), not its
  own. A fix to a job script applies to releases built after it. So
  dry run 7 was run on the fixed commit (below).
- **Dry run 7, on the fixed commit** (`dryrun-edit-9.py`, as 8 with
  `v0.0.0-dryrun.7`):
  - [run 45509439098](https://github.com/Weel-Sandvig/WS.Phoenix/actions/runs/45509439098)
    on `e14a60d9d` (`37fef01d4` plus the two temporary files), 00:31-00:53
    on 25 November. Green in every job `[V]`.
  - `sboms` and `sboms-again`: both `1666bccb…`.
  - `build-manifest.json` (`e393b564…`): 15 subjects.
  - The temporary files were removed in `b66bdce95`, whose tree equals
    `37fef01d4`'s.
  - Main CI on `b66bdce95` (run 45514416170): green on attempt 2. On
    attempt 1 only the timing test `BatchQuery_VsIndividualQueries`
    failed. Main CI on `48c5b3cba` and `37fef01d4` had failed because the
    office runner was out of disk (worker crash, Postgres "could not
    extend file"); `test-release-manifest` passed every time.
- **Lab step 70c, the Mac Studio, 01:06-01:44 on 25 November: `SAME`**
  `[V]`. `rebuild.sh` from `b66bdce95` with the two Mac patches, against
  dry run 7. The rebuilt `build-manifest.json` equals the run's byte for
  byte (`cmp` of `data/…/github/dryrun7-build-manifest.json` with
  `macstudio/70c-dry7-build-manifest-rebuilt.json`). That covers all 15
  subjects: the 9 files, the SBOM zip `1666bccb…` and the 5 images. The
  log has no `qemu` line.
- `[I]` The fix leaves the runners' output as it was. Their migrators were
  already 0644: the Mac's fixed zip equals the zip they made without it.
  Dry run 6 was not run again on `37fef01d4`.

## Interpretation

- `[V]` Each shipped file now has its own SBOM. Two runners make the same
  bytes, and so does `rebuild.sh` on another architecture: dry run 7,
  `SAME` for all 15 subjects on the Mac Studio. The build record shrinks from 19 subjects to 15, and still
  names everything the release publishes.
- `[V]` The scanner sees into the single-file migrators: 144 NuGet
  packages and the .NET runtime packs each. That was Fable's open
  question `[I]`, now measured.
- `[I]` The mode finding is the thesis's pattern in small. A tool output
  (here an SBOM) recorded an incidental property of its input (a file
  mode), and only a rebuild on another path found it. The two runners
  agreed with each other because they got their inputs the same way.
- Two runs of one workflow do not show that a verifier reproduces it. The
  first independent rebuild did not, until the fix.
## Caveats

- The `*.log.gz` build logs are not in this public repository (they hold WS source paths and names); they are kept privately with Leo.
- An SBOM is a scan of the output. npm packages bundled into the
  frontend's chunks are invisible to it (ADR-0003 decision 3); the image
  SBOMs and the zip SBOMs share that gap.
- The scanner writes SPDX 2.3. BSI TR-03183-2 asks for SPDX 3.0.1+ or
  CycloneDX 1.6+; that is a scanner choice, not one of layout.
- An SBOM document does not carry the SHA-256 of the zip it describes.
  The binding is `build-manifest.json`, which lists both the zip and the
  SBOM zip by digest.

## Not tested

- A real release with the zip (thesis.8 is not tagged).
- A rebuild on Linux x86-64 (`arch`) with the new `rebuild.sh`: `arch`
  was off the network. Only the Mac Studio, with its two patches, has run
  it.
- Vulnerability scanners (grype, Trivy) reading the SPDX files.
