# v0.0.0-thesis.7: the release with its build record, published and rebuilt (24 November 2026)

Grounds: the WS branch `thesis/reproducible-builds` after stages 0-2 of
the release record
([phoenix-build-manifest](2026-11-24-phoenix-build-manifest.md)), a real
tag and its GitHub release run, a check of what that run published, and
rebuilds of the published tag on `arch` and on the Mac Studio. Leo gave
the go that evening ("Yeah." / "ja"), on the condition that every gate
in the [checklist](2026-11-24-phoenix-thesis7-checklist.md) was green
first. Run by Claude in a side session of the writing session.

## Question

1. Does the release workflow, with the build record in it, publish a
   release whose `build-manifest.json` names every published file and
   image by digest, with the version tags naming the image manifests
   themselves?
2. Does `scripts/release/rebuild.sh v0.0.0-thesis.7`, the verifier the
   tag carries, rebuild the published release so that the regenerated
   `build-manifest.json` equals the published one byte for byte (`SAME`),
   on `arch` and on a second machine of another architecture?

## The gates before the tag

All five were required green on the commit to be tagged, `96e2990a6`
(the branch's tip; its tree is dry run 5's without the two temporary
workflow files, plus the two fixes `7d5c05eb0` and `96e2990a6`).

| Gate | Result |
|---|---|
| Dry run 5 green, `web.config` without the ProjectGuid | [run 45403522195](https://github.com/Weel-Sandvig/WS.Phoenix/actions/runs/45403522195), on `8491a0d63` `[V]` |
| No temporary `zz-*` workflow in the tagged tree | `git ls-tree -r --name-only 96e2990a6 .github/workflows \| grep zz` prints nothing `[V]` |
| Main CI green on `96e2990a6` | run 45413447893: attempt 1 failed only in `BatchQuery_VsIndividualQueries`, the timing test; attempt 2 (`gh run rerun --failed`) green `[V]` |
| Arch verify-twice against dry run 5 | lab step 64g: `SAME` twice; the two rebuilds' 14 release files, 5 image manifests and the two manifests identical; the 5 SBOMs equal the run's `[V]` |
| The tag-digest test | lab step 65b, below `[V]` |

`[V]` The tagged commit's `docker-images.sh` and `03-release.yml` equal
dry run 5's (`git diff --quiet 8491a0d63 96e2990a6 -- …`). Its
`migration-bundles.sh` and `rebuild.sh` differ: the invariant culture for
the SQL, and the verifier fixes. Linux's SQL with and without the
invariant culture is the same file, `d46aeeb1…` (the Mac's native script
check of the afternoon, against the run).

### The tag-digest test (lab steps 65 and 65b)

A throwaway registry (`registry:2`) on `localhost:5000` on `arch`, and a
builder of the pinned BuildKit on the host network. `docker-images.sh
push` (the release job's mode: push by digest) pushed the five images of
dry run 5's source; then the release job's own tagging,
`imagetools create --prefer-index=false`, and its digest check.

- **65, the first run:** the tagging held (each tag's digest = the
  pushed manifest, an OCI image manifest). But the pushed manifests and
  SBOMs differed from rebuild 1's. Cause `[V]`: the script cloned the
  verifier's checkout at its `HEAD`, `7d5c05eb0`, not dry run 5's
  `8491a0d63`, so it built another source with another
  `SOURCE_DATE_EPOCH`. A fault of the test, not of the release.
- **65b, on `8491a0d63`:** `[V]`
  - each pushed object is `application/vnd.oci.image.manifest.v1+json`;
  - each version tag's digest equals the pushed manifest's;
  - each equals the image subject in rebuild 1's `build-manifest.json`;
  - each pushed manifest equals rebuild 1's OCI file (`oci` mode): push
    and OCI export give the same manifest;
  - the `ws-pems` and `wspems-chat-server` SBOMs equal rebuild 1's;
  - without `--prefer-index=false`, `imagetools create` wraps the
    manifest in a new OCI index (`b373f6c1…` for the auth broker), whose
    digest is not the manifest's. That is the default stage 2 avoids.

## The tag and the release run

- `[V]` Tag `v0.0.0-thesis.7` (annotated, tagger Leo's identity as for
  `thesis.6`) on `96e2990a6128eed919eb216a3779f3d0613ce6cc`, pushed
  17:56:48.
- `[V]` [Release run 45442984125](https://github.com/Weel-Sandvig/WS.Phoenix/actions/runs/45442984125):
  green. `validate-lookup` reused Main CI's green attempt; `validate-run`
  skipped. Green: `frontend-build`, `migration-bundles`, `docker-images`,
  `publish-linux`, `publish-windows` (with the real signing),
  `checksums`, `windows-smoke`, `release`. The job list with times is in
  `data/…/github/release-run-45442984125.json`; the full log stays out of
  this public repository.

## What the release published

Checked from a download of the release and `gh api` on the GHCR
packages, 18:45-18:50. All `[V]`; the files are in
`data/2026-11-24-phoenix-thesis7-release/github/`.

- A pre-release, with 20 assets: the four zips, both migrators, the SQL,
  `upgrade.sh`, `SHA256SUMS`, `build-manifest.json`, five
  `*.spdx.json` and five `*.provenance.json`.
- `SHA256SUMS`: 8 lines, all OK. It lists none of the record's files.
- `build-manifest.json` (`13b29f4b…`):
  - 19 subjects: 9 files, 5 SBOMs, 5 images; no provenance file;
  - every file subject's SHA-256 equals the downloaded file's;
  - `gitCommit` is `96e2990a6…`, `APP_VERSION` is `v0.0.0-thesis.7`,
    `SOURCE_DATE_EPOCH` 1795530171.
- Images: for each of the five, the GHCR version tagged
  `v0.0.0-thesis.7` is the digest in `build-manifest.json`. The release
  job checked each digest is one image manifest before writing the
  record, and each tag's digest after tagging; both steps passed.
- Provenance files: no `github_` keys and no e-mail addresses.
- The release notes carry the "How to rebuild this release" paragraph.
  GitHub's generated "What's Changed" list follows it, so it is not the
  last paragraph, as the checklist had it.

## Expectation for the rebuilds, written before their results

- `arch`, twice, with the tag's own `rebuild.sh`, in a fresh clone: `SAME`
  both times, and the two rebuilds identical, as for dry run 5 (64g). The
  published release came from the same scripts as dry run 5, now on a
  real tag with real signatures. What is new: the real Authenticode
  signatures pasted into the rebuilt Windows files.
- The Mac Studio, in an x86-64 container under Rosetta in colima: `SAME`
  for the files. For the images, `SAME` if Rosetta runs every x86-64
  step and the Rosetta fix in the Dockerfiles keeps its cache folder out
  of the layers. Not certain: no image has been rebuilt end to end under
  Rosetta through `rebuild.sh` before (the two tries of the afternoon
  failed, below).

## The rebuilds

### Arch (lab step 71)

`lab/71-t7-arch-twice.sh`: a fresh clone of the source with the tag
fetched from GitHub, the release's assets with `gh release download`,
`sha256sum -c SHA256SUMS` (8 OK `[V]`), then `rebuild.sh
v0.0.0-thesis.7` twice under the memory guard.

**Interrupted** `[V]`. The script started at 18:44 (log `~/lab-logs/71-t7-arch-twice.log` on `arch`): the verifier source and the tag were `96e2990a6`, the 20 assets downloaded, `sha256sum -c` said OK for all 8, and rebuild 1 began at 19:03. Around 20:00 `arch` left the office network (ssh timed out, then "Host is down"; ping lost all; Wake-on-LAN got no answer), with the lid open and nobody touching it. Not a result about the release: the verify-twice against dry run 5 (64g) and the tag test (65b) had passed on `arch` before the tag.

The cause, read on 25 November from `arch`'s journal of the previous boot (`journalctl -b -1`) and upower's battery history `[V]`: `arch` was on battery, not mains, as the evening's note had assumed.
- It had been discharging from at least 15:21 (98 %), about 25 % an hour under the builds, and reached LOW at 18:40.
- At 19:38:43 upowerd asked logind to suspend at 2 % (`PercentageAction=2`, `CriticalPowerAction=Auto`). NetworkManager went to sleep, and at 19:38:44 the kernel entered s2idle.
- It woke at 21:26:05, and the journal stops at 21:27:59 with no shutdown: the battery ran flat. `rebuild1.log` was last written at 21:28.
- GNOME's idle setting and the sleep inhibitor do not cover the critical-battery action.

The journal's last 50 lines and its suspend lines are kept privately (`speciale-2026/data/phoenix-thesis7-release/arch-journal-boot-1-tail.txt`), since the journal is the whole machine's.

**Run again, 25 November: `SAME` `[V]`.** Started 10:06 with the same script, on AC (charging from 9-10 %), after a reboot. Two things the reboot had removed were restored first: the memory guard `/tmp/claude-1000/ws-mem-run.sh` (`/tmp` is a tmpfs on `arch`; written again from its description, same lock, same `MemoryMax`/`MemorySwapMax=0` scope, same cap + 6 GB check) and the tmux session `lab` (now running bash; the new session first opened fish, where `lab.sh`'s command line fails). The verifier source and the tag are `96e2990a6` again, and `sha256sum -c` says OK for all 8. Rebuild 1 began at 10:09:40 and ended at 10:30:09 with exit 0: `SAME`. The rebuilt `build-manifest.json` is the published one, byte for byte. That covers all 19 subjects: the 9 files with the real signatures pasted, the 5 SBOMs and the 5 image manifests. `cmp` against the published copy in `data/…/github/` agrees. Rebuild 2 was refused at 10:30:09, as planned below (`arch/71-t7-rebuild2-refused.log`). Logs: `data/2026-11-24-phoenix-thesis7-release/arch/` (the lab log, the gzipped rebuild log, the rebuilt manifest). It took 20 minutes, against about 2 hours the evening before, when rebuild 1 had not finished by 19:38: warm caches on `arch`, AC power, and the `performance` profile. The time is not part of the result.

Two differences from 64g, both Leo's choice on the morning of 25 November:
- **One rebuild, not two.** Arch's agreement between two rebuilds is already shown by 64g, and the Mac Studio rebuilt the published thesis.7 `SAME`. The script is unchanged. Instead, the memory guard refuses the call whose work folder is `/private/tmp/rb1-t7/work2` and stops the lab script, so the log ends after rebuild 1's verdict, and the comparisons of rebuild 1 against rebuild 2 do not run.
- **The power profile was `performance`, not `balanced`.** `powerprofilesctl get` said `performance` at about 10:13 and again at 10:14, during rebuild 1. A change over SSH had been refused by polkit, so Leo or a saved setting must have set it at the machine. The journal does not say when. That should change only the time, not the bytes.

### Mac Studio (lab step 70, PUBLISHED=1)

The verifier runs in `rb1-verifier:amd64` (Ubuntu 24.04, x86-64, under
Rosetta in colima's vz VM, aarch64), with the VM's Docker socket, the
work folder a Docker volume at the same path inside and out, and
`DOCKER_DEFAULT_PLATFORM=linux/amd64`. Two tries against dry run 5 that
afternoon showed two Mac-only faults in the verifier as the tag carries
it `[V]`:

1. **The images were built for arm64.** `rebuild.sh` runs each job under
   `env -i`, which drops `DOCKER_DEFAULT_PLATFORM`, so buildx built for
   the VM's platform. The arm64 canvas prebuilt in `mcp/Dockerfile`'s
   build stage then failed the MCP server's tests: `libexpat.so.1` is not
   in the slim base image (log
   `data/2026-11-24-phoenix-build-manifest/macstudio/70-dry5-try2-arm64-rebuild.log.gz`).
   The release files of that try matched the run's (Linux zips, migrator;
   the SQL before the invariant-culture fix did not).
2. **Under BuildKit's own QEMU, .NET aborts.** With the platform passed
   through, the builder (BuildKit's container, arm64) listed only
   `linux/arm64, linux/386` and ran the x86-64 steps under its bundled
   QEMU; `dotnet restore` aborted ("qemu: uncaught target signal 6") and
   the build hung for 85 minutes at 0 % CPU (log `…70-dry5-try3-qemu-hang-rebuild.log.gz`).
   The Rosetta note of that morning had met the same: .NET crashes under
   QEMU, and BuildKit hands x86-64 programs to Rosetta only once its
   bundled `buildkit-qemu-x86_64` is moved aside in the builder's
   container.

For the published tag, `lab/mac-verifier/patch-rebuild.sh` makes both
changes in the verifier's own clone (not on the branch): the platform
passed through `run()`, and the QEMU moved aside right after `rebuild.sh`
starts its builder.

Two more tries failed for the Mac itself, not the release `[V]`:

3. 19:24: the wrapper stopped before building: macOS's bash 3.2 treats the
   empty `ca` array (no CA for a real release) as unbound under `set -u`.
   Fixed in the wrapper (`${ca[@]+"${ca[@]}"}`), with `REUSE=1` to keep the
   downloaded assets.
4. 20:06: the host's disk filled during the first image build (colima's VM
   disk had grown to 85 GB on a 460 GB volume with other work on it). The
   VM's Docker databases then returned I/O errors. Before that, `dotnet
   restore` was running under Rosetta, with no QEMU. colima's VM and data
   disk were deleted and created again with the same settings (vz,
   Rosetta, 8 CPUs, 20 GiB, 100 GB), and the verifier image rebuilt.

**Try 5, 21:00-22:00: `SAME`** `[V]`
- `rebuild.sh` from the tag (`96e2990a6`) with the two patches, in
  `rb1-verifier:amd64`, against the published release downloaded fresh
  (`sha256sum -c`: 8 OK).
- Step 7: "SAME: … the published build-manifest.json, byte for byte". The
  rebuilt manifest is in `data/…/macstudio/build-manifest-rebuilt.json`;
  `cmp` with the published copy in `data/…/github/` says equal.
- That covers:
  - the 9 files, the Windows ones after pasting the real signatures;
  - the 5 SBOMs;
  - the 5 images. The rebuilt OCI manifests (`images.txt`) are the five
    GHCR tags' digests, built on Apple Silicon under Rosetta.
- The log has no `qemu` line.
- The steps took 60 minutes:
  - jobs, 21 minutes;
  - paste, 7 minutes;
  - images, 28 minutes.

## Interpretation

- `[V]` The first published release with its build record
  verifies on a second machine of another architecture. The published
  `build-manifest.json` was regenerated byte for byte from a rebuild on an
  Apple Silicon Mac, with the x86-64 steps under Rosetta. The check is
  one `cmp`, with the published Windows signatures pasted. That answers
  question 2 for the Mac.
- `[V]` Question 1 holds. The tags name the image manifests themselves, so
  the digest a rebuild makes is the digest a `docker pull` of the tag gets.
  65b showed that pushing by digest and exporting to an OCI file give the
  same manifest. That is why a rebuild into OCI files can be compared with
  the registry at all.
- `[I]` The verifier as tagged runs as is on Linux x86-64 (64g, on
  `arch`). On an Apple Silicon Mac it needs two changes that are not on
  the branch:
  - pass `DOCKER_DEFAULT_PLATFORM` through `env -i`;
  - keep BuildKit from using its own QEMU, under which .NET aborts.

  Both are about the verifier's host, not the release. Whether they belong
  on the branch is Leo's decision.
- `[I]` What the Mac rebuild adds to `arch`'s 64g: other hardware, another
  kernel (colima's), and another x86-64 implementation (Rosetta, not a
  CPU) gave the same bytes. The earlier Rosetta cache-folder fix in the
  Dockerfiles is what makes the images agree.

## Caveats

- The `*.log.gz` build logs are not in this public repository (they hold WS source paths and names); they are kept privately with Leo.
- Main CI on the tagged commit was green only on its second attempt. The
  failing test is a timing comparison on a shared runner, not touched by
  the branch.
- Both Mac patches live outside the tag. A verifier on an Apple Silicon
  Mac needs them until the branch carries them.
- The Mac ran the rebuild once, not twice. Its agreement is with the
  published release, not with a second run of its own.
- `arch`'s rebuild of the published tag was interrupted; only the Mac has
  rebuilt the published release so far.
- The GHCR check read the tag's digest through GitHub's packages API, not
  with `imagetools inspect` from here; the media type rests on the
  release job's own check.

## Not tested

- Pulling and running the published images.
- Installing the published release on a server, or the Windows zips
  outside `windows-smoke`.
- A rebuild on a machine with no access to WS's GitHub (the source and
  the release are private).
