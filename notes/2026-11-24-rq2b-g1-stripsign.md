# The eight "identical without signatures" rows of RQ2b, hashed as complete DLLs (24 November 2026)

Grounds: the writing session's request of 24 November (evidence gap G1).
Part 2b's release build reports 22 reproduced packages, and 8 of them rest
on the match *identical without signatures*: Cronos 0.9.0,
Hangfire.InMemory 1.0.0, NodaTime 3.2.0, Microsoft.Identity.Abstractions
9.0.0, Microsoft.Identity.Web.Certificateless 3.8.2, .Diagnostics 3.8.2,
.TokenCache 3.8.2 and Microsoft.OpenApi 1.6.22. That match was decided by
`level.py` from `dllreport.cs` report lines, not by hashing the complete
DLLs with the signatures removed (`dotnet-rebuild-experiments`,
`2-dependencies/2b-rebuild/README.md`, Caveats, third item). The 35
publisher-build rows were hashed with `stripsign.cs`; these eight were not.
Run by Claude on the Mac Studio. Data:
[`data/2026-11-24-rq2b-g1-stripsign/macstudio/`](../data/2026-11-24-rq2b-g1-stripsign/macstudio/).

## Question

For each of the eight packages: after `stripsign.cs` removes the PE
checksum, the Authenticode block and the strong-name signature, is the
DLL from our release-build recipe byte-for-byte the DLL served by
nuget.org?

## Setup

- **The recipes are Windows recipes, all eight.** Each `recipe.toml` at
  `f127442` says `os = "windows"`, inferred by rule 4 from CRLF in the
  SDK-generated files recorded in the publisher's PDB (4 to 30 such files
  per package, none with LF; `derive/<pkg>/facts.txt`, line `os:`). Cronos
  also needs the build folder `C:\projects\cronos`, which its PDB records
  unmapped. The Mac's SDK writes those generated files with LF, so their
  checksums in our PDB, the PDB id in the DLL's debug directory, and with
  them the deterministic MVID and PE timestamp would differ. `stripsign.cs`
  does not remove any of these. And `install-sdk.py` fetches only the
  `linux-x64` or `win-x64` archive. A rebuild on this arm64 Mac therefore
  cannot follow the recipes, and was not attempted.
- **The rebuilt DLLs used instead** are the A builds of the 27 October run
  itself, which ran on GitHub's `windows-2022` runner (image
  20261022.344.1) through `.github/workflows/nupkg-rebuild.yml`. Each run
  uploaded its `out/` folder as an artifact (A, A2 and the nuget.org
  package it downloaded), kept until 25 January 2027. They are downloaded
  here with `gh run download`. Each A DLL is checked against the `sha256`
  line of the stored `level/report-A.txt` at `f127442`, so that the file
  hashed is the file the row was decided from. For Cronos, a second
  Windows build exists: the rerun of 3 November (run 41599872747).
- **The published DLLs** are taken from the `.nupkg` downloaded fresh from
  nuget.org's flat container on 24 November, and checked against the
  stored `level/report-nugetorg.txt`.
- **The tool**: `2-dependencies/shared/stripsign.cs`, copied unchanged into
  a `net10.0` console project, as in the recorded run. It prints only the
  first 16 hex digits of each hash. A second copy differing only in its
  output line prints the full SHA-256 (the diff is in `data/`).
- Lab: `/private/tmp/rb2-g1`, outside any git repository. The .NET 10 SDK
  10.0.403 (`osx-arm64`) is installed alone into the lab from Microsoft's
  archive after its SHA-512 is checked against the release metadata.

## Expectation (written 24/11 10:54, before anything was downloaded or run)

1. Every artifact A DLL has the SHA-256 of its stored `report-A.txt`, and
   every fresh nuget.org DLL that of its stored `report-nugetorg.txt`.
2. In the stored reports, each nuget.org DLL is exactly A's size plus its
   Authenticode block (for example NodaTime 514,048 + 10,944 = 524,992
   bytes), and the strong-name signatures are equal. So I expect all eight
   to come out **equal** under `stripsign.cs`.
3. Doubt: the report hashes neither the `.rsrc` section (the Win32 version
   resource with the file and product version strings), the import and
   relocation tables, nor the padding between sections. A difference
   there would have passed `level.py` and now show as "differ".
4. Cronos's 3 November rebuild gives the same DLL as the 27 October one,
   as the 2b README states.

## Commands

Verbatim in `data/.../kommando.txt`; the scripts it calls are in
`data/.../scripts/`. In short:

