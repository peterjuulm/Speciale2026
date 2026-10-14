# Everything a release ships, and the parts not yet measured, 14 October 2026

## Question

Leo asked that everything WS ships be reproducible, or at least thought
through. What does a Phoenix release ship, how far is each part measured,
and what do the parts not measured yet give when built twice?

## The inventory

Read from the release workflow, its reusable workflows and the image
scripts on the WS branch at `fa60ea97` `[V]` (`03-release.yml`,
`00-reusable-windows-publish.yml`, `scripts/docker-build-push.sh`,
`scripts/docker-build-push-keycloak.sh`).

The GitHub Release of a tag carries:

- the two Linux zips (`publish-linux`): measured in layers 2 to 4 and `Z`;
  across machines the same but for W58 (dry run, 13/10);
- the two Windows zips (the reusable Windows publish, on Linux), signed:
  unsigned the same in two builds (W55) and across machines but for W58;
  signed, see [phoenix-signing](2026-10-14-phoenix-signing.md);
- the Linux migrator (`migration-bundles`): two builds the same (13/10),
  across machines but for W58; the Windows migrator, signed, as the
  Windows zips;
- the idempotent SQL script, `dotnet ef migrations script --idempotent`
  (`migration-bundles`): never measured (the bundle note says so);
- `upgrade.sh`, copied from `scripts/`: a source file;
- `SHA256SUMS`, written by the release job over all of the above with
  `sha256sum *.zip db/* upgrade.sh`: the glob's order follows the locale.
  It differs between two runs with the signed zips anyway.

The registry gets five images from `docker-images`, staged as
`<tag>-build` and promoted by the release job: the WebAPI and the job
worker (W56, fixed in `fa60ea97`, the same across machines in the dry run)
and three MCP images (`mcp/Dockerfile`, `mcp/chat-server/Dockerfile`,
`mcp/auth-broker/Dockerfile`), never measured. Since `fa60ea97` all five
get the commit's time and `rewrite-timestamp`.

Outside the release workflow, `scripts/docker-build-push.sh` builds and
pushes the WebAPI, the job worker and the migrations image
(`deployment/migrations/Dockerfile`), the last built nowhere else, with
neither the epoch nor `rewrite-timestamp`. `scripts/docker-build-push-keycloak.sh`
pushes a Keycloak image: Keycloak's own server with WS's theme and realm.

Not shipped: the docs site, the devcontainer, the Modbus simulator, the
CI runner's dashboard and the signing image, which is a tool of the
release job.

## Setup

Run by Claude at Leo's request, on `arch`, on `fa60ea97` (its build inputs
are `100e3912`'s; it changed the release workflow only). Four checks of
the parts never measured:

1. The SQL script as the release job writes it, twice, each in a fresh
   export: the second at another path, with `LC_ALL=et_EE.UTF-8` and
   another `TZ`. SDK 10.0.401 alone, the offline NuGet cache, an empty
   `HOME`.
2. The migrations image, built twice as `docker-images` builds the WebAPI
   image since `fa60ea97`: the commit's time in `SOURCE_DATE_EPOCH` and
   `rewrite-timestamp=true`, `--no-cache`, an OCI tarball; compared with
   `oci-diff.py`.
3. The three MCP images, the same way.
4. The order of `sha256sum *.zip db/* upgrade.sh` over the release's file
   names under `C.UTF-8`, `en_US.UTF-8`, `da_DK.UTF-8` and `et_EE.UTF-8`.

## Expectation, written before the checks

All `[I]`.

1. The two SQL scripts are the same file: EF writes literals with the
   invariant culture, and nothing in the script names a path or a time.
2. The two migrations images give the same manifest, as the WebAPI image
   does with the fix: the same pattern, an SDK image and a runtime image
   by digest, a locked restore, one publish, `COPY` and `RUN chmod`.
3. The MCP images differ, but only in what `apt-get` and `npm` log: dpkg's
   and apt's logs record the time of each install, npm writes a debug log
   named by the time. Their bases are named by tag only, but resolve to
   the same digest within the hour.
4. The same order under all four locales: no two names differ only in
   case or punctuation at the same place.

Added at 06:57, before checks 2 and 3, after checks 1 and 4 had run: on
Codex's advice the image files were changed first, so checks 2 and 3
measure them as WS would get them, not as `fa60ea97` has them. The three
MCP images now name their base by digest as well as tag, remove apt's
and dpkg's logs and ldconfig's cache in the step that installs, and
remove `/root/.npm` after every npm command in the final stage; the
migrations image and the two MCP files with a `syntax` line name the
Dockerfile frontend by digest. Expectation 3 is therefore not tested as
written. Instead:

