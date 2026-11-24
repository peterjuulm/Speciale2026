#!/bin/bash
#
# ci-as.sh NODE_DIR APP OUT [LIBC]
#
# npm ci in APP (a copy of src/WebAPI/ClientApp outside git) with the Node
# and npm in NODE_DIR, as linux-x64 with LIBC (default glibc), the release
# runner's platform, through npm's own --os/--cpu/--libc overrides. Then a
# list of every installed package: its folder, name and version, and the
# SHA-256 of each file under node_modules except npm's hidden lockfile.
#
#   OUT.packages.txt   path name@version, one per package, sorted
#   OUT.files.sha256   sha256  path, one per file, sorted
#   OUT.npm.log        npm's output
#
# The cache is /private/tmp/rb1-npm, as stage 3's build.sh uses. ONLINE=1
# lets npm fetch what the cache lacks; without it npm runs --offline.
#
# Written 23 November 2026 for the npm pin (E1-S3-08).

set -euo pipefail
[ $# -ge 3 ] || { echo "usage: ci-as.sh NODE_DIR APP OUT [LIBC]" >&2; exit 1; }
node_dir=$1 app=$2 out=$3 libc=${4:-glibc}
offline=--offline
[ "${ONLINE:-}" = 1 ] && offline=

cd "$app"
rm -rf node_modules
env -i HOME="$HOME" PATH="$node_dir/bin:/usr/bin:/bin" \
    npm_config_cache=/private/tmp/rb1-npm npm_config_update_notifier=false \
    npm ci --ignore-scripts $offline --no-audit --no-fund \
        --os=linux --cpu=x64 --libc="$libc" > "$out.npm.log" 2>&1 \
    || { echo "npm ci failed; see $out.npm.log" >&2; exit 1; }
echo "npm $(env -i PATH="$node_dir/bin:/usr/bin:/bin" npm --version)" >> "$out.npm.log"

/usr/bin/python3 -I - node_modules > "$out.packages.txt" <<'EOF'
import json, os, sys
root = sys.argv[1]
rows = []
def walk(nm):
    for e in sorted(os.listdir(nm)):
        p = os.path.join(nm, e)
        if e.startswith('.') or not os.path.isdir(p):
            continue
        if e.startswith('@'):
            for s in sorted(os.listdir(p)):
                pkg(os.path.join(p, s))
        else:
            pkg(p)
def pkg(p):
    pj = os.path.join(p, 'package.json')
    if os.path.isfile(pj):
        d = json.load(open(pj))
        rows.append(f"{p} {d.get('name')}@{d.get('version')}")
    sub = os.path.join(p, 'node_modules')
    if os.path.isdir(sub):
        walk(sub)
walk(root)
print('\n'.join(sorted(rows)))
EOF

find node_modules -type f ! -path node_modules/.package-lock.json -print0 \
    | LC_ALL=C sort -z | xargs -0 shasum -a 256 > "$out.files.sha256"
echo "$out: $(wc -l < "$out.packages.txt") packages, $(wc -l < "$out.files.sha256") files"
