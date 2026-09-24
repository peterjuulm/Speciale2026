# Roslyn orders generated types by culture: a minimal reproduction

Run 24 September 2026 on `arch`. Follows
[phoenix-layer2-reprotest](2026-09-24-phoenix-layer2-reprotest.md), run 2,
where Phoenix's release changed under `et_EE.UTF-8` (W26).
Data: `data/2026-09-24-roslyn-locale-repro/arch/`.

## Question

Does the locale defect show up in a few lines of our own code, without
Phoenix? And which fix makes the output independent of the build machine's
locale? The reproduction is also what an upstream report needs.

## Setup

- `experiments/roslyn-locale/`: a class library with two collection
  expressions, one into a `ReadOnlySpan<int>` and one into an
  `IEnumerable<int>`. They should make the compiler generate
  `<>y__InlineArray2<T>` and `<>z__ReadOnlySingleElementList<T>`.
- `run.sh NAME VAR=VALUE…` copies the project to `/private/tmp/rb1-locale`,
  outside git, shuts the build servers down, builds with `dotnet build -c
  Release -p:Features=debug-determinism` in the given environment, and prints
  the DLL's hash, the order of the two generated types (`ildasm -CLASSLIST`),
  and the hash of the compiler's `.key` file. `debug-determinism` makes the
  compiler write that file, which lists every input it considers part of a
  deterministic build.
- Microsoft's SDK 9.0.120, Roslyn 4.12 `fc52718e`, as for Phoenix.
- Five builds:

| Build | Environment |
| --- | --- |
| B1 | `LC_ALL=C.UTF-8`, as reprotest's control and GitHub's Linux runners |
| B2 | `LC_ALL=da_DK.UTF-8` |
| B3 | `LC_ALL=et_EE.UTF-8` |
| B4 | `LC_ALL=et_EE.UTF-8 DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` |
| B5 | `LC_ALL=C.UTF-8 DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` |

## Expectation, written before the run

1. B1 and B2 are identical, with `<>y__` first: Danish sorts y before z.
2. B3 differs from B1 with `<>z__` first, as in Phoenix's run 2.
3. The `.key` files of B1 and B3 are identical. Roslyn's documentation lists
   the current culture as an input only for the language of diagnostics
   (`docs/compilers/Deterministic Inputs.md`), so the key does not record it
   `[I]`.
4. B4 and B5 are identical: invariant globalization makes every culture
   comparison ordinal, whatever `LC_ALL` says `[I]`.
5. B5 is identical to B1. Ordinal and invariant order agree on these names
   `[I]`. Weakly held.

## Commands

`experiments/roslyn-locale/run.sh`, five calls, verbatim in `kommando.txt`.

## Result

13:49, all five builds succeeded `[V]` `results.txt`, `build-*.log`.

| Build | DLL | Generated types, in emitted order | `.key` |
| --- | --- | --- | --- |
| B1 `C.UTF-8` | `0be29e7a…` | `<>y__InlineArray2`1`, `<>z__ReadOnlySingleElementList`1` | `376bcae2…` |
| B2 `da_DK.UTF-8` | `0be29e7a…` | y, z | `376bcae2…` |
| B3 `et_EE.UTF-8` | **`65ba6aa4…`** | **z, y** | `376bcae2…` |
| B4 `et_EE.UTF-8` + invariant | `0be29e7a…` | y, z | `376bcae2…` |
| B5 `C.UTF-8` + invariant | `0be29e7a…` | y, z | `376bcae2…` |

The `.key` files are byte-identical across all five builds. The key, 4753
lines of JSON, records the compiler and runtime versions, the OS, every option
and every reference with its hash, and no culture `[V]` `key-*.txt`.

All five expectations held.

## Interpretation

**Two methods are enough.** Two collection expressions, built under
an Estonian locale, give a different DLL than under the invariant or the
Danish culture. The defect is the compiler's, not Phoenix's.

**The compiler's own account of its inputs is incomplete.** Roslyn's
determinism key says B1 and B3 had identical inputs, and the outputs differ.
By Roslyn's documented contract, culture should only change the language of
diagnostics. That makes this a determinism bug in Roslyn's own terms.

**Invariant globalization fixes it independent of the locale.**
`DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` gave B1's bytes under both `C.UTF-8`
and `et_EE.UTF-8`. It should work on Windows too, where `LC_ALL` means
nothing `[I]`, not tested.
Pinning `LC_ALL=C.UTF-8` also gives B1's bytes, but only where the variable is
set.

**Which SDKs have the fix.** The ordinal sort came with Roslyn PR #80970,
merge commit `c14ec83f`, 31 October 2025. It is in Roslyn's `release/dev18.3`,
`release/insiders` and `main`, and not in `release/dev18.0` or any
`release/dev17.x` `[V]` GitHub compare API, 24/9. The SDK's own dependency file
maps SDK bands to Roslyn: 9.0.3xx to 4.14, 10.0.1xx to 5.0, 10.0.2xx to 5.3,
10.0.3xx to 5.6 `[V]` `eng/Version.Details.xml` on each `dotnet/sdk` release
branch. So the fix ships from SDK 10.0.2xx on, and in no .NET 9 SDK `[I]`, not
measured with a build. The three other culture-sensitive sorts in
`PrivateImplementationDetails` are still on `main`.

## Caveats and not tested

- One pair of names. Other generated names, sorted by the same class, could
  collate differently in other cultures.
- A compiler with the ordinal sort (Roslyn `main`, or a newer
  `Microsoft.Net.Compilers.Toolset`) is not tested: it would need a download.
- Invariant globalization changes all culture handling in the build's .NET
  processes. Harmless here; on a larger project it has to be measured.
