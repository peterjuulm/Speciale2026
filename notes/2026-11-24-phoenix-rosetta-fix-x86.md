# The Rosetta fix on x86-64: the images unchanged? (24 November 2026)

Grounds: builds on `arch` of the six images at the WS branch's tip
`688822389`, against the same images built from its parent `30b5c745d`
earlier that morning (D4 and D5 of
[phoenix-merge-optA](2026-11-23-phoenix-merge-optA.md)). Run by Claude in
a side session of the writing session, over SSH in the tmux session
`lab`, which Leo watched. Leo approved putting the fix on the branch and
pushing it that morning ("Ja, læg den på").

## Question

`688822389` adds `--mount=type=tmpfs,target=/root/.cache` to ten `RUN`
steps:

- the nine root `RUN`s in the stages the release's five images keep;
- the migrations image's one `RUN`.

On the Mac Studio, the flag keeps Rosetta's cache folder out of the
layers, and QEMU's x86-64 builds are the same with and without it
([rosetta-cache-layer](2026-11-24-rosetta-cache-layer.md)). Does a real
x86-64 machine give the same six images with the flag as without it?

## Setup

- `arch`: Leo's Arch laptop, x86-64, kernel 7.3.4-arch1-2, Docker
  29.9.3. BuildKit v0.33.1 as the builder `rb1` (digest `cec9f139…`),
  the version the release pins.
- **Without the flag:** the images of `30b5c745d`, built that morning:
  - the release's five, from D5's first run of the whole release
    (`rebuild.sh`'s images job);
  - the migrations image from D4's first build.
- **With the flag:** the same six from a shallow clone of `688822389`,
  built as those were:
  - `--no-cache`, no provenance;
  - `APP_VERSION=v0.0.0-merge-optA.1`;
  - the WebAPI image with `SKIP_SPA_BUILD=true` and the frontend export
    of D5's first run;
  - OCI output with `rewrite-timestamp`.
- `SOURCE_DATE_EPOCH` is `30b5c745d`'s time (1795445958), not
  `688822389`'s. The epoch dates the image config and caps the files'
  times, so a new commit date alone would change every manifest.
- The fix's commit changes nothing but the six Dockerfiles (44 lines
  added, 10 removed).
- Compared by `oci-diff.py` (`dotnet-rebuild-experiments` at
  `d991fc5`): the manifest, the config and each layer.

## Expectation, written before the run

Written at 10:00, before any of these builds ran.

1. All six images: the same `linux/amd64` manifest with the flag as
   without it. `[I]` The tmpfs exists only while the step runs. BuildKit
   writes no mount options into the image history. On the Mac, QEMU's
   x86-64 builds of the changed and unchanged Dockerfiles were the same.
2. The text `type=tmpfs` appears in no image's config.

## Commands

Verbatim in `data/2026-11-24-phoenix-rosetta-fix-x86/arch/kommando.txt`.

## Result

`[V]`, from `results.txt` and `42-fix-x86.log` in the data folder.

1. Held. With the flag, all six images have the same `linux/amd64`
   manifest as without it. In each, the config and every layer are the
   same:

   | Image | Manifest, with and without the flag | Layers |
   | --- | --- | --- |
   | `ws-pems` | `c6d39f32…` | 11 |
   | `ws-pems-job-worker` | `8544035d…` | 10 |
   | `wspems-mcp-server` | `856c0da4…` | 15 |
   | `wspems-chat-server` | `6885cc5f…` | 12 |
   | `wspems-mcp-auth-broker` | `43c88439…` | 11 |
   | migrations | `0c0565db…` | 9 |

2. Held. `type=tmpfs` appears in none of the six configs.

Every `RUN` step ran again, the ten with the flag among them. The build
logs report as cached only the base images' `FROM` and two `WORKDIR`s.

On GitHub, the manual checks at `688822389`
([run 45360625913](https://github.com/Weel-Sandvig/WS.Phoenix/actions/runs/45360625913))
passed all seven jobs: the backend build and tests, the frontend's lint,
tests and build, Trivy, and the secrets history scan.

## Interpretation

**On x86-64 the fix changes nothing.** `[V]` The six images built on
`arch` with the flag are byte for byte the images without it. Together
with the Mac Studio's measurements that morning, the flag:

- removes Rosetta's folders on a Mac;
- leaves an x86-64 build as it was.

So the fix costs a verifier on x86-64 nothing. It does not change what
GHCR would publish for the same commit and date.

**The three MCP images match across machines and emulators.** `[V]`
`856c0da4…`, `6885cc5f…` and `43c88439…` are the manifests that:

- `arch` built from `30b5c745d` (D5) and from `688822389` (here);
- the Mac Studio built under QEMU from the unchanged tree;
- the Mac Studio built under Rosetta with the flag
  ([rosetta-cache-layer](2026-11-24-rosetta-cache-layer.md)).

The MCP images take no `APP_VERSION`, so the comparison is direct. That
is the first time all three match between an x86-64 machine and an Apple
Silicon one. The pinned Debian snapshot (E1-S6-05) makes the apt layers
the same, and the tmpfs keeps Rosetta out.

`[I]` `ws-pems` and the job worker should match across the machines too
when both get the same `APP_VERSION` and frontend export. The Mac built
them with `v0.0.0-thesis.7`, and `arch` with `v0.0.0-merge-optA.1`, so
this was not shown.

## Caveats

- The comparison uses `30b5c745d`'s time as `SOURCE_DATE_EPOCH`. `[I]`
  Built with its own commit date, `688822389` would give other
  manifests, through the dates alone. That is what the epoch is for, not
  an effect of the flag. Not built that way here.
- One BuildKit (v0.33.1, the release's pin). GitHub's runners start the
  same version from the digest in `03-release.yml`.
- D5 and D4 are the references, built that morning on the same machine.
  They were not rebuilt for this.
- Docker's legacy builder rejects `RUN --mount`. The MCP Dockerfiles
  needed BuildKit before; now the WebAPI, job worker, broker and
  migrations Dockerfiles need it too. `[I]` Nothing in CI or the release
  uses the legacy builder. On `arch`, plain `docker build` outside `rb1`
  falls back to it (D4's migration test used it before the fix).

## Not tested

- The release workflow on `688822389`.
- `ws-pems` and the job worker with the same `APP_VERSION` on both
  machines.
- A Mac rebuild of the migrations image with the flag.
