# The reference release rebuilt on arch, six weeks later (24 November 2026)

Grounds: a rebuild on `arch` of `v0.0.0-thesis.6`, compared with what
GitHub's release workflow published on 14 October. Leo asked for it on
23 November ("Yes, rebuild today"). The first attempt that afternoon
stopped when `arch` went off the network. It was run again from the
start on the morning of 24 November, after `arch` was restarted ("Ja vi
tager arch i morgen tidlig"). It was run by Claude in a side session of
the writing session, over SSH in the tmux session `lab`, which Leo
watched. The other machine of the same comparison is the Mac Studio, on
23 November: see [phoenix-macstudio-rebuild](2026-11-23-phoenix-macstudio-rebuild.md).

## Question

Six weeks after GitHub published `v0.0.0-thesis.6`, does `arch` rebuild
all of it from empty caches and get identical files? The outputs are:

- the frontend export;
- both Linux and both Windows zips;
- both migrators;
- the SQL script and `upgrade.sh`;
- a `SHA256SUMS` made from the rebuilt files;
- the five images, by their `linux/amd64` manifest against GHCR.

`arch` did the same on 14 October, alongside the release, and on
20 October, six days after it
([phoenix-delayed-rebuild](2026-10-20-phoenix-delayed-rebuild.md)).

## Setup

- `arch`: Leo's Arch laptop (`leo-21h8s0ap01`), x86-64, glibc 2.44,
  64 GB. Restarted at about 08:40 on 24/11, now on kernel 7.3.4-arch1-2
  (7.2.11-arch1-1 on 23/11), with about 57 GB available when the rebuild
  started.
- The tag `v0.0.0-thesis.6`, commit `be5fc56e`. As on 14 and 20 October,
  each job takes its own shallow clone of the tag in
  `/private/tmp/rb1-ci/<job>`, with origin set to GitHub's URL. The
  source of the clones is a `git clone --shared` of Leo's clone in
  `/private/tmp`, so Leo's own checkout is not touched.
- Scripts from `dotnet-rebuild-experiments` (`1-ws-pems/scripts/5-release/local-vs-github-comparison/`
  at `d991fc5`): `rebuild.sh`, `compare.sh` and `ghcr-manifests.py`.
  These were `ci-local.sh` and `ci-compare.sh` in October.
- Tools:
  - SDK 10.0.401 (runtime 10.0.12), installed that day in
    `~/rb1-dotnet-10.0.401` by the branch's `install-dotnet-sdk.py`. The
    archive's SHA-512 was checked against `dotnet-sdk.lock.json`. It is a
    new download, not October's folder.
  - Node 22.23.3 with npm 10.9.9, from nodejs.org, checked against the
    SHA-256 of `node.sha256`. The tag's frontend job used setup-node's
    build of the same version.
  - BuildKit v0.33.1 as the builder `rb1`, as in October.
  - The signing image `ws-signing:rb-ref6` of 14 October, for pasting
    signatures.
- **Caches empty:**
  - NuGet: on 23/11, `rebuild.sh`'s NuGet folder `/tmp/dch` (5.3 GB) was
    moved aside, and `/tmp/dch` became a link to an empty folder on disk,
    `/private/tmp/rb1-dch`. `/tmp` is in RAM on `arch`, and the memory
    guard counts it. The interrupted attempt filled 5.2 GB of it, so on
    24/11 it was emptied again before the run. The restart had removed
    the link, so it was made again.
  - npm: on 23/11 the old cache `/private/tmp/rb1-npm` was moved aside.
    On 24/11 the cache filled for the interrupted attempt was moved aside
    too, and a new one was filled by an online `npm ci` of the tag's lock,
    with the tag's npm (10.9.9): 1343 packages, 274 MB. Then
    `rebuild.sh`'s frontend job installs from it offline.
  - BuildKit builds with `--no-cache`. The base images are pulled by
    digest.
- **What GitHub published:** the release's nine assets, downloaded that
  day with `gh release download` and laid out as `compare.sh` expects
  the run's artifacts: `release-zips-linux`, `release-zips-windows`,
  `db-migration-bundles-linux`, `db-migration-bundles-windows` and
  `sha256sums`. The run's own artifacts expired after 1-5 days, so two
  are missing:
  - `frontend-export`: the export is inside both Linux zips.
  - The image artifacts: the images are compared with GHCR.
- Every heavy job runs under `arch`'s shared memory guard,
  `/tmp/claude-1000/ws-mem-run.sh` (one heavy job at a time, a systemd
  scope with MemoryMax). The images run in BuildKit, under the guard's
  lock. The restart emptied `/tmp`, so the guard was gone. It was put back
  from the version the Arch setup session last wrote, read from that
  session's transcript (SHA-256 `db14855a…`, in `environment.txt`).
- What the interrupted attempt of 23/11 produced (the frontend export and
  its log) was moved aside, so nothing of it is in today's outputs.

## Expectation, written before the run

Written on 23 November at 16:25, before any part of the first attempt
ran, and left unchanged for the second. Since then, the Mac Studio's
rebuild that evening found the MCP images' apt layers changed
([phoenix-macstudio-rebuild](2026-11-23-phoenix-macstudio-rebuild.md)).
That result was known before this run; expectation 4 is not revised.

1. All six jobs pass, from the empty NuGet cache and the new npm cache.
2. Byte for byte, as on 14 and 20 October:
   - both Linux zips, the Linux migrator, the SQL script and `upgrade.sh`;
   - with the release's signatures pasted, both Windows zips and the
     Windows migrator;
   - a `SHA256SUMS` made from those files equal to the published one.

   The packages come from nuget.org and the npm registry again, but the
   lock files name each by hash.
3. The `linux/amd64` manifests of `ws-pems` and `ws-pems-job-worker`
   equal GHCR's.
4. The three MCP images may differ from GHCR. At this tag their
   Dockerfiles run `apt-get update` against Debian's live archive (the
   snapshot pins came on 20/21 October). Five weeks give Debian time for
   security updates or a point release in the packages they install
   (W67). The base image is pinned by digest. A difference is then in
   the apt layers, and it is traced by package version.

