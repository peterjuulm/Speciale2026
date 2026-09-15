# reprotest logs, 15 September 2026, arch

The rt-*.log files are reprotest's full output: MSBuild build logs and diffoscope
dumps of Phoenix assemblies and PDBs. They contain Weel-Sandvig source paths,
identifiers and embedded generated code, so they stay in Leo's private repo
(speciale-2026/data/phoenix-reprotest/arch/). Verdicts and sizes below; the
sha256 lets a later copy be checked against what was analysed.

| file | lines | verdict | sha256 |
| --- | --- | --- | --- |
| rt-0-failed-msb1008.log | 63 | build failed (MSB1008) | cbaa2b17e030400f… |
| rt-1-build_path.log | 453927 | differences | 30cb3316a840ad87… |
| rt-2-build_path-pathmap.log | 453928 | differences | e7abb3b43279d7a8… |
| rt-3-build_path-pathmap-explicit.log | 19787 | differences | 266667716ef02920… |
| rt-4-build_path-no-razor.log | 19381 | differences | 28dd38803b0eeeaa… |
| rt-5-time.log | 19590 | identical | 0a6bdbc48d8ca6f6… |
| rt-6-locales.log | 19580 | identical | a9accdafdf1db601… |
| rt-7-umask.log | 19578 | identical | 00960529bbef9c8d… |
| rt-8-exec_path.log | 19578 | identical | 7f848221f3e14a5c… |