```bash
LAB=/private/tmp/rb2-g1
while IFS=$'\t' read n run ships b; do gh run download $run -R peterjuulm/Speciale2026 -D $LAB/artifacts/$n; done < $LAB/runs.tsv
curl -sSfL -o nugetorg/$l.$v.nupkg https://api.nuget.org/v3-flatcontainer/$l/$v/$l.$v.nupkg     # per package
/usr/bin/python3 -I scripts/install-sdk-osx.py 10.0.403 sdk-report
scripts/denv dotnet new console -o ss --framework net10.0; cp .../shared/stripsign.cs ss/Program.cs
scripts/denv dotnet build ss -c Release
bash scripts/compare.sh        # unzip the shipped DLL from each package, hash, check stored reports, then per package:
scripts/denv dotnet ss/bin/Release/net10.0/ss.dll $LAB/dll/<pkg>/nugetorg.dll $LAB/dll/<pkg>/A.dll
```

## Results

**1. The files are the ones the rows were decided from.** [V]
`stored-check.tsv`: all 16 SHA-256s (8 A DLLs from the artifacts, 8 DLLs
from today's nuget.org packages) equal the `sha256:` lines of the stored
reports at `f127442`. Each artifact's `recipe.toml` and `summary.txt` are
byte-for-byte the stored ones (`artifact-vs-stored.txt`). Today's
nuget.org packages are byte-for-byte the ones the runner downloaded on
27 October (`nupkg-sha256.txt`). A equals A2 for all eight (`sha256.tsv`).

**2. All eight are equal under `stripsign.cs`.** [V] `stripsign.txt`
(unchanged tool) and `stripsign-full.txt` (full hashes; same verdicts, and
each full hash begins with the unchanged tool's 16 digits):

| package | identical without signatures | stripped bytes | SHA-256 stripped, nuget.org | SHA-256 stripped, our build A |
|---|---|---|---|---|
| Cronos 0.9.0 | yes | 38,410 | `427c897af8778a15535285010ef4419cb0914d4c3854d6a499ee9bdaed1e9f72` | `427c897af8778a15535285010ef4419cb0914d4c3854d6a499ee9bdaed1e9f72` |
| Hangfire.InMemory 1.0.0 | yes | 125,450 | `36cc4a19f9ea979930e307516f9c3b91019c617ca7a4f5beb3ffda59fb6c8d2c` | `36cc4a19f9ea979930e307516f9c3b91019c617ca7a4f5beb3ffda59fb6c8d2c` |
| NodaTime 3.2.0 | yes | 513,546 | `a1e01ae158abfd4807ff9035fa78f1647aa21e98d76efab4febeaabcf79cfd15` | `a1e01ae158abfd4807ff9035fa78f1647aa21e98d76efab4febeaabcf79cfd15` |
| Microsoft.Identity.Abstractions 9.0.0 | yes | 33,802 | `7349889ab354c18d9d6b05b193d1ef809976fa2c5af33c7160663024dfa74be9` | `7349889ab354c18d9d6b05b193d1ef809976fa2c5af33c7160663024dfa74be9` |
| Microsoft.Identity.Web.Certificateless 3.8.2 | yes | 16,906 | `a60168cf8bd270f40113a68e04f33faffdc8bb42bd90f32be272c79323c91643` | `a60168cf8bd270f40113a68e04f33faffdc8bb42bd90f32be272c79323c91643` |
| Microsoft.Identity.Web.Diagnostics 3.8.2 | yes | 14,346 | `4ff8fa81b4443a178214dce1bb092b100fd4e31578a4b75316793f2a30422022` | `4ff8fa81b4443a178214dce1bb092b100fd4e31578a4b75316793f2a30422022` |
| Microsoft.Identity.Web.TokenCache 3.8.2 | yes | 45,066 | `affaf7376217019e05dedda0c27cae64ef69f327b8da70c48c296be905f31ca5` | `affaf7376217019e05dedda0c27cae64ef69f327b8da70c48c296be905f31ca5` |
| Microsoft.OpenApi 1.6.22 | yes | 232,970 | `f67bd84f879ef3c5b96121bfbf7e6f47ce049bb6e4bc54e7b9765d290bc039f0` | `f67bd84f879ef3c5b96121bfbf7e6f47ce049bb6e4bc54e7b9765d290bc039f0` |

The stripped length is below A's file length because `stripsign.cs` drops
trailing zero padding (502 bytes for every package here) from both sides.

**3. Cronos's 3 November rebuild** gives the same A DLL as the 27 October
one (SHA-256 `adc6e8d7…`), and the same stripped hash. [V] `sha256.tsv`,
`stripsign.txt`, last line.

**4. Where the files differ before stripping.** [V] `raw-diff.txt`. Within
A's length, the only differing bytes in all eight are the PE checksum
(offset `0xD8`) and the certificate table entry (`0x118`–`0x11F`). The
nuget.org file is A's bytes followed by the Authenticode block, which
starts exactly at A's end (10,264 to 12,000 bytes). Six of the eight are
strong-name signed (NodaTime, Microsoft.Identity.Abstractions,
.Certificateless, .Diagnostics, .TokenCache and Microsoft.OpenApi;
`cor flags` in the stored reports); Cronos and Hangfire.InMemory are not.
All six strong-name signatures are equal byte for byte, so the zeroing of
that signature did not decide any verdict here.

**5. The tool discriminates.** [V] `controls.txt`, on
Microsoft.Identity.Web.Diagnostics: one byte flipped in A's `.rsrc`
section (the region the report does not hash) gives *differ* at `0x3200`;
one byte in the middle of `.text` gives *differ* at `0x1A00`; one byte in
the strong-name signature gives *equal*; A against itself gives *equal*.

## Interpretation

- The eight rows hold. Checked on the complete DLLs, all eight are
  *identical without signatures*; the gap named in the 2b README's third
  caveat is closed for the 27 October builds. The headline of 22
  reproduced packages (14 identical, 8 identical without signatures) now
  rests on complete-file hashes throughout: the 14 by plain SHA-256, the 8
  by `stripsign.cs`. [V] for the eight, from results 1 and 2.
- The doubt in expectation 3 did not materialise: nothing outside the
  report's lines differed, including the Win32 version resource. [V]
  result 4.
- The match is tighter than its name. For all eight, the publisher's DLL
  is our build with one thing added after compilation: an Authenticode
  signature, with the PE checksum and certificate entry that go with it.
  The strong-name signatures were already equal, which means the
  strong-name key the publisher used is the one in the public repository.
  [V] for the bytes (result 4); [I] that the key is the one in the
  repository, since our build signed with whatever key the repository
  provides and produced the same signature.
- This verifies the run of record, not a new build. What is shown is that
  the DLL our recipe produced on 27 October equals the published DLL
  without signatures. For Cronos, an independent second build a week
  later gave the same bytes; for the other seven, repeatability rests on
  A = A2 within one run. [V]

## Caveats

- **Not rebuilt here.** The task asked for a rebuild with each recipe.
  All eight recipes are Windows recipes (`os = "windows"`), and this
  arm64 Mac cannot follow them: `install-sdk.py` selects `linux-x64` on
  any non-Windows host (line 33 of `2-dependencies/shared/install-sdk.py`
  [V]); Cronos needs `C:\projects\cronos` [V, recipe]; the other seven
  would get LF instead of CRLF in the SDK-generated files and with that a
  different PDB id, MVID and timestamp [I, not run]. The artifacts of the
  run of record were used instead. A fresh rebuild on `windows-2022` would
  mean dispatching `nupkg-rebuild.yml` in Speciale2026 eight times; that
  was not done, since it acts on the shared repository.
- The artifacts and the stored reports come from the same run. Their
  agreement shows the files are the ones the rows were decided from, not
  independent provenance. The artifacts' GitHub digests are recorded in
  `runs-provenance.tsv`.
- The artifacts expire on 25 January 2027 (Cronos's rerun on 1 February
  2027). After that this check can be repeated only by rebuilding on a
  Windows runner. The DLLs are not kept in git (bytes do not go in git).
- `stripsign.cs` in `dotnet-rebuild-experiments` differs from
  `f127442:dependencies/experiments/nupkg/stripsign.cs` in three comment
  lines only (`scripts/stripsign-f127442-vs-shared.diff`). The full-hash
  copy changes one output line (`scripts/stripsign-full.diff`); its
  verdicts and hash prefixes agree with the unchanged tool.
- The report SDK came from a lab copy of `install-sdk.py` with the archive
  name changed to `osx-arm64` (`scripts/install-sdk-osx.diff`). It only
  runs `stripsign.cs`, whose output does not depend on the host.
- On macOS, `dotnet` under `env -i` fails at first use without `TMPDIR`
  (NuGet's migration mutex: `lstat("")`, ENOENT). The lab's `denv` sets
  it. [V] for `dotnet new`; [I] that `rebuild.py`'s non-Windows
  environment, which sets no `TMPDIR`, would fail the same way on a Mac.

## Not tested

- A fresh rebuild of the eight on `windows-2022` today.
- Any of the eight built on macOS.
- The PDBs (`.snupkg`), which this match does not cover.
- Higher SDKs with the same compiler (rule 3).

## For the writing session (nothing edited here)

- `2-dependencies/2b-rebuild/README.md`: the third caveat, and "Not run
  from here: … `stripsign.cs` on the eight rows matched as identical
  without signatures", can now point to this note.
- `results/signature-stripped.txt` holds the 35 publisher-build rows; the
  eight rows above could be added in its form.
