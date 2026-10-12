#!/bin/bash
# Lab for the entry-order experiment (W47): an export of the whole commit,
# with the frontend's next.config.js wrapped so that EntryOrderPlugin logs,
# and with ENTRY_SORT=1 sorts, webpack's entries. run.sh then builds it as
# usual, with LAB pointing here.
#
#   entry-lab.sh COMMIT [LAB]     LAB defaults to /private/tmp/rb1-fe-entry
#
# The lab differs from the commit in exactly three files under
# src/WebAPI/ClientApp: next.config.js (the wrapper), next.config.orig.js
# (the commit's config, renamed) and entry-order-plugin.js.
#
# Written 12 October 2026.
set -euo pipefail
commit=${1:?COMMIT}
lab=${2:-/private/tmp/rb1-fe-entry}
repo=/home/leos/Dev/Weel-Sandvig/WS.Phoenix-repro
here=$(cd "$(dirname "$0")" && pwd)
app=$lab/src/WebAPI/ClientApp

rm -rf "$lab"
mkdir -p "$lab"
git -C "$repo" archive "$commit" -- . ':(exclude).claude' | tar -x -C "$lab"
python3 "$here/../labcheck.py" "$repo" "$commit" "$lab"
mv "$app/next.config.js" "$app/next.config.orig.js"
cp "$here/next.config.wrap.js" "$app/next.config.js"
cp "$here/entry-order-plugin.js" "$app/entry-order-plugin.js"
echo "wrapped: $app/next.config.js"
