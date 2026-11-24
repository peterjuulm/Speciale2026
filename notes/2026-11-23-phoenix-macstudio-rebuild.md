# The reference release rebuilt on the Mac Studio, five weeks later (23 November 2026)

Grounds: a rebuild on `macstudio` of `v0.0.0-thesis.6`, compared with
what GitHub's release workflow published on 14/10. Leo asked for it on
23/11 ("Yes, rebuild today"), including a small Docker environment on
this Mac for the images. Run by Claude in a side session of the writing
session.

## Question

Five weeks after GitHub published `v0.0.0-thesis.6`, does a second
computer of ours, of another operating system and processor, rebuild all
of it and get identical files? Every output: the frontend export, both
Linux and both Windows zips, both migrators, the SQL script,
`upgrade.sh`, a `SHA256SUMS` made from the rebuilt files, and the five
images by their `linux/amd64` manifest against GHCR. The earlier Mac
rebuild (21/10) covered the frontend and the Linux zips only.

## Setup

- `macstudio`: Leo's Mac Studio, Apple M2 Max (12 cores, 32 GB), macOS
  26.4.1 on arm64. A new machine name in these notes; it is not Peter's
  `mac`.
- The tag `v0.0.0-thesis.6`, commit `be5fc56e`, read from Leo's clone
  `~/Dev/Weel-Sandvig/WS.Phoenix` without a change to it. As in the three
  earlier rebuilds, each job takes its own shallow clone of the tag in
  `/private/tmp/rb1-ci/<job>`, outside any other repository, with origin
  set to GitHub's URL. A clone and not `git archive`: GitHub built in a
  checkout, and the release's assemblies carry the commit.
- Scripts: `rebuild.sh`, `compare.sh` and `ghcr-manifests.py` from
  `dotnet-rebuild-experiments` at `d991fc5`
  (`1-ws-pems/scripts/5-release/local-vs-github-comparison/`). They run
  the same commands as `ci-local.sh` and `ci-compare.sh` here; the files
  differ in comments and the path to `oci-diff.py` only. One change, in a
  copy: the npm cache `/private/tmp/rb1-npm` becomes
  `/private/tmp/rb1-ms-npm`, because the old path on this Mac holds
  another session's cache.
- Empty caches: the NuGet cache `/tmp/dch` does not exist before the run;
  the npm cache is a new, empty folder. The frontend job installs offline,
  so the cache is first filled from the registry by `npm ci
  --ignore-scripts` in a scratch clone of the tag, as on 21/10. The
  BuildKit builder is new, so its cache mounts start empty too.
- SDK 10.0.401 (runtime 10.0.12) installed with the tag's own
  `scripts/install-dotnet-sdk.py` into `/private/tmp/rb1-ms-dotnet`, its
  SHA-512 checked against Microsoft's metadata. The tag's installer fails
  on macOS's `/usr/bin/python3` 3.9.6 (W70, fixed on the branch after the
  tag), so it ran on uv's CPython 3.12.16.
- Node 22.23.3, as the tag's `.nvmrc` says, for darwin-arm64 from
  nodejs.org, checked against `SHASUMS256.txt`. The tag pins no npm, so
  npm is Node's own 10.9.9.
- Packing: two small Python shims for GNU `realpath -m` and `touch -d @N`
  in `/private/tmp/rb1-tools`, plus links to `/bin/chmod` and `/bin/rm`,
  as on 21/10 (rewritten today; hashes in `environment.txt`). `zip` is
  Apple's `/usr/bin/zip`.
- Docker, installed today without Homebrew or an administrator: colima
  0.10.3 and Lima 2.3.0 (a `vz` VM, aarch64, with Rosetta registered for
  x86-64 binaries), the Docker CLI 29.10.0 and buildx 0.38.0, the
  programs in `/private/tmp/rb1-ms-docker`, each checked against its
  publisher's checksum where one exists. The VM itself lives in
  `~/.colima`, and only the home folder is shared with it. The builder `rb1` runs
  `moby/buildkit:v0.33.1`, the version CI's builder had on 14/10.
  `DOCKER_DEFAULT_PLATFORM=linux/amd64` makes the unchanged script build
  for `linux/amd64`: every `RUN` step executes x86-64 code under Rosetta.
- The signing image for the paste is built from the tag's
  `deployment/signing`, for arm64; it only cuts and pastes signatures.
