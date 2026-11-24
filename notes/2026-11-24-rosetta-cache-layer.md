# Keeping Rosetta's cache folder out of the image layers (24 November 2026)

Grounds: the writing session's request of 24 November, for the coming
prerelease `v0.0.0-thesis.7`. Both `arch` and the Mac Studio are to
rebuild that release, every image included, and get identical results.
The Mac Studio rebuild of `v0.0.0-thesis.6` on 23 November
([phoenix-macstudio-rebuild](2026-11-23-phoenix-macstudio-rebuild.md),
result item 6) found that Rosetta, which runs the `linux/amd64` steps on
the Mac, leaves three empty folders, `root/`, `root/.cache/` and
`root/.cache/rosetta/`, in the layer of any `RUN` step it runs as root.
That alone keeps the Mac from matching. Run by Claude on the Mac Studio.
`arch` is not used: the branch session is rebuilding there.

## Question

Is there a minimal change to the Dockerfiles that keeps Rosetta's cache
folder out of the layers? The test is the WebAPI Dockerfile's base stage
alone (`--target base`), built at the tip of `thesis/reproducible-builds`
(`30b5c745d`), once under Rosetta and once under BuildKit's own QEMU.

- Required: with the change, the Rosetta layer equals the QEMU layer.
- Preferred: the change leaves the layer an x86-64 build makes as it
  was, GHCR's `v0.0.0-thesis.6` layer 7, `67cb4685…`.

Then: which other `RUN` steps in the images the release builds run as
root, or as any user, in a stage that ends up in an image, and so need
the same change?

## Setup

- The Mac Studio as on 23/11: colima 0.10.3 and Lima 2.3.0, a `vz` VM
  (aarch64) with Rosetta registered for x86-64, Docker CLI 29.10.0,
  buildx 0.38.0, and BuildKit v0.33.1 pinned by digest. Two builders of
  the same BuildKit image:
  - `rb1`, with BuildKit's bundled QEMU moved aside in the builder's
    container, so that the kernel hands x86-64 programs to Rosetta;
  - `rb1q`, unchanged, so that BuildKit runs them under its bundled QEMU
    (10.2.3).
- QEMU stands in for an x86-64 machine. On 23/11 its base-stage layer
  was GHCR's exactly. It creates no cache folder.
- The source: an export of `30b5c745d` into a lab under `/private/tmp`,
  outside any git repository. Leo's WS.Phoenix clone is not touched.

## Expectation (written 24/11 09:02, before anything was run)

1. **Baseline, no change.** Under Rosetta the base stage's layer holds
   the three folders; under QEMU it does not. If the base stage has not
   changed since the tag, the layers are `e9ec63f8…` (Rosetta) and
   `67cb4685…` (QEMU), as on 23/11.
2. **A tmpfs on the cache folder:** `--mount=type=tmpfs,target=/root/.cache`
   on the `RUN`. Rosetta writes its folder into the tmpfs, which is not
   part of the layer. `/root/.cache` does not exist in the base image,
   so BuildKit creates it as a mount point and removes it after the
   step. I expect BuildKit also to restore the parent's time, so that
   `/root` is not in the layer either: Rosetta's layer equals QEMU's,
   and both are `67cb4685…`. Doubt: if the mount point leaves `/root`
   behind, both layers hold `root/`. They then still equal each other,
   but not `67cb4685…`.
3. **A tmpfs on the whole home folder:** `--mount=type=tmpfs,target=/root`.
   `/root` exists, so no mount point is created. Expect Rosetta's layer
   to equal QEMU's, both `67cb4685…`. The cost: it hides anything the
   step writes under `/root`. That does not matter for a step that
   creates folders or installs packages, but it does for a step that
   relies on a cache from an earlier step.
4. **Mechanism:** Rosetta finds the folder through `$HOME`, not through
   the password file. So a `HOME` pointed elsewhere moves the folder
   instead of removing it. `[I]`, to be checked.
5. **Other steps:** the MCP images' runtime stage runs `apt-get` as
   root, and on 23/11 its layer held the same folders. It needs the same
   change. Steps in build stages leave the folder only in their own
   stage, which no image keeps. Whether the migrations image is in the
   release, and what it runs, is to be read from the workflow.

## Commands

Verbatim in
[`data/2026-11-24-rosetta-cache-layer/macstudio/kommando.txt`](../data/2026-11-24-rosetta-cache-layer/macstudio/kommando.txt).

## Result

Built 24/11 09:06-09:50. Digests, layer lists and probes are in
[`results.txt`](../data/2026-11-24-rosetta-cache-layer/macstudio/results.txt).
Layer numbers count from 1 in the image manifest. "QEMU" is BuildKit's
own (10.2.3), "Rosetta" the one Lima mounts in the VM.