3b. Each of the three MCP images gives the same image manifest twice.
    The npm installs are locked, the native `canvas` binary comes from
    the same prebuilt download, and what is left of apt is its package
    database, which records no times.

## Commands

Verbatim in `data/2026-10-14-phoenix-shipped/arch/kommando.txt`; the
images with `experiments/phoenix-rt/image-probe.sh`, extended today to
the migrations and MCP images.

## Result

`[V]` (scripts, logs and diffs in private data). Checks 1 and 4 06:33,
check 2 06:57-07:02, check 3b 07:02-07:07 and again 07:08-07:13.

1. Held. The two SQL scripts are one file, 21912 lines, sha256
   `6b201191…`, from exports at two paths, the second under
   `LC_ALL=et_EE.UTF-8` and `TZ=Pacific/Auckland`. `dotnet ef` ran on the
   SDK alone, as the new installer sets it up.
2. Held. Both builds of the migrations image give the image manifest
   `55e0fc48…`, all 9 layers the same.
3. Not tested as written (see the addendum).
3b. Failed on the first try. Each of the three images differed between
    its two builds, in one or two layers each:
    - MCP server: the runtime's apt layer in four fontconfig caches under
      `/var/cache/fontconfig`, and the final `RUN` layer in 450 files of
      Node's compile cache, `/tmp/node-compile-cache`, which npm turns on
      for its own runs;
    - chat server: the same compile cache, and in `node_modules` the
      vitest results file `node_modules/.vite/vitest/…/results.json`,
      written by `npm test` in the build stage: its 40 entries, one per
      test file, differ in their `duration` and in their order;
    - authorization broker: the compile cache, left by `npm ci` in the
      final stage.

    Added after the first try, at 07:07: the Dockerfiles also remove
    `/var/cache/fontconfig/*` where the fonts are installed,
    `/tmp/node-compile-cache` where npm runs in the final stage, and
    `node_modules/.vite` after the chat server's tests. Built twice again
    from a commit with those changes, each image gave the same manifest
    both times: MCP server `ad32e3b0…` (15 layers), chat server
    `6035b81e…` (12), authorization broker `8ce0153f…` (11).
4. Held for three locales: `C.UTF-8`, `en_US.UTF-8` and `da_DK.UTF-8` give
   the same order of the release's file names. `et_EE.UTF-8` is not
   installed as a C library locale on `arch`, so bash fell back to `C`
   there; that locale was not tested.

## Interpretation

**Every artefact the release ships now builds the same twice, but for
the signatures.** `[V]` for one machine: the zips, the migrators and the
two .NET images (13/10), the SQL script, the migrations image and the
three MCP images (today), the images compared by their manifests. The
signed Windows files differ by design and are checked by pasting
([phoenix-signing](2026-10-14-phoenix-signing.md)). The registry's
indexes around the images still differ: the release adds provenance
and an SBOM, which keep the build's own times (W56); the probe built
without them.

**Containers record their build in caches nobody asked for.** `[V]` None
of the MCP images' differences came from the application: a font cache,
a compiler cache and a test report, each written as a side effect of a
step that did something else. `npm` enabling Node's compile cache for its
own process was the least visible; it appeared in all three images.
Clamping file times (W56) cannot catch these, as they differ in their
contents. `[V]` for vitest's results: the durations and their order.
`[I]` for the two caches, whose contents were not decoded: fontconfig's
records the font folders' times, and V8's code cache need not come out
the same twice. `[I]` The rule generalises what the reproducible-containers
project's examples do for apt's logs and ldconfig's cache: remove what a
step writes besides its product, in the step that writes it.

**Two builds the same is not a rebuild later.** `[I]` The MCP images
install Debian packages from the live archive and name only their base
by digest. Built months later, `apt-get` gets newer packages, and the
image differs without any change in the repository. Pinning a snapshot
of the archive (snapshot.debian.org, as in `repro-sources-list.sh`) would
fix that, at the price of a dependency on that service at every build;
a decision for WS. The .NET images avoid it: they install nothing.

**The glob order holds by luck of the names.** `[I]` With the release's
names no two collations disagree, but nothing kept it so. `LC_ALL=C` in
the job makes it independent of the locale.

## Caveats

- One machine for checks 1-4; one day, so the apt archive did not move
  between the builds.
- The MCP images' fix was made between the two tries of check 3b, so
  its expectation was tested on the second try only.
- The migrations image was built as `image-probe.sh` builds images, with
  the settings the manual script now uses, not with the script itself.

## Not tested

- The manual image script end to end, and its push.
- A rebuild of the MCP images on another day, with the archive changed.
- The Keycloak image, which this note leaves out of the release's scope.