## Commands

Verbatim in `data/2026-11-24-phoenix-arch-rebuild/arch/kommando.txt`.

## Result

`[V]` throughout, from `results.txt`, `compare.txt`, `images-ghcr.txt`
and the lab logs in `data/2026-11-24-phoenix-arch-rebuild/arch/`. The
rebuild's own files stay on `arch` in `/private/tmp/rb1-rebuild6`, not in
git.

**The first attempt, 23/11.** It started at 17:07 in `lab`, under the
guard. The frontend job passed (17:07-17:13). The Linux job was
restoring when `arch` went off the network, between about 17:30 and
17:40: SSH timed out, then "Host is down", and ping got no reply. That
afternoon the battery was at 3 % on AC, and a systemd inhibitor had kept
the machine awake. Its outputs were set aside on 24/11, unused.

**The run, 24/11.** Started at 08:49:52.

1. Held, with one rerun.
   - The frontend, Windows, migrator, SQL and images jobs passed on the
     first try.
   - The Linux job did not: its restore failed with `NU1301`. Over 17
     minutes, nuget.org's service index timed out after 100 seconds,
     seven times, and the six projects "Failed to restore". No build
     ran.
   - The Windows job started right after (09:10) and restored from
     nuget.org without trouble.
   - So the Linux job ran again alone (09:28-09:32), from an empty NuGet
     folder once more. The 5.3 GB the other jobs had filled was set
     aside. Just before, nuget.org's index answered in 0.2 seconds. It
     passed with no `NU1301`.
2. Held: byte for byte.
   - Both Linux zips (`4c0d6362…`, `202f5b5d…`), the Linux migrator
     (`596a26c4…`), the SQL script (`6b201191…`) and `upgrade.sh`.
   - With the release's signatures pasted (2130 files, 114 folders), both
     Windows zips and the Windows migrator.
   - A `SHA256SUMS` made from the rebuilt files: all eight lines equal
     the published file.
   - The frontend export's 994 files are the files at the same paths in
     the published Linux zip's `wwwroot/`. `compare.sh` reports the export
     itself as missing, because the run's artifact has expired.
3. Held. The `linux/amd64` manifests of `ws-pems` (`e097c1aa…`) and
   `ws-pems-job-worker` (`a0d51db3…`) are GHCR's. The five GHCR index
   digests are those recorded on 14/10 and 20/10, so the tags have not
   moved.
