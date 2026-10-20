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
