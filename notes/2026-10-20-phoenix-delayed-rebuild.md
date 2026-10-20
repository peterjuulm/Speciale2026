# The reference release rebuilt six days later (20 October 2026)

Grounds: a second rebuild on `arch` of `v0.0.0-thesis.6`, compared with
the release published on 14/10 and its run's artifacts. Leo asked for
it on 20/10. Run by Claude.

## Question

Does `v0.0.0-thesis.6` still come out the same when it is rebuilt six
days after the release? The reference release's note left this open
under "Not tested"
([phoenix-reference-release](2026-10-14-phoenix-reference-release.md)).
Every output again: the frontend export, the zips, the migrators, the
SQL script, `SHA256SUMS`, and the five images by their `linux/amd64`
manifest.

## Setup

- The same tag and commit, `be5fc56e`, from the same clone,
  `/private/tmp/rb1-ci/src`. `ci-local.sh` and `ci-compare.sh` as of
  `fe4be3c` (14/10, after the first rebuild): the same build commands,
  plus the exit status and the frontend job clearing an old export.
- The same tools as on 14/10, the same files on disk: SDK 10.0.401 with
  runtime 10.0.12, Node v22.23.3, the same `zip`, buildx v0.38.0 and
  BuildKit v0.33.1 in the same builder container, and the same signing
  image (`environment.txt`).
- What changed: six days, and a reboot. The reboot emptied `/tmp`, so
  the NuGet cache starts empty and the locked restore downloads every
  package from nuget.org again. The npm cache in `/private/tmp/rb1-npm`
  is the one from 14/10, so the frontend installs offline as before.
- What the builds read from the network: NuGet, pinned by the lock files'
  hashes; the base images, pinned by digest; `npm ci` in the MCP images,
  pinned by their lock files; and `apt-get install` in the three MCP
  images, from Debian's live archive. Their Dockerfiles say it
  themselves: two builds give the same image only while the archive has
  not changed the packages.
- Compared with the release as on 14/10: the run's artifacts and the
  published `SHA256SUMS`, kept in private data, and the images on GHCR.

## Expectation, written before the run

Written 16:00.

1. All six jobs pass. The restore fills the empty NuGet cache from
   nuget.org.
2. Byte for byte, as on 14/10: the frontend export (994 files), both
   Linux zips, the Linux migrator and the SQL script; both Windows zips
   and the Windows migrator once the release's 177 signatures are
   pasted; and a `SHA256SUMS` made from the rebuilt files equals the
   published one. Nothing these builds read can have changed: the tools
   are the same files, and every package is pinned by its hash.
3. `ws-pems` and `ws-pems-job-worker`: the `linux/amd64` manifests equal
   GHCR's. They install nothing from Debian.
4. The MCP images are the same only if Debian has not changed a package
   they install since 14/10. `wspems-chat-server` and
   `wspems-mcp-auth-broker` install only `ca-certificates`, which seldom
   changes, so both are expected to be the same. `wspems-mcp-server`
   installs cairo, pango, librsvg, libjpeg-turbo, giflib and a font, and
   compiles native modules against a C toolchain and their `-dev`
   packages in its build stage, then copies `node_modules` over. It is
   the image most likely to differ. A difference is traced through the
   installed packages' versions first.

## Commands

Verbatim in `data/2026-10-20-phoenix-delayed-rebuild/arch/kommando.txt`.

## Result

`[V]` (`results.txt` and `environment.txt` in the data folder; the
rebuild, its logs and the comparisons in private data). All six jobs ran
16:01-16:18, 17 minutes.

1. Held. All six jobs passed, and the locked restore filled the empty
   NuGet cache from nuget.org.
2. Held. Byte for byte: the frontend export (994 files), both Linux zips,
   the Linux migrator and the SQL script; with the release's signatures
   pasted (2130 files, 114 folders), both Windows zips and the Windows
   migrator; and a `SHA256SUMS` made from the rebuilt files equals the
   published one. `ci-compare.sh`: 0 differ or failed.
3. Held. The `linux/amd64` manifests of `ws-pems` and
   `ws-pems-job-worker` equal GHCR's.
4. Held for all three MCP images, against the expectation's doubt about
   `wspems-mcp-server`: each manifest equals GHCR's, and each layer
   equals the rebuild of 14/10's. Debian changed none of the packages they
   install in the six days. On snapshot.debian.org, `bookworm`'s release
   file is the same file on 14/10 and 20/10; `bookworm-security`'s
   changed, but in packages these images do not install.

Found while checking where the MCP server image's files come from: its
canvas binary is downloaded at build time, without a checksum (W68). It
was the same file both days. See
[phoenix-mcp-pins](2026-10-20-phoenix-mcp-pins.md).

## Interpretation

**Six days, a reboot and an empty NuGet cache change nothing.** `[V]`
for this release. What the branch pins by hash or digest came back the
same: the SDK, the lock files' packages, the base images.

**The one input that can move did not, this time.** `[I]` Debian's main
archive took no update for `bookworm` in the window, and the security
updates that came missed the images' packages. That is the timing, not
the build: a point release, or a security fix to cairo, pango or librsvg,
changes the MCP server image, and `ca-certificates` all three (W67).

**The test is weak where nothing moved.** `[I]` A delayed rebuild shows
time-dependence only when the world changes in between. Here the
inputs that can change stayed put, so this run cannot tell a pinned input
from a lucky one. The pins note tests the Debian input directly, with an
older snapshot.

## Caveats

- One machine, the same tools on purpose (`environment.txt`). It does
  not show a rebuild on another machine after a delay.
- The frontend installed from the npm cache of 14/10, offline, so npm's
  registry was not asked again. The MCP images' `npm ci` runs with a
  BuildKit cache mount, which `--no-cache` does not empty, so their
  packages may have come from the builder's cache of 14/10 too `[I]`.
- Six days is short against Debian's update rhythm.

## Not tested

- A rebuild with every cache empty, BuildKit's cache mounts included.
- A rebuild with the network limited to an archive of the inputs.
- A rebuild after a Debian point release.
