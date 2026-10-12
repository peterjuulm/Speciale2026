# Phoenix: the release zips (layer 4)

Experiment note, 12 October 2026, on `arch`. Private data in Leo's
`speciale-2026/data/phoenix-zip/arch-2026-10-12/`; the public part is in
[data/2026-10-12-phoenix-zip/arch/](../data/2026-10-12-phoenix-zip/arch/). Phoenix source and build output do
not land in this repo. Expectation written before the first run.

## Question

The whole Linux release, built end to end, gives the same 2227 files under
every axis ([phoenix-sorted-release](2026-10-12-phoenix-sorted-release.md)).
What ships, though, is two zips, one per program, and a zip stores more than
the files' bytes. Two questions:

1. Are the zips reproducible as the release workflow makes them?
2. If not, does a normalised packing make them so?

The commit is `a16f9a91`, the branch head.

## How the release packs

`03-release.yml` lines 297-303 `[V]`: in `release/`, `zip -r
ws-pems-linux-x64-${REF_NAME}.zip ws-pems-linux-x64/` and the same for the
job worker. `SHA256SUMS` is then made from the zips (lines 562-567 `[V]`), so the
zips' bytes are what a user checks. Info-ZIP's `zip`, as on the Ubuntu
runner. For each entry it stores, besides the bytes `[I]` (Info-ZIP's
documentation):

- the modification time as a DOS date and time, in local time;
- an extra field `UT` with the modification time in UTC, and in the local
  header the access time too;
- an extra field `ux` with the owner's uid and gid;
- the Unix mode in the external attributes;
- the entries in the order `zip -r` meets them in the directories.

## Setup

- `experiments/phoenix-rt/run.sh` gets a layer `Z`: layer `R`, the whole
  release in one build, then a hash list of `release/`, then the zips twice.
  First as CI makes them, with `zip -q -r` (`-q` only silences the output).
  Then normalised, as a candidate fix: every folder 755, every file 755 or
  644 by its owner's x bit, every time set to `ZEPOCH`, the names sorted
  with `LC_ALL=C sort`, `zip -X` without extra fields, and `TZ=UTC` for the
  DOS time. Empty folders stay in, as entries.
- `ZEPOCH` is the commit's time, `1791802349` (12/10 12:52:29 +0200). In CI
  it would be `git log -1 --format=%ct`.
- `zip` is Info-ZIP 3.0 from the Flatpak runtime
  `org.freedesktop.Platform` 25.08, copied to `/private/tmp/rb1-tools/zip`,
  since `arch` has no `zip`. The Ubuntu runner's is Info-ZIP 3.0 too, built
  by Ubuntu.
- `experiments/phoenix-zip/compare-zip.py` compares two zips entry by entry
  and field by field.
- Axes `none` and `all`, with `APP_VERSION=v0.0.0-thesis` and
  `LC_ALL=C.UTF-8` as in layer `R`.
- Checked on a small tree before the run: two CI-style zips made a few
  seconds apart differ, the two normalised ones are identical.

## Expectation, written before the run

All `[I]` until measured.

1. The release's files are the same as in layer `R`, `b72bbc3b…`, under both
   axes.
2. The CI zips differ under `none` already: every entry's DOS time and `UT`
   time differ, because the two builds write their files at different
   times, and the access times differ too. Names, contents and CRCs are the
   same.
3. The CI zips' entry order may differ: `zip -r` lists folders as the file
   system returns them, and on tmpfs that follows the order the files were
   created, which a parallel publish may vary.
4. Under `all` the CI zips differ also in the modes (umask 0002) and in the
   DOS times' time zone. The `ux` owner is the same, since `all` does not
   vary the user.
5. The normalised zips are identical under both axes, byte for byte.

## Commands

Run by Claude at Leo's request, in bash. Verbatim in `kommando.txt`.

## Result