- Compared with the release's assets, `gh release download` today. The
  run's artifacts have expired, so the frontend export is compared with
  `wwwroot/` in the release's Linux WebAPI zip, as on 21/10, and
  `upgrade.sh` with the asset directly. The images with GHCR through
  `ghcr-manifests.py`.
- What the builds read from the network today: NuGet and npm packages,
  pinned by the lock files' hashes; base images, pinned by digest; and
  Debian's live archive in the three MCP images. Before the run,
  snapshot.debian.org resolves `bookworm`'s `InRelease` on 23/11 to the
  same file as on 14/10 (`736a99b8…`), and `bookworm-security`'s to a
  different one (`b0a1cf2a…` against `5377dcc5…`).

## Expectation, written before the run

Written 16:10, before any build.

1. All six jobs pass on macOS arm64, the images job under Rosetta. The
   locked restore fills the empty NuGet cache from nuget.org. The risk is
   the images: `dotnet publish` and the MCP images' `npm ci` run as
   x86-64 code under emulation.
2. The frontend export: the release's 994 files, byte for byte. `[I]`
   It held on Peter's Mac on 21/10 with the same Node and SWC binary, and
   every package is pinned by the lock's integrity hash.
3. Both Linux zips, the Linux migrator, the SQL script and `upgrade.sh`:
   byte for byte. `[I]` The zips held on 21/10 on macOS; the migrator and
   the SQL script come from the same compiler, runtime and packages.
4. Both Windows zips and the Windows migrator, once the release's 177
   signatures are pasted: byte for byte. `[I]` Never built on macOS
   before. The win-x64 apphost and single-file bundle are made by the SDK
   on any host, and `arch` (Linux) already matched the office runner
   (Windows).
5. A `SHA256SUMS` made from the rebuilt files equals the published one.
6. `ws-pems` and `ws-pems-job-worker`: the `linux/amd64` manifests equal
   GHCR's. `[I]` They install nothing from Debian; the compiler's output
   does not depend on whether x86-64 instructions run natively or
   translated.
7. The three MCP images are the same only if Debian has not changed a
   package they install since 14/10. `bookworm` has not moved, but
   `bookworm-security` has. `wspems-mcp-server` installs cairo, pango,
   librsvg and their libraries, the most likely to have taken a security
   fix, so it is the one most likely to differ. `wspems-chat-server` and
   `wspems-mcp-auth-broker` install only `ca-certificates`; expected the
   same. A difference is traced to its layer, file and package version.

## Commands

Verbatim in `data/2026-11-23-phoenix-macstudio-rebuild/macstudio/kommando.txt`.

## Result

`[V]` (`results.txt` and `environment.txt` in the data folder; the
rebuild, its logs, the downloaded release and the image files in
`/private/tmp/rb1-ms`, not in git).

Three things went wrong on the way, none of them in the build:

- The first try stopped in two jobs at once: `next[@]: unbound
  variable`. macOS's `/bin/bash` is 3.2, which treats an empty array as
  unset under `set -u`; Peter's Mac on 21/10 ran the script as of
  `fe4be3c` (its `environment.txt`), before `23a5711` added those arrays. Fixed in the copy with `${a[@]+"${a[@]}"}`, the same
  commands (`rebuild-sh.diff`). The second try ran 16:10:57-16:17:29,
  6 minutes 32 seconds.
- BuildKit did not count `linux/amd64` among its platforms under Rosetta
  (it listed `linux/arm64, linux/386`), so it ran every x86-64 step under
  its own bundled QEMU, not Rosetta: `.buildkit_qemu_emulator -0 sleep
  /bin/sleep 8` in the VM's process list. Its x86-64 emulator was moved
  aside in the builder container (not the image), and the same step then
  ran as `/mnt/lima-rosetta/rosetta /bin/sleep 8`.
