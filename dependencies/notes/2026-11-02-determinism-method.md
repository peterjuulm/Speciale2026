# The determinism experiment's method, as pseudocode

Written 2 November 2026 for the methods section with Peter. The method of
[2026-11-01-determinism.md](2026-11-01-determinism.md) in 25 lines; the
scripts that run it are in `dotnet-rebuild-experiments/2-dependencies/2a-determinism/`
(`population.py`, `build-and-compare.py`, `summary.py`).

```
packages   = packages WS.PEMS ships                      # 341, from its lock files

for p in packages:
    p.repo, p.commit = read p.nuspec                     # the publisher's own statement
    p.project        = find csproj in clone(p.repo, p.commit) with p.assembly name
    if any missing: record why, skip p                   # 341 -> 224

sdk        = .NET SDK 10.0.403, installed alone, hash checked
modes      = { default:    dotnet build && dotnet pack,                   # Benedetti's "as is"
               configured: the same + ContinuousIntegrationBuild
                                    + Deterministic
                                    + DeterministicTimestamp = commit time }
variations = { build_path, environment, locales, exec_path,
               time, timezone, umask, fileordering }
levels = { whole file, content without NuGet metadata, assemblies }

for p in packages with a project:
    clone at p.commit, restore once
    if build(p, default) fails: record the first error, skip p   # "did not build": a result, not an exclusion

    for mode in modes:
        for v in variations:
            a = build(p, mode)                           # control
            b = build(p, mode, vary = v)                 # one thing changed
            for level in levels:
                verdict[p, mode, v, level] = same | differs | failed

for p in built:
    for level in levels:
        broken = { v in variations where verdict[p, default, v, level] != same }

        if broken is empty:                                           category = "as is"
        elif all verdict[p, configured, v, level] == same
             for v in broken:                                         category = "with configuration"
        else:                                                         category = "unreproducible"
```

Details that do not change the numbers, left out above:

- `UseSharedCompilation=false` in both modes, so the compiler does not run as
  a server process (the `time` variation hangs on it).
- A `global.json` that pins another SDK has the pin removed, and the row says so.
- The two packages of a run are paired by package id, not file name, since two
  packages write the clock into the version. Symbol packages are not compared.
- reprotest runs without diffoscope; the verdict is the driver's own comparison
  (SHA-256 of the file, of each entry, of the assemblies among them).

The run of 1 to 2 November was made on an earlier derivation of the population
(157 package versions, 51 excluded before building, 16 did not build, 90
measured) and ran the configured mode only where content differed plus `time`.
The run of 2 to 3 November covers the 224 and every configured variation.
