# reprotest logs, 23 September 2026, arch

The rt-*.log files are reprotest's full output: MSBuild output with
Weel-Sandvig source paths and identifiers, so they stay in Leo's private
repo. Verdict and size below; the sha256 lets a later copy be checked.

| file | lines | verdict | sha256 |
| --- | --- | --- | --- |
| rt-1-build_path.log | 9696 | reproduction successful (exit 0) | f3b8275022bf227a… |

Cross-run check: the release.sha256 of both reprotest builds (control in
`const_build_path`, experiment in `build-experiment-1`) is identical to
run 7's publish7.sha256 from the lab: 1237 files, manifest
9283b29e2f8ce154…
