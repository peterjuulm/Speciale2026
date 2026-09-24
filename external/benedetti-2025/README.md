# Benedetti et al. (2025): replication package

The replication package of Benedetti et al., "An Empirical Study on
Reproducible Packaging in Open-Source Ecosystems" (ICSE 2025), reference [18]
in the paper: OSF project `vmnsh`,
<https://osf.io/vmnsh/?view_only=c8e26e10cbf145839bfa6820de76792d>.
Mirrored 24 September 2026.

**Not redistributed here.** The OSF project is public but carries no license
(OSF API, 24/9: no `node_license`). Without a license the authors keep all
rights, so this public repo holds a pointer, not the files. `fetch.py`
downloads the package into `osf/`, which is gitignored, and checks every file
against `SHA256SUMS`, the hashes OSF reported on 24/9.

    python3 fetch.py

## Contents: 24 files, 50 MB

| Path | What |
| --- | --- |
| `src/` | Their Go program. It clones each package and runs reprotest once per variation (`src/reprotest/reprotest.go`), storing results in MongoDB. `src/main` is a compiled binary, 12 MB |
| `reproducible_builds_viz/` | The R Markdown behind the paper's figures (`RBFigures.Rmd`), the aggregated data (`R-Bs paper (1).xlsx`) and the figure PDFs |
| `mongodb/` | A MongoDB dump with the raw results, and a Dockerfile to restore it |
| `package_managers_source_code/` | Their patched Python `build` module and RubyGems, as zips |
| `external_resources.pdf` | Examples of causes, the package-manager patches, tables |
| `README.md` | Their own description |

## What we read from it, 24/9

From `src/reprotest/reprotest.go` and `src/main.go` `[V]`:

- reprotest runs on the local machine, one variation per run
  (`--variations=<name>`), 15 packages in parallel.
- Eight variations: environment, fileordering, kernel, locales, exec_path,
  time, timezone, umask. `build_path` is not among them.
- Build commands: npm `npm pack`, PyPI `pip3 wheel`, Cargo `cargo build
  --release`, Maven `mvn clean install`, RubyGems `gem build`.
- The first reprotest run that exits non-zero ends a package's test and
  stores an empty result. The clone and all eight runs share one 3-minute
  timeout. How their analysis reads an empty result is not checked yet.

Tested 24/9 with minimal projects and their build commands: see
`notes/2026-09-24-toolchain-servers.md`.