**What Rosetta reads.** Its binary names the cache `%s/.cache/rosetta`
next to the string `HOME=`, and has no XDG or `ROSETTA_` variable for the
cache `[V]`. Probes on the aspnet base image, under Rosetta:

- Inside a plain `RUN`, `/root/.cache/rosetta` already exists. Under QEMU
  it does not `[V]`.
- With `HOME=/dev/shm` the folder is `/dev/shm/.cache/rosetta`, and
  nothing appears under `/root` `[V]`.
- With a tmpfs on `/root/.cache` and `HOME=/root`, the folder is made
  inside the tmpfs. The step's layer is the empty layer, `4f4fb700…` `[V]`.

1. **Held, with a changed base stage.** Since the tag, the base stage's
   `RUN` also creates `/app/App_Data`, so the tip's layers are not the
   tag's. At the tip, Rosetta's layer is `e1b77a07…` (269 bytes) with
   `root/`, `root/.cache/` and `root/.cache/rosetta/`. QEMU's is
   `6aaac3e3…` (216 bytes) without them. At the tag the same builds give
   `e9ec63f8…` and `67cb4685…`, as on 23/11 `[V]`.
2. **Held, and the doubt did not come true:** the tmpfs on `/root/.cache`
   - At the tip, Rosetta's and QEMU's layers are both `6aaac3e3…`, the
     unchanged QEMU layer. No `root/` entry: the mount point BuildKit
     creates leaves nothing behind `[V]`.
   - More than the layer is unchanged. The image config and manifest
     equal those of the unchanged Dockerfile under QEMU, `17758551…`: the
     mount does not show in the image's history `[V]`.
   - At the tag, the change gives `67cb4685…` under both emulators,
     GHCR's `v0.0.0-thesis.6` layer, and the manifest of the unchanged
     QEMU build `[V]`.
3. **Held:** the tmpfs on `/root`. On the base stage it gives the same
   as 2, at the tip and at the tag `[V]`. It was not tried on the whole
   images.
4. **Held:** Rosetta follows `$HOME` (the probe above) `[V]`.
   - `ARG HOME=/dev/shm` before the `RUN` gives the same layer,
     `6aaac3e3…`, under both emulators.
   - But it changes the image config. The history records the argument
     (`3ee8c9a7…` against `17758551…`), so an x86-64 build with this
     change differs from one without it `[V]`.
5. **Held in part; there are more steps than expected.**
   - The release builds five images, the same five as for thesis.6
     (`03-release.yml`). No workflow builds
     `deployment/migrations/Dockerfile`: `01-pr-validation.yml` only
     requires that it exists `[V]`.
   - In the stages an image keeps, nine `RUN` instructions run, all as
     root, before the stage's `USER` line. None runs as another user.
     - `ws-pems`: the base stage's and the final stage's `RUN`, lines 8
       and 100.
     - `ws-pems-job-worker`: the base stage's, line 6. It is new since
       the tag: at the tag the job worker had no `RUN` that it kept, and
       it matched GHCR from the Mac on 23/11.
     - The three MCP images: the runtime stage's `apt-get` step (lines
       84, 69, 47) and one more each (lines 126, 100, 72). Those three
       run npm and then remove `/root/.npm`.
   - The other `RUN` steps are in build stages, whose layers no image
     keeps.
   - Without the change, each image's first root `RUN` holds Rosetta's
     three folders: `ws-pems` layer 8, the job worker's 7, and each MCP
     image's apt layer, 6 `[V]`. A later root `RUN` in the same or an
     inheriting stage adds nothing, because the folder already exists.
   - With the flag on the first step only, the folders move to the next
     one: `ws-pems` with line 8 alone has them in layer 11, the final
     stage's `RUN` (`3e275511…`) `[V]`. Every `RUN` in a kept stage needs
     the flag, not only the first.

**The whole images, with `--mount=type=tmpfs,target=/root/.cache` on all
nine:**

| Image | Rosetta, changed | QEMU, changed | QEMU, unchanged | Rosetta, unchanged |
| --- | --- | --- | --- | --- |
| `wspems-mcp-server` | `856c0da4…` | `856c0da4…` | `856c0da4…` | `44ae93bf…`, folders in layer 6 |
| `wspems-chat-server` | `6885cc5f…` | `6885cc5f…` | `6885cc5f…` | `1bece391…`, layer 6 |
| `wspems-mcp-auth-broker` | `43c88439…` | `43c88439…` | `43c88439…` | `c9a13136…`, layer 6 |
| `ws-pems` | `cfa1dac5…` | `cfa1dac5…`¹ | `cfa1dac5…`¹ | `20af858f…`, layer 8 |
| `ws-pems-job-worker` | `a39c40ee…` | not valid² | not valid² | `fbf070e2…`, layer 7 |