- The first image try stalled in `ws-pems`'s `dotnet restore`: NuGet's
  downloads "timed out because no data was received for 60000ms", 57
  times in three minutes, while the VM fetched a test file at a tenth of
  the host's speed and the host's own release download failed ("can't
  assign requested address"). After a restart of the VM the same file
  came at 4.8 MB/s, and the second try's restores went through.

1. Held for the five release jobs: all passed on macOS arm64, and the
   locked restore filled the empty NuGet cache from nuget.org (4.1 GB).
   The images: see 6 and 7.
2. Held. The frontend export's 994 files are the files at the same paths
   under the release's `wwwroot/`, byte for byte. (`wwwroot/` holds 1057
   files; the other 63 are the backend's, under `Identity/`.)
3. Held. Byte for byte: `ws-pems-linux-x64` `4c0d6362…`,
   `ws-pems-job-worker-linux-x64` `202f5b5d…`, the Linux migrator
   `596a26c4…`, the SQL script `6b201191…` and `upgrade.sh`, each the
   hash GitHub lists for the asset and the published `SHA256SUMS`.
4. Held. With the release's 177 signatures pasted (2130 files, 114
   folders, 0 failed), both Windows zips and the Windows migrator equal
   the release's, byte for byte: the first build of the Windows release on
   macOS.
5. Held. The `SHA256SUMS` made from the rebuilt files equals the
   published one, all eight lines. `compare.sh`: 0 differ or failed.
   The PDBs record the compiler `5.9.0-1.26423.113+e34a38d2…` on runtime
   `10.0.12-servicing.26422.108+95017c71…`, as on 21/10.

The images, built 16:20:38-16:38:06 under Rosetta, all five jobs passed
(1 held for them too). The reference is GHCR read live today, with a
`read:packages` token Leo added during the run. All ten tags (each image
and its `-build` tag) give the index and `linux/amd64` image digests
recorded on 14/10 and 20/10, compared digest by digest: the tags have
not moved since the release.

6. Held for `ws-pems-job-worker`, not for `ws-pems`.
   - `ws-pems-job-worker`: the `linux/amd64` manifest is GHCR's,
     `a0d51db3…`.
   - `ws-pems`: `08b930c4…` against GHCR's `e097c1aa…`. Nine of its ten
     layers are GHCR's, the 226 MB application layer among them. Layer 7,
     the base stage's `RUN mkdir … && chown` run as root, has three
     entries more: `root/` (0700), `root/.cache/` and
     `root/.cache/rosetta/`, empty folders. The image config differs only
     in that layer's `diff_id`.
   - The cause, by a control: the base stage alone (`--target base`)
     under Rosetta gives the layer `e9ec63f8…` (235 bytes) with the three
     folders; under BuildKit's own QEMU, in a second, unchanged builder of
     the same BuildKit image, it gives `67cb4685…` (183 bytes), GHCR's
     layer 7 exactly. Rosetta, the emulator, creates its cache folder in
     the home of the user it runs as, here `/root`, and the step's layer
     keeps it (`[I]` for the mechanism; the control shows the effect). `job-worker`'s final stage runs nothing, so nothing of
     Rosetta's reaches it.
   - The whole `ws-pems` image under QEMU could not be built, with
     either of two QEMUs. BuildKit's own (10.2.3): in `dotnet restore`
     the emulated MSBuild crashed (`qemu: uncaught target signal 11
     (Segmentation fault)`), and the restore then hung, one process at
     2 % CPU for five minutes, until stopped. The VM's (7.0.0, made the
     kernel's x86-64 handler in Rosetta's place, 16:43-17:14): MSBuild
     died after 2.9 seconds with `System.AccessViolationException`, and
     the restore then sat idle for 30 minutes, until stopped.
7. Did not hold, as the expectation's doubt said, and wider than it
   said: all three MCP images differ, `chat-server` and `auth-broker` as
   well as `mcp-server`.
   - In each, one layer differs, the runtime stage's `apt-get install`
     (layer 5). Every other layer is GHCR's, the `node_modules` and `dist`
     layers built by `npm ci`, the native compile and the tests under
     Rosetta among them.
   - The layer's packages, GHCR against today: `ca-certificates`
     `20250419~deb12u1` → `deb12u2`, `openssl` and `libssl3`
     `3.0.22-1~deb12u1` → `deb12u2` in all three; in `mcp-server` also
     `libexpat1` `2.5.0-1+deb12u4` → `deb12u5` and `libbrotli1`
     `1.0.9-2+b6` → `1.0.9-2+deb12u1`.
   - Every differing entry of the layer belongs to one of those packages
     (their files; the certificate links `update-ca-certificates`
     writes; dpkg's and debconf's own records), or is one of Rosetta's
     three folders. The new `ca-certificates` drops two roots, Comodo AAA
     Services and emSign ECC Root CA G3, so their six entries exist only
     in GHCR's layer. 221 entries in `mcp-server`, 202 in the other two.
     `chat-server` and `auth-broker` share the layer, one digest on each
     side.
   - The new versions reached `bookworm-security` between 20/10 21:13 UTC
     (`ca-certificates`) and 26/10 (`openssl`), on snapshot.debian.org:
     all after the delayed rebuild of 20/10, which matched.

