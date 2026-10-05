#!/usr/bin/env python3
# Print the shell script reprotest would run for the control and the
# experiment build, without starting a testbed or running anything.
# Uses the copy in external/reprotest-0.7.32, so you can set breakpoints in
# its variation functions and step through them on any machine.
#
#   python3 reprotest-plan.py -all,+build_path
#
# Needs rstr and distro, e.g. the Python in reprotest's pipx environment.

import logging
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "external", "reprotest-0.7.32"))

from reprotest import BuildContext
from reprotest.build import VariationSpec, Variations

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

vary = sys.argv[1:] or ["-all,+build_path"]
spec = VariationSpec().extend(["+all"] + vary)
start_env = {"PATH": "/usr/bin:/bin", "HOME": "/home/user", "LANG": "da_DK.UTF-8"}

for name, variations in zip(["control", "experiment-1"], Variations.of(spec, verbosity=1)):
    print(f"\n===== {name}")
    ctx = BuildContext("/tmp/reprotest.XXXXXX", "/tmp/dist", "/tmp/src", name, variations)
    build = ctx.make_build_commands("cp a.txt b.txt", start_env)
    print("build folder:", build.tree)
    changes = [f"{k}={v}" for k, v in sorted(build.env.items()) if start_env.get(k) != v]
    changes += [f"-{k}" for k in sorted(start_env) if k not in build.env]
    print("environment changes:", " ".join(changes) or "none")
    print(build.to_script(no_clean_on_error=False))
