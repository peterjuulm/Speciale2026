# Phoenix: the release on .NET 10

Experiment note, 12 October 2026, on `arch`. Private data in Leo's
`speciale-2026/data/phoenix-net10-release/arch-2026-10-12/`; the public
part will be in `data/2026-10-12-phoenix-net10-release/arch/`. Phoenix source
and build output do not land in this repo. Expectation written before the
first run.

## Question

The WS branch moved to .NET 10 at `332752b9`: SDK 10.0.401 pinned in
`global.json`, every workflow installing exactly that SDK, the projects on
`net10.0` with the Microsoft packages at 10.0.12. Every hash measured
before, the release `b72bbc3b…` and the zips, was made with SDK 9.0.120, a
different compiler (Roslyn 4.12; SDK 10.0.401 ships Roslyn 5.9, its
`CompilerApiVersion`). Two questions:

1. Is the whole release, and are its normalised zips, still reproducible on
   .NET 10?
2. Does the locale defect W26 remain? Roslyn 4.12 ordered the types it
   generates for collection expressions with a culture-sensitive sort;
   Roslyn's `main` sorted them ordinally when we looked on 24/9.

The WS-side compatibility check of the move (build, all tests, EF model)
is in Leo's private notes; it was green before this run.

## Setup

- `experiments/phoenix-rt/run.sh Z` as in
  [phoenix-zip](2026-10-12-phoenix-zip.md): the whole release in one build,
  frontend included, then the zips as CI packs them and normalised. New:
  `DOTNET_DIR` selects the SDK, here Microsoft's 10.0.401
  (`dotnet-sdk-linux-x64.tar.gz`, SHA-512 checked against Microsoft's
  release metadata) unpacked in `/private/tmp/rb1-dotnet10/sdk`.
- The lab is a fresh export of `332752b9`. `ZEPOCH` is its commit time,
  `1791824287`.
- Three runs: `none`; `all` with `APP_VERSION` and `LC_ALL=C.UTF-8` in
  `FIXENV`, as the release's Linux jobs set them; `locales` with
  `APP_VERSION` only, so the experiment builds under `et_EE.UTF-8`.

## Expectation, written before the run

All `[I]` until measured.

1. `Z-none`: the release's two builds are identical, the normalised zips
   too; the CI zips differ, as on .NET 9 (W48).
2. `Z-all`: the same.
3. `Z-locales`: the release is identical under Estonian without the pin,
   because Roslyn 5.9 sorts those generated types ordinally. If it differs
   in the four assemblies as W26 did, the fix has not reached the SDK and
   the pin is still needed.
4. The release has a new hash, not `b72bbc3b…`: a new compiler, new
   packages and `net10.0`.

## Commands

Run by Claude at Leo's request, in bash. Verbatim in `kommando.txt`.

## Result

`[V]` (`summary.tsv`, the stores' hash lists, the normalised zips read with
Python's `zipfile`, the samples):

| Run | Start-end | Exit | Release files that differ | Job worker zip | WebAPI zip |
| --- | --- | --- | --- | --- | --- |
| `Z-none` | 19:05-19:24 | 1 | 1 of 2245 | identical | differs |
| `Z-all` | 19:24-19:41 | 1 | 6 of 2245 | identical | differs |
| `Z-locales` | 19:41-19:59 | 1 | 1 of 2245 | identical | differs |

- The job worker's normalised zip is the same in all six builds,
  `10d3348587d9252c`, 501 entries. The WebAPI's normalised zips differ in
  exactly the files that differ in the release. The CI zips differ in every
  run, as on .NET 9 (W48).
- The file that differs in all three runs is
  `WebAPI.staticwebassets.endpoints.json`, the manifest of the WebAPI's
  static web assets. It lists 311 endpoints, all for the 63 files the ASP.NET
  Core Identity UI package (10.0.12) brings. 248 endpoints differ between
  the two builds of a run, and only in their `Last-Modified` header: the 124
  with `Content-Encoding: gzip` and the 124 with `br`. Their value is the
  time of that build, to the second, for example 17:11:48 and 17:21:26 UTC
  in `Z-none`. The 63 endpoints without an encoding carry the package's own
  date, `Sat, 22 Aug 2026 13:49:22 GMT`, in every build.
- On SDK 9.0.120 the same manifest had 311 endpoints too, all with one date,
  `Tue, 29 Oct 2024 13:06:48 GMT`, the file time of the Identity UI 9.0.0
  package in the NuGet cache (store of `Z-all` in
  [phoenix-zip](2026-10-12-phoenix-zip.md)).
- `Z-all` also differs in five frontend files. Every build's export holds two
  byte-identical chunk files whose names differ only in the leading chunk
  id, 7363 and 9744; each file registers both ids. Two pages under one
  route each load one of the two. In `Z-all`'s experiment the two pages had
  swapped ids, which changes their two page chunks (names and contents),
  `_buildManifest.js` and the two pages' HTML. All earlier builds of
  12 October whose file lists are stored, about 50, have the control's
  assignment. The frontend's files are the same in `a16f9a91` and
  `332752b9`.
- `Z-locales`' experiment ran under `LANG` and `LC_ALL` `et_EE.UTF-8` (144
  samples of the publish, 144 of its MSBuild nodes), the control under
  `C.UTF-8`. Every assembly is identical, the four that differed under W26
  included.
