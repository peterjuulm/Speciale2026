# Windows

Living document for the Windows side of Phoenix's release: decisions, what is
on which branch, what is measured and what is open. Add a dated line to the
log at the bottom for every change. Started 5 October 2026.

## Where we stand

| Item | State |
| --- | --- |
| Scope | Later work in the thesis if time allows; part of the delivery to Weel-Sandvig. Decided by Leo and Peter on 5/10 ([layer plan](2026-09-15-layer-plan.md), "Windows") |
| Measured | 13/10: the Windows release as the job builds it since the merge, on Linux, built twice under `none`, `all` and `locales`: identical before signing ([phoenix-windows-release](2026-10-13-phoenix-windows-release.md)). Nothing on a Windows machine |
| Locale fix (W26) | Not needed since SDK 10.0.401: its compiler sorts ordinally ([findings table](findings-table.md), W26). `thesis/reproducible-builds-windows` (`b9c0700d`) never ran |
| Release workflow on the thesis branches | The Windows job ran once, on the test tag `v0.0.0-thesis.1` (`82ea130a`, 13/10) on GitHub's Windows runner: published, signed, verified ([phoenix-release-run](2026-10-13-phoenix-release-run.md)). Since the merge it builds on a Linux runner and signs in a container; not run like that yet |

## Why Windows needs its own locale fix

History since 13/10: the branch builds with SDK 10.0.401, whose compiler
sorts these types ordinally, and the Windows job builds on Linux. The
section is kept as the reasoning of 5/10.

- W26: Roslyn 4.12, the compiler in SDK 9.0, orders the types it generates
  for collection expressions with a culture-sensitive sort. Under
  `et_EE.UTF-8` four of Phoenix's assemblies change ([findings
  table](findings-table.md), W26; [roslyn-locale-repro](2026-09-24-roslyn-locale-repro.md)).
- The Linux release jobs pin `LC_ALL: C.UTF-8` on `thesis/reproducible-builds`
  (`4e5237a3`), not yet run in CI.
- `LC_ALL` does nothing on Windows: .NET takes the culture from the user's
  region settings `[V]` `CultureInfo.Windows.cs`, dotnet/runtime `release/9.0`
  (layer plan).
- `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` makes culture comparisons ordinal
  on every operating system. On Linux it gave the release's bytes under both
  `C.UTF-8` and `et_EE.UTF-8` `[V]` (roslyn-locale-repro B4 and B5;
  [layer2-reprotest](2026-09-24-phoenix-layer2-reprotest.md) run 6). On
  Windows it stays `[I]` until measured.
- GitHub's Windows runners probably use `en-US`, which sorts these names in
  the same order as ordinal `[I]`. Today's output would then match, but the
  workflow neither sets nor records the region.
- The ordinal sort is in Roslyn since PR #80970 and ships from SDK 10.0.2xx,
  in no .NET 9 SDK `[I]` (roslyn-locale-repro).

## What is on which branch (WS.Phoenix)

| Branch | Commit | `publish-windows` in `03-release.yml` |
| --- | --- | --- |
| `thesis/reproducible-builds` | `4e5237a3` (24/9) | No locale setting. The Linux jobs have `LC_ALL: C.UTF-8` |
| `thesis/reproducible-builds-windows` | `b9c0700d` (5/10), off `4e5237a3` | Job-level `env: DOTNET_SYSTEM_GLOBALIZATION_INVARIANT: "1"` |
| `thesis/reproducible-builds` | `100e3912` (13/10), after the merge of main | Calls `00-reusable-windows-publish.yml`: a Linux runner, one locked restore, three `win-x64` publishes, signing in a container, both zips packed with `scripts/pack-release-zip.sh`. No locale setting |

Invariant mode applies to every .NET process in the job, the signing step
included. The first Windows run should check that signing and publishing
behave as before `[I]`.

## Open points

From the layer plan, plus what came up on 5/10:

- Invariant globalization is not measured on Windows.
- The branch's locked restore and `--no-restore` in the Windows job have never
  run on Windows. One run of the release workflow is needed before delivery.
- How to run the Windows job without making a release. The workflow starts
  only on a `v*.*.*` tag, and its last job, `release`, makes the GitHub Release
  and the real image tags, so a test tag would publish `[V]` (`03-release.yml`).
  Options to settle: a manually triggered copy of the job, a fork, or the
  publish commands by hand on a Windows machine `[I]`.
- reprotest runs only on POSIX systems (`external/reprotest-0.7.32`,
  `dist-info/METADATA`), so the comparison method on Windows is open.
- Signed binaries can never equal a rebuild byte for byte. A comparison has to
  strip the signature first.
- Line endings at checkout, and whether a Linux machine can rebuild the
  Windows release. The second is answered for the unsigned release: yes,
  byte for byte (13/10).

## Log

- 2026-10-05: Windows decided as later work, part of the WS delivery (layer
  plan).
- 2026-10-05: `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT: "1"` added to
  `publish-windows` on the new branch `thesis/reproducible-builds-windows`
  (`b9c0700d`, off `4e5237a3`). Not run.
- 2026-10-12: the WS branch moved to SDK 10.0.401; W26 gone (`Z-locales`,
  phoenix-net10-release).
- 2026-10-13: the Windows job ran on GitHub's Windows runner on the test
  tag `v0.0.0-thesis.1` (`82ea130a`): published, signed and verified.
- 2026-10-13: main merged into the branch (`79cb67a7`); the Windows job now
  builds on a Linux runner and signs in a container. Both release jobs pack
  with one script since `5ec085ac`.
- 2026-10-13: the Windows release built twice on `arch`, the job's commands
  on `100e3912`, under `none` and `all`, and under `locales` without the
  locale pin: the same 4256 files and zips before signing
  (phoenix-windows-release).
