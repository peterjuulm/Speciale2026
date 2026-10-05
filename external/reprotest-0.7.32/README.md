# reprotest 0.7.32: source copy

The Python source of reprotest 0.7.32, the version the notes record for the
reprotest runs on `arch` and `ubuntu-vm`, installed with pipx
([2026-09-08-findings](../../notes/2026-09-08-findings.md),
[2026-09-14-environment-axes](../../notes/2026-09-14-environment-axes.md),
[2026-09-24-phoenix-layer2-reprotest](../../notes/2026-09-24-phoenix-layer2-reprotest.md)).
Upstream: <https://salsa.debian.org/reproducible-builds/reprotest>.
Copied 5 October 2026 from the pipx install on `mac`, the PyPI release,
installed 7 September 2026.

**Unmodified.** All 24 files match the sha256 that pip wrote into
`dist-info/RECORD` at install time (checked 5/10). `SHA256SUMS` covers the same
files plus `dist-info/` and `COPYING`:

    shasum -a 256 -c SHA256SUMS

**Left out:** `__pycache__/` (compiled bytecode) and pipx's launcher
`bin/reprotest`, a wrapper whose first line holds the local Python path. It
only calls `reprotest.main()`.

## License

reprotest is GPL-3.0-or-later: `dist-info/METADATA` and the header of each of
its own files. The files in `reprotest/lib/` and `reprotest/virt/` come from
autopkgtest, copyright Canonical Ltd, and are GPL-2.0-or-later by their
headers; their "or any later version" clause lets them travel with the GPL-3
text. `lib/system_interface/fedora.py` and the empty `lib/__init__.py` have no
header. `COPYING` is the GPL version 3 text, sha256 `3972dc97…`. Every header
is kept as it is. The headers point to the upstream `debian/copyright`, which
the PyPI package does not include; it is in the upstream repository.

## What is where

| Path | What |
| --- | --- |
| `reprotest/__init__.py` | The main program: options, the control and experiment builds, the comparison |
| `reprotest/build.py` | The variations: `build_path` line 253, `fileordering` 269, `home` 288, `locales` 382, `exec_path` 394, `umask` 451, and the rest |
| `reprotest/lib/`, `reprotest/virt/` | autopkgtest's testbed code and virt servers (null, chroot, schroot, lxc, lxd, qemu, ssh), which run the builds |
| `dist-info/` | pip's metadata: version, dependencies (`rstr`, `distro`, optional `diffoscope>=112`) and `RECORD` |

## Running it

The copy runs from this directory with a Python that has `rstr` and `distro`:

    python3 -m reprotest --help

Tested 5/10 with the pipx environment's Python. Most variations call Linux
tools (`unshare`, `setarch`, `faketime`, `disorderfs`), so real runs still
need `arch` or `ubuntu-vm`; see
[2026-09-09-findings](../../notes/2026-09-09-findings.md).