The digests are the `linux/amd64` image manifests, all `[V]`.

1. .NET crashes under QEMU (23/11), so `ws-pems` was not built whole
   there. Instead, QEMU went back into `rb1`, and the image was rebuilt
   with `--no-cache-filter=base,final`. The publish stage (`dotnet
   restore`, `dotnet publish`) came from the cache of the Rosetta build.
   Both `RUN` steps, and every step of the final stage, ran again under
   QEMU, each marked "DONE", not "CACHED", in the log.
2. The same pass for the job worker is no reference. Its base `RUN` ran
   again under QEMU, but the final stage's first step, `WORKDIR /app`,
   came from the cache despite the filter. So the image was put together
   on the earlier Rosetta build's chain, and the unchanged variant gave
   Rosetta's manifest. The job worker's x86-64 evidence is its base
   stage, built with `--no-cache` under both emulators (`7ebd1eb2…`).
   Layers 1-8 of that image equal layers 1-8 of the whole image built
   with the change under Rosetta. Layers 9-10 are a `WORKDIR` and the
   application `COPY`, and they are the same in Rosetta's builds with and
   without the change `[V]`.

No layer of any image built with the change holds a file or folder with
`rosetta` in its name, or a `.flu` file `[V]`. Outside Rosetta's three
folders, the unchanged images are the same under both emulators. This
includes the MCP images' apt layers, now that the tip installs from a
pinned Debian snapshot, and their node build stages (npm, the native
compile, the tests), which also ran under QEMU `[V]`.

## Interpretation

- The change that works, and the one I would give the branch: add
  `--mount=type=tmpfs,target=/root/.cache` after `RUN` on each of the
  nine instructions above, at `30b5c745d`:
  - `src/WebAPI/Dockerfile` 8 and 100;
  - `src/BackgroundJobExecutor/Dockerfile` 6;
  - `mcp/Dockerfile` 84 and 126;
  - `mcp/chat-server/Dockerfile` 69 and 100;
  - `mcp/auth-broker/Dockerfile` 47 and 72.

  Rosetta then writes its cache into a tmpfs that exists only while the
  step runs. On x86-64 nothing changes: QEMU gives the same image, byte
  for byte, with and without the flag, so neither GHCR's
  `v0.0.0-thesis.7` nor `arch`'s rebuild is affected. At the tag this
  holds against GHCR itself (`67cb4685…`).
- It is the narrowest of the three. A tmpfs on `/root` also works on the
  base stage, but it hides all of `/root` from the step, not just the
  cache. `ARG HOME` puts the argument into the image's history, so it
  changes the image everywhere.
- The rule it implies: every `RUN` in a stage an image keeps carries the
  flag. A later step does not inherit the fix: the first step without
  the flag makes the folder in its own layer.
  - For a `RUN` as another user, the target would be that user's
    `$HOME/.cache`; none exists today.
  - A guard in CI could check that each `RUN` in a kept stage has the
    flag `[I]`.
- The migrations image is not part of the release. If it is ever built
  on a Mac, its final stage's one root `RUN` needs the same flag `[I]`.
- Why the mount point leaves nothing behind is BuildKit's business: it
  removes the folder it created for the mount and keeps the parent's
  times. The tests show the effect `[V]`. The mechanism, and whether
  other BuildKit versions do the same, is `[I]`.

## Caveats

- QEMU stands in for x86-64. The link to a real x86-64 build is the tag:
  the change's layer and the unchanged QEMU layer equal GHCR's
  `67cb4685…`. Nothing at the tip was built on x86-64 here, since `arch`
  is busy.
- `ws-pems` under QEMU took its publish stage from the Rosetta build. So
  the 200 MB application layer is the same in all of its builds by
  construction, not by an independent run. That Rosetta's application
  layer equals x86-64's was shown at the tag on 23/11, not at the tip.
- One BuildKit (v0.33.1, pinned by digest) and one Rosetta (macOS 26.4.1)
  were tested. GitHub's runners use their own BuildKit. The Dockerfiles
  of `ws-pems`, the job worker and the broker have no `# syntax=` line,
  so BuildKit's built-in frontend parses them. It accepted the flag
  here. Docker's legacy builder would reject `--mount` `[I]`.
- Only `linux/amd64`, as the release builds.
- The tmpfs on `/root` and `ARG HOME` were tried on the WebAPI base stage
  only, not on the whole images.

## Not tested

- The change in the branch itself, built by the release workflow.
- A Mac rebuild of a release built with the change. That is the
  `v0.0.0-thesis.7` comparison this note prepares for.
