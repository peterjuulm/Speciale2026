# v0.0.0-thesis.8, tagged and held back: the rebuild on Apple Silicon in rebuild.sh, and a readable rebuild.sh (25 November 2026)

Grounds: this morning's commits on the WS branch `thesis/reproducible-builds`, a test on the
Mac Studio, the tag `v0.0.0-thesis.8` and its release run, and a run on `arch`. Leo's decisions,
relayed by the writing session:
- the two Mac fixes go on the branch before the tag ("ser en pointe i, at vi lige får lavet den
  færdige version, og så får genkørt det");
- the tag is a go as long as WS colleagues' work is not in the way ("Det er et go herfra i hvert
  fald. Så længe vi ikke går i kampolage med arbejdet på Weel og Sandvig"), then "ja lad os få
  det gjort hurtigst muligt!";
- a readable `rebuild.sh`, after thesis.8 ("Ja, efter thesis.8"), without adding much new ("Nu
  skal vi heller ikke tilføje alt for meget nyt");
- at 11:2x, thesis.8 waits until December ("vente med thesis 8 til en gang i december, når vi
  har lidt mere styr på vores, så mig og Peter kan sidde sammen med vores branch"). The release
  run was cancelled and nothing was published; see "State at the end of the day".

Run by Claude in a side session of the writing session. The layout thesis.8 would ship, one SBOM
zip with 15 subjects, is in [phoenix-sbom-zip](2026-11-24-phoenix-sbom-zip.md). The thesis.7
rebuilds are in [phoenix-thesis7-release](2026-11-24-phoenix-thesis7-release.md).

## Question

1. Can `rebuild.sh` itself rebuild on an Apple Silicon Mac, with no lab patch, while Linux
   x86-64 runs exactly as before?
2. Does it stop with a clear message where it cannot work (arm64 without Rosetta)?
3. Does the published thesis.8 rebuild `SAME`? Not answered: thesis.8 was not published.
4. Does a readable `rebuild.sh`, the same behaviour in another layout, still rebuild the
   published releases `SAME`? Answered for thesis.7 only.

## The Mac fixes in rebuild.sh (commit `1c90ad428`)

`1c90ad428` is `b66bdce95` (dry run 7's tree) plus `rebuild.sh` and `docs/release/build-manifest.md`.
When `docker info` reports an architecture other than `x86_64`:
- before anything is built, a throwaway builder reads the kernel's `binfmt_misc` and stops
  unless an enabled x86-64 handler exists whose interpreter is not QEMU;
- `run()` passes `DOCKER_DEFAULT_PLATFORM=linux/amd64` through `env -i`;
- BuildKit's bundled `buildkit-qemu-x86_64` is moved aside in the rebuild's builder.

On `x86_64` none of this runs. The docs got a table of hosts, which says what is tested.

Checks `[V]`:
- `bash -n`.
- `run()`'s environment on `x86_64` is byte-identical to `b66bdce95`'s: the same 16 lines from
  `env`.
- On colima with Rosetta, the check finds `/mnt/lima-rosetta/rosetta`. colima disables
  `qemu-x86_64` there.
- **The refusal:** on a colima profile without Rosetta (`colima start -p norosetta --vm-type
  vz`), where only `qemu-x86_64` is enabled, `rebuild.sh v0.0.0-thesis.7` stopped in step 1,
  within seconds, with exit 1 and this message: "Docker runs on aarch64, and its kernel runs
  x86-64 programs only under QEMU or not at all; …". No builder was left behind.
  `data/2026-11-25-phoenix-thesis8-release/macstudio/75-arm64-refusal.log`.
  - It ran from the macOS host with `DOCKER_HOST` set to that profile's socket, and only the
    published manifest as `ASSETS`. The profile was deleted afterwards.

Not tested before the tag: a full Mac rebuild with these changes and no patch. A test against
dry run 7 sat on the 1.3 GB artifact download and was stopped when Leo asked for the tag at
once. The changes are the lab patch's two (with which the Mac rebuilt thesis.7 and dry run 7
`SAME`), plus the refusal. The published thesis.8, rebuilt on the Mac with its own
`rebuild.sh`, would be the test. It was not run, because thesis.8 was held back.

## The tag and the release run

- Before the tag: the runner agent on `arch` reported 37 GB free on `ws-office` (up from 11)
  at 10:22. At 10:28 no run was queued or in progress in the repository.
- `v0.0.0-thesis.8` (annotated, tagger as for thesis.6 and thesis.7) on
  `1c90ad428fcb3624e3da4c1bd8173ce7cc0dd8fa`, pushed 10:28:47 `[V]`.
- Release run [45585787137](https://github.com/Weel-Sandvig/WS.Phoenix/actions/runs/45585787137):
  - `validate-lookup`, Main CI's `test-release-manifest`, `test-node-services`,
    `build-frontend`, `frontend-build`, `migration-bundles` and `docker-images` green `[V]`.
  - Main CI's `build-backend` failed only in the integration test
    `EntityFrameworkPerformanceTests.BatchQuery_VsIndividualQueries` (the timing test), as on
    thesis.7, so `validate-gate` holds back the release job `[V]`.
  - `publish-linux`, `publish-windows` and `checksums` went green later.
  - The plan had been `gh run rerun --failed` once the run finished. At Leo's decision it was
    not rerun: it was cancelled at 11:22:45, while `sboms` and `windows-smoke` were running
    `[V]`. Conclusion `cancelled`; `release`, `sboms` and `windows-smoke` are cancelled.
  - `gh release view v0.0.0-thesis.8` says "release not found" `[V]`. Nothing was published,
    and no image was tagged. The untagged image manifests that `docker-images` pushed by digest
    stay in GHCR.
- The tag also started "Docs deploy" (`05-docs-deploy.yml`, run 45585787123), as every `v*` tag
  does. The writing session found that it failed at the Cloudflare step, before publishing
  anything. thesis.7's run of it, on 24 November, did publish: the public docs site and the
  internal docs image show the thesis branch's docs. That is Leo's to undo. Neither run is ours
  to rerun.

## The readable rebuild.sh (commit `378f113d9`, on the branch as `6b5d6b5b3`)

`378f113d9` on top of `1c90ad428` changes `scripts/release/rebuild.sh` only (347 lines in, 178
out):
- a `main()` that calls the seven steps, one function each;
- a list of the globals the steps share, and where each is set;
- the three Python blocks as named functions, their Python byte-identical to before;
- the Mac logic as `require_x86_without_qemu` and `use_rosetta_in_builder`;
- `run()`'s environment one variable per line;
- no line over 120 characters.

Checks `[V]`:
- `run()`'s environment is identical to `1c90ad428`'s in all 16 combinations of platform,
  `DOCKER_CONFIG`, `DOCKER_HOST` and `BUILDX_BUILDER`.
- The three Python blocks are byte-identical.
- shfmt `-i 2 -ci` and ShellCheck 0.10 are clean. Both were run from their Docker images on the
  Mac, and nothing was added to the repository.

**/simplify:** the built-in skill, with four reviewers (reuse, simplification, efficiency,
altitude). It found no behaviour change.

Applied:
- `start_builder` for the two identical `buildx create` calls;
- a comment on why three manifest values nobody reads are still looked up (a manifest without
  those dependencies fails in step 1);
- `DOCKER_CONFIG` straight into `run()`'s list, since it is always set by then;
- `jobs`, `T` and `home` set in `main`;
- the Mac check called from `main`;
- the list of globals.

Skipped:
- splitting step 5 into paste and pack, since it would break the seven-step mapping;
- dropping the step numbers in `main`;
- a helper for the repeated `rev-parse` of the tag.

A first draft with a separate `rebuild-helper.py` and five new tests was dropped, at Leo's
request to add little that is new.

The proof is lab step 78: `378f113d9`'s `rebuild.sh`, copied over a fresh clone at the thesis.8
tag on `arch`, against a published release. The plan was thesis.7, then thesis.8, with `SAME`
for both before the commit goes on the branch.

- **thesis.7: `SAME` `[V]`.** 10:54:26-11:15:38, exit 0, "SAME: … the published build-manifest.json, byte for byte". The rebuilt manifest equals the published one (`cmp`): `arch/78-readable-t7-build-manifest-rebuilt.json`, `arch/78-readable-t7-wrapper.log`. The verifier's `rebuild.sh` had sha256 `650489d4…`, the file of `378f113d9`.

- **thesis.8: not run.** thesis.8 was not published.

It was first kept unpushed for December. At about 11:25, Leo decided to close the branch by
committing what is finished ("Lad os lige starte med at få lukket vores thesis branch ned ved
at committe og pushe til den"). It went on the branch as `6b5d6b5b3`: `378f113d9`'s tree, with
the commit message saying it was proven against thesis.7 and not against thesis.8.

## State at the end of the day

- **The tag `v0.0.0-thesis.8`** (tag object `0ce0747b1f…` on `1c90ad428`) stays on GitHub. Keep
  it or delete it: Leo's call in December. A new tag later must have another name, or this one
  is deleted first.
- **No thesis.8 release.** The run was cancelled before its release job, so nothing was
  published.
- **`thesis/reproducible-builds` on GitHub** went from `1c90ad428` to `85334ffda`, pushed
  10:25:47Z `[V]`, in two commits:
  - **`6b5d6b5b3`**: the readable `rebuild.sh`, proven `SAME` against the published thesis.7,
    not against thesis.8.
  - **`85334ffda`**: Codex's shorter docs and comments.
    - 25 files: the patches in Leo's `notes/drafts/2026-11-25-codex-branch-text/`, all except
      `tools/dependency-graph/summary.md`, which is generated.
    - All applied with `git apply`. Text only `[V]`: the 10 shell scripts are the same without
      comment lines and pass `bash -n`; the 5 Python files have the same AST without
      docstrings; the release tests pass (6); `03-release.yml` parses (PyYAML and Ruby) to the
      same YAML apart from one comment line inside the `run` block of the release job's step
      13.
    - The docs keep the host table.

  The push started no workflow run, and the branch has no PR `[V]`. The thesis.8 tag stays on
  `1c90ad428`, so it does not have these two commits.
- The bundle on `arch` (`/private/tmp/rb1-lab/readable/`) and the lab clone's branch
  `readable-rebuild` hold the earlier hash `378f113d9`, with the same tree. They are no longer
  needed.
- **Not run:** the rebuilds of thesis.8 on `arch` and the Mac (lab 77 and 76 are written and
  ready), and the readable script against thesis.8.

Parked for December, by Leo's decision. Not touched today:
- whether to tag thesis.8 again (or keep this tag) and publish it;
- the arm64 build of `mcp/Dockerfile`;
- thesis.7's five provenance files;
- the office runner's RAM (4 GB);
- Windows signing for thesis tags;
- Docs deploy running on every `v*` tag. thesis.7's deploy was undone today by rerunning
  v1.0.60's.

## Caveats

- The thesis.8 tag carries the Mac fixes untested end to end on the Mac. If the Mac rebuild of
  the published thesis.8 fails on them, thesis.8 can still be verified with the lab patch
  (`PATCH=1 bash lab/76-mac-t8.sh`), and the fix goes into a later release.
- The refusal test ran `rebuild.sh` on the macOS host against a colima VM, not inside a Linux
  container: only step 1 ran, which needs no GNU tools.

## Not tested

- macOS on Intel and Windows (WSL2): in the docs' table as expected, untested.
- Linux on arm64 with a non-QEMU x86-64 handler (FEX, box64): the check would let it through.
  Whether dotnet runs there is unknown.