- The release has 2245 files, 18 more than on .NET 9: 21 libraries that
  arrive with the new package versions, and 3 that are gone.

Where the expectation failed: 1 and 2, on the manifest, and 2 also on the
frontend. 3 held for every assembly; `Z-locales`' exit 1 is the manifest
alone. 4 held.

## Interpretation

**SDK 10 dates the compressed copies of static assets with the build
time.** `[V]` by the source of SDK 10.0.401 (dotnet/dotnet commit
`e34a38d2`) and a minimal project:

- For every compressible static web asset, publish writes a gzip and a
  Brotli copy and registers each as an asset of its own. `DefineStaticWebAssets`
  reads an asset's length and last-write time from its file
  (`ResolveFileDetails`), so a compressed copy gets the time it was written.
  `DefineStaticWebAssetEndpoints` writes that time as `Last-Modified`, and
  `ApplyCompressionNegotiation` keeps the compressed copy's own
  `Last-Modified`, `Content-Length` and `ETag` on the endpoint that
  negotiates it (lines 386-395).
- A minimal web project, one CSS file dated 1 January 2025 and
  `MapStaticAssets`, published twice 7 s apart: on SDK 10.0.401 the plain
  endpoint is dated 1 January 2025 and the gzip and Brotli endpoints with
  each publish's time, so the two manifests differ. On SDK 9.0.120 every
  endpoint is dated 1 January 2025 and the manifests are identical. On SDK
  10.0.401 with `CompressionEnabled=false` the manifests are identical and
  no compressed copy is written.

So the release's last irreproducible file comes from a regression in SDK
10, not from Phoenix, and it hits every project that publishes static web
assets with compression on, the default. One URL also gets two different
`Last-Modified` values depending on `Accept-Encoding` `[I]`. Not reported
upstream yet.

**Phoenix does not use what the SDK compresses.** `[V]` The WebAPI serves
`wwwroot` with `UseStaticFiles` (`Program.cs` line 492). Nothing calls
`MapStaticAssets`, the only reader of the manifest, and `UseStaticFiles`
never serves a precompressed copy. The manifest and the 124 compressed
copies ship without being read.

**W26 is gone with SDK 10.0.401.** `[V]` for this commit: under Estonian
without the pin, every assembly is the same. This matches what we read in
Roslyn's `main` on 24/9: the generated types are now sorted ordinally. The
`LC_ALL` pin in the release jobs is no longer needed for W26; keeping it
does no harm `[I]`.

**The frontend has a second, rarer order dependence.** The identical bytes
are explained `[V]` by webpack's `FlagIncludedChunksPlugin` (Next's
`bundle5.js`): when a chunk contains all of another chunk's modules, it
adds the other's id to its own list, so both copies list 7363 and 9744.
That two chunks with the same modules exist, one per page, and that their
creation order decides which page gets which id, is `[I]`: webpack's
deterministic ids give both copies the same key and break the tie by order,
and that order can follow the order in which modules finished building, a
timing the entry sort of W47 does not fix. Seen in 1 of about 50 builds;
not measured.

## The fix, checked

`CompressionEnabled=false` in `WebAPI.csproj`, with a comment saying why,
committed as `e6ce3549`. `[V]` Two WebAPI publishes of `332752b9` with it,
layer 2's command without the frontend: 631 files each, the same hash list;
the manifest has 63 endpoints, all with the package's date, and no `.gz` or
`.br` is written. With it the Release build passes and so do the unit tier
(4226 tests) and the functional tier (149), the one that hosts the WebAPI.
The whole release on `e6ce3549` under `none`, `all` and `locales` started
at 20:11.

The minimal project is in `experiments/swa-lastmodified/`, its manifests in
`data/2026-10-12-phoenix-net10-release/arch/swa-repro/`.

## Caveats and not tested

- One machine, one run per axis.
- During `Z-locales`' experiment build, at 19:51, Claude published the
  minimal test project above in another folder. The sampler counted 15
  samples of it as publish processes (Danish locale, the home directory,
  working directory `src`). It shared no files with the build, and the
  release differs only in the manifest, as in `Z-none`.
- The frontend race was seen once. Its rate and its cause are not measured.
- The Windows release is not measured.