4. Held as the expectation said: the three MCP images differ, in the apt
   layer only.
   - In each image one layer differs, the runtime stage's
     `apt-get install`. The config differs only in that layer's
     `diff_id`. Every other layer is GHCR's.
   - Five packages are newer than on 14/10:
     - `ca-certificates` `20250419~deb12u1` → `deb12u2`, and `openssl`
       and `libssl3` `3.0.22-1~deb12u1` → `deb12u2`, in all three;
     - in `wspems-mcp-server` also `libexpat1` `2.5.0-1+deb12u4` →
       `deb12u5` and `libbrotli1` `1.0.9-2+b6` → `1.0.9-2+deb12u1`.
   - Every differing entry belongs to one of those packages, or is
     something they produce:
     - the files `update-ca-certificates` writes, and
       `etc/ca-certificates.conf`;
     - dpkg's and debconf's records;
     - in `mcp-server`, the two `libexpat` paths no `.list` file names.
   - 218 entries differ in `mcp-server` and 199 in the other two, which
     share the layer.
   - Six entries exist only in GHCR's layers: the two root certificates
     the new `ca-certificates` drops (Comodo AAA Services, emSign ECC
     Root CA G3), with their links.
   - The new packages' files are dated 14/10 07:02:26 UTC, the commit's
     time, which `rewrite-timestamp` gives to anything newer. GHCR's
     files keep their packages' own dates.

**`arch` against `macstudio`.** The Mac Studio rebuilt the same tag the
evening before
([phoenix-macstudio-rebuild](2026-11-23-phoenix-macstudio-rebuild.md)).
Every release file there was identical too. For the images:

- The Mac found the same five packages.
- Its apt layers differ from `arch`'s in exactly three entries, the
  empty folders `root/`, `root/.cache/` and `root/.cache/rosetta/` that
  Rosetta wrote on the Mac.
- Every other entry of the two machines' apt layers is equal, in type,
  mode, owner, time, size and content, and in order: 2229 entries in
  `mcp-server`, and 547 in `chat-server` and `auth-broker`.
- The same holds in `ws-pems`'s layer 7, the one that differed on the
  Mac: on `arch` the whole image is GHCR's.

## Interpretation

**Six weeks later, the release's files come out the same on `arch`.**
`[V]` for `v0.0.0-thesis.6`:

- the frontend export, all four zips, both migrators, the SQL script,
  `upgrade.sh` and `SHA256SUMS`;
- every NuGet and npm package downloaded again into empty caches;
- an SDK installed that day, kernel 7.3.4 against October's 7.2.9, and
  Docker 29.9.3 against 29.9.1 on 20/10. The zip binary, BuildKit and
  the signing image are October's.

It is the third time on `arch`: on 14/10 alongside the release, on
20/10, and now. With the Mac Studio on 23/11, that makes two machines,
two operating systems and two processors in the same week, with the same
answer.

**The images say the same as on the Mac, without the emulator.** `[V]`

- `ws-pems` and `ws-pems-job-worker` are GHCR's, manifest for manifest.
- The MCP images differ for one reason only: Debian's security archive
  moved five packages after 20/10 (W67, the live archive). At this tag
  the Dockerfiles installed from the live archive. The branch has since
  pinned a snapshot date (E1-S6-05).
- Both rebuilders, a day apart, got byte-identical package files from
  Debian. So the difference from GHCR lies in the input, not in either
  build.

`[I]` A rebuild of the tag's MCP images against Debian's archive as it
was on 14/10 should give GHCR's manifests. Not run.

**A network failure is not a difference.** `[V]` The Linux job's first
try stopped before it built anything, on nuget.org's service index. That
is the verifier's availability problem, not reproducibility. The rerun
from an empty NuGet folder gave the same bytes. `[I]` A verifier needs
the registries online, or a cache filled earlier. NuGet's 100-second
timeout with 17 minutes of retries is what a flaky network costs.

## Caveats

- One run of each job on `arch`, apart from the Linux job's two. The
  first of those failed in restore and built nothing.
- The Linux job's NuGet folder was empty, as the other jobs' was. But
  between its two tries the Windows, migrator and SQL jobs had fetched
  the same packages from nuget.org. The network failure's cause was not
  found.
- The npm cache was filled online at 08:48 by `npm ci` with the tag's
  npm, so the frontend job installed offline, as in October.
- The export is compared with the published Linux zip's `wwwroot/`, not
  with the run's artifact, which has expired. The zip that holds it is
  identical too.
- The memory guard was put back by hand after the restart, from the Arch
  setup session's transcript. Its hash is in `environment.txt`.
- The BuildKit builder `rb1` was the October container (v0.33.1, digest
  `cec9f139…`). It started again after the restart. The builds ran with
  `--no-cache`.

## Not tested

- The MCP images against Debian's archive of 14/10, which would separate
  the archive's change from the build.
- Installing or running the release.
- A second full rebuild on `arch` the same day.
