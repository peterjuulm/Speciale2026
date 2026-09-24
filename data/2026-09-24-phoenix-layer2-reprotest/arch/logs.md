# reprotest logs, 24 September 2026, arch

The rt-*.log files are reprotest's full output: MSBuild output with
Weel-Sandvig source paths and identifiers, and in run 2 diffoscope's dump of
Phoenix assemblies. They stay in Leo's private repo, together with the
reprotest stores, the mode lists, the process samples and the ildasm dumps.
Verdict and size below; the sha256 lets a later copy be checked.

| file | lines | verdict | sha256 |
| --- | --- | --- | --- |
| rt-0-umask.log | 9717 | reproduction successful (exit 0) | 1929ed6e8288bf83… |
| rt-1-time.log | 9731 | reproduction successful (exit 0) | ecb3df389cc4cea5… |
| rt-2-locales.log | 10187 | differences (exit 1) | 73ac291f56d0fd56… |
| rt-3-umask.log | 9725 | reproduction successful (exit 0) | adebca1b61b5b3f0… |
| rt-4-exec_path.log | 9725 | reproduction successful (exit 0) | 2566ae9add63841e… |
| rt-5-locales.log | 9727 | reproduction successful (exit 0) | 734873feada16b7d… |
| rt-6-locales.log | 9955 | reproduction successful (exit 0) | ff91c28f2d11d646… |

Process samples, one per run: samples-N-AXIS.txt, written by
experiments/sample-dotnet.py and summarised with experiments/analyze-samples.py.
No MSBuild worker node appears in any of them.
