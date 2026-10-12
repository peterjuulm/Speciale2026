#!/bin/bash
# Lab for the module-order experiment (W51): an export of the whole commit,
# with the frontend's next.config.js wrapped so that ModuleOrderPlugin can
# perturb, log and sort webpack's module order. module-runs.sh builds it.
#
#   module-lab.sh COMMIT [LAB]     LAB defaults to /private/tmp/rb1-fe-module
#
# The lab differs from the commit in exactly three files under
# src/WebAPI/ClientApp: next.config.js (the wrapper), next.config.orig.js
# (the commit's config, renamed) and module-order-plugin.js.
#
# Written 12 October 2026, after entry-lab.sh.
set -euo pipefail
commit=${1:?COMMIT}
lab=${2:-/private/tmp/rb1-fe-module}
repo=/home/leos/Dev/Weel-Sandvig/WS.Phoenix-repro
here=$(cd "$(dirname "$0")" && pwd)
app=$lab/src/WebAPI/ClientApp

rm -rf "$lab"
mkdir -p "$lab"
git -C "$repo" archive "$commit" -- . ':(exclude).claude' | tar -x -C "$lab"
python3 "$here/../labcheck.py" "$repo" "$commit" "$lab"
mv "$app/next.config.js" "$app/next.config.orig.js"
cp "$here/module.wrap.js" "$app/next.config.js"
cp "$here/module-order-plugin.js" "$app/module-order-plugin.js"
echo "wrapped: $app/next.config.js"
