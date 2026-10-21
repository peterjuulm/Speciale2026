# Nupkg test: the short plan

Planning note, 21 October 2026. Step 3 of the
[dependency plan](2026-10-12-dependency-plan.md), which stays the reference
for terms and decisions. Not an experiment; the pilot gets its own note.
Phoenix commit `79cb67a7` (.NET 10).

## Question

Do we get the bytes on nuget.org when we build a package from the commit it
declares, with the compiler it declares?

## Packages

- **312 tested.** The plan's 341 included 29 packages that ship no file to the
  Linux release (category N0). By our rule they are left out (corrected 21/10).
- **196 ready** (source and compiler declared) come from **82 builds**. One
  build is one repository at one commit.
- The other 116 are not built: no compiler declared (83), no source declared
  (24), native code only (9, still open).

## The environment for each build

| Part | Where we take it from |
| --- | --- |
| Source | The `.nuspec`'s repository and commit, cloned with history: version tools read git |
| SDK | `global.json` if it is exact (E4, E5). Else the SDK whose `csc.dll` has the Roslyn commit in the PDB's compiler record |
| Build command | The repository's CI file or build script, else `dotnet pack -c Release` |
| Official build values | Taken from the published DLL, and marked (decision 9) |
| Machine | `arch`, outside our lab and outside this repo |

Record for each build which row gave which value.

## Steps for each build

1. Clone the repository at the declared commit, in a new directory.
2. Build with the chosen SDK and command.
3. Compare each DLL and PDB with the file on nuget.org, after we remove the
   signatures (decision 6).
4. Build again in a second directory and compare the two builds.
5. If step 2 fails, try SDK `10.0.401` one time. Mark it as a fallback: a match
   with it does not count as reproducible.

## Result for each build

- **Nupkg test:** reproducible, differs (which file, which bytes), or does not
  build (where it stopped; who could fix it: as is, configuration, tool patch,
  external).
- **Determinism:** our two builds are the same, or they differ (where).

## Pilot first

Four small third-party builds, at different levels of what they declare:

| Package | Version | SDK declared |
| --- | --- | --- |
| Cronos | 0.9.0 | None (E2) |
| RBush | 4.0.0 | Wildcard in CI (E2) |
| Ardalis.GuardClauses | 5.0.0 | Wildcard in CI (E2) |
| FluentValidation | 11.11.0 | `global.json` as a lower bound (E3) |

The pilot gives the script and the time for one build. Then the other builds,
smallest first, `dotnet/dotnet` last.

## Expectations (draft: Leo and Peter confirm before the pilot)

`[I]` all of it.

1. At least 2 of the 4 pilot builds match nuget.org after signatures are
   removed.
2. Where they do not match, the cause is the version stamp, a build path or a
   reference version.
3. Our two builds are the same in every build that succeeds.

## Open

- A table from SDK version to Roslyn commit, to pick the SDK in step 2.
- Packages built on Windows: line endings may differ on `arch`.
- How much of `dotnet/dotnet` the test needs (62 packages).