## Interpretation

**Five weeks later, on another operating system and processor, the
release's files come out the same.** `[V]` for `v0.0.0-thesis.6`: the
frontend export, all four zips, both migrators, the SQL script,
`upgrade.sh` and `SHA256SUMS`, 2130 Windows files with the release's
signatures pasted. This is the first full rebuild of the release's files
on a machine other than `arch`, and the first of the Windows release on
macOS. Every NuGet and npm package came from the registries today, into
empty caches.

**The images say less, and for two reasons outside the build.** `[V]`
- One is time: Debian's security archive changed five packages the MCP
  images install. That is W67, the live archive, which the WS branch has
  since pinned to a snapshot date (`f073bf5e4`); the tag predates the
  fix. A rebuild of the tag from 14/10's archive would be the test of
  the rest, not run here.
- The other is the emulator: Rosetta writes its cache folder into any
  layer whose `RUN` step runs as root, so an Apple Silicon rebuild of
  these Dockerfiles under Rosetta can never match an x86-64 build. It is
  the rebuilder's environment, not the release, but a verifier on a Mac
  meets it first. A new cause, not yet numbered in the findings table.
- Everything else in the images is the same: `job-worker` whole, and
  every layer of the other four outside the apt layer and Rosetta's
  folders, including the application layers built by `dotnet publish`,
  `npm ci`, a native compile and the tests, all run as x86-64 code
  translated by Rosetta.

**Emulation is a choice with consequences.** `[I]` QEMU, the default
BuildKit falls back to, gives the right bytes for a small step (the
control) but cannot run the .NET SDK here, in either version tried;
Rosetta runs it, at the cost above. A Mac can therefore verify the `ws-pems` image only by layer, not
by manifest, unless the Dockerfiles change (a non-root build user, or
removing `/root/.cache` in each root step) or BuildKit runs on x86-64.

**For the thesis's table.** `[I]` On two computers of ours five weeks
apart (pending the Arch run of the same day), the release's files are
identical; the images match where the build controls the inputs, and
differ, traceably, where the tag left an input open (Debian) or the
verifier's emulator adds files (Rosetta).

## Caveats

- One Mac, one run. The release files were compared once; no second
  build on this machine.
- The frontend export is compared with the release's `wwwroot/`, not
  with the run's artifact, which has expired. The zip that holds it is
  compared byte for byte too, so the export is covered twice.
- Three things here are not the release job's: the rebuild script's
  bash-3.2 fix (`rebuild-sh.diff`, the same commands), the packing shims
  for GNU `realpath -m` and `touch -d` (`rb1-tools-shims.txt`), and
  Apple's `zip`. The zips came out the same, so none changed a byte.
- The builder container was changed by hand (its x86-64 QEMU moved
  aside) so that Rosetta ran the steps. The BuildKit image itself is the
  pinned v0.33.1.
- `ws-pems` and the MCP images were not compared by manifest without
  Rosetta. The claim that QEMU would give GHCR's manifest rests on the
  base-stage control and on the other layers being the same; it is
  `[I]` for the whole image.
- The npm cache was filled from the registry by `npm ci
  --ignore-scripts` before the frontend job, as on 21/10, so the job
  itself installed offline. The NuGet cache was filled by the first try's
  migrator job; the second try's jobs reused it, on the same day.
- The image builds started from an empty BuildKit cache, but the
  stopped first try had already pulled the .NET base images into it.
  Pinned by digest, they are the same bytes either way.
- The first image try stalled on the VM's network, and the host's
  release download failed at the same time. The cause was not found; a
  restart of the VM cleared it.
- The tag's SDK installer did not run on macOS's own Python 3.9 (W70,
  fixed on the branch); uv's Python 3.12 ran it.

## Not tested

- The images by manifest under QEMU, or on an x86-64 Mac or Linux host.
- The MCP images with Debian pinned to 14/10 (the branch's snapshot
  fix, W67), which would separate the archive's change from the build.
- Installing or running the release.