`[V]` (`summary.tsv`, the stores' hash lists, `compare-zip.py` on the
stores' zips, `zipinfo`, the samples):

| Run | Start-end | Exit | Release, both builds | CI zips | Normalised zips |
| --- | --- | --- | --- | --- | --- |
| `Z-none` | 14:21-14:37 | 1 | `b72bbc3b…` | differ | identical |
| `Z-all` | 14:37-14:51 | 1 | `b72bbc3b…` | differ | identical |

- The normalised zips are the same in all four builds, across the two
  runs: `b3d86bf0a1f646b6` for WebAPI (1847 entries, 258815568 bytes) and
  `df24fa1e75ec48fc` for the job worker (493 entries). `Z-all`'s experiment
  had libfaketime, `et_EE.UTF-8` under the pinned `LC_ALL`, `TZ=GMT-14`,
  umask 0002, 5 CPUs and another path.
- In the CI zips, no entry's bytes differ: the same CRC, sizes and
  compression for every entry, in both runs. Everything else can differ:

| Field | `Z-none`, WebAPI | `Z-none`, job worker | `Z-all`, WebAPI | `Z-all`, job worker |
| --- | --- | --- | --- | --- |
| Entry order | 140 positions | 287 | 1239 | 347 |
| DOS time | 1237 of 1847 | 10 of 493 | 1847 | 493 |
| `UT` times | 1237 | 10 | 1237 | 10 |
| Mode | 0 | 0 | 1192 | 9 |
| `ux` owner | 0 | 0 | 0 | 0 |

- The entries whose time stays the same under `none` are the 609 and 482
  dependency DLLs with mode 744. Publish copies them from the NuGet cache
  with their times, which are dates such as 17 July 2026 and 29 October
  2024. Under `all` their DOS time differs anyway, by the time-zone
  difference: the DOS time is local time.
- Under `all`, 644 became 664 for 1080 entries and 755 became 775 for 112.
  Unchanged: the 609 DLLs at 744, and 45 files at 644, the 44 of `public/`
  and `appsettings.json`.
- Every CI zip entry carries `ux` with uid and gid 1000, the build user.
- The normalised WebAPI zip has 112 folders at 755, 1125 files at 644 and
  610 at 755: the 609 DLLs, which had 744, and the program. All times are
  12/10 10:52 UTC, and no entry has an extra field.

Where the expectation failed: 2 held except that the dependency DLLs keep
their time under `none`. 1, 3, 4 and 5 held.

## Interpretation

**The release zips are not reproducible as the workflow makes them, and
only their metadata is to blame.** The files inside are the same bytes
every time; the zip around them records when each file was written, in
the build's time zone, in the order the file system listed them, with the
build's umask and the build user's uid and gid. Two builds a few minutes
apart already give different zips, and so a different `SHA256SUMS`.

**A normalised packing makes them identical, also across runs and under
every variation.** Fixed times from the commit, sorted names, no extra
fields, `TZ=UTC` and modes set from the owner's x bit: four builds, two
runs, one pair of zips. The packing is a few lines of shell in the
release's archive step. It changes the zips in three ways a user could
notice: every file shows the commit's time, the 609 DLLs get 755 instead of
744, and the uid, gid and access times are gone `[I]`.

**This also settles W30 for the release.** The modes a build gives its files
no longer reach the zip.

## Caveats and not tested

- The zip is the Flatpak runtime's Info-ZIP 3.0, not Ubuntu's build of the
  same version. Their default output is expected to match, not checked.
- In CI the NuGet cache is filled fresh by each restore. Whether the
  DLLs' times then match from run to run is not measured; the normalised
  packing sets them anyway.
- `user_group` was not run for layer `Z`; the `ux` field it would change is
  left out by `zip -X`.
- The Windows zips (`Compress-Archive`, lines 476-482) and the migration
  bundles in `SHA256SUMS` are not measured.
- The normalised packing is in the experiment's script, not in the WS
  workflow.
