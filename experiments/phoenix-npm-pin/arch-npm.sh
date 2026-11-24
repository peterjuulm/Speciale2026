#!/bin/bash
#
# arch-npm.sh COMMIT
#
# The npm pin on a real Linux machine, Leo's Arch laptop (glibc), driven
# from the Mac over SSH; nothing of WS.Phoenix is cloned there:
#   1. Node 22.23.3 linux-x64 from nodejs.org, checked against node.sha256
#      of COMMIT, in /private/tmp/rb1-npmpin-node, and npm from the tarball
#      that COMMIT's packageManager names, checked against its SHA-512.
#   2. An online npm ci of COMMIT's ClientApp into /private/tmp/rb1-npm (the
#      cache stage 3's build.sh uses), then the list of installed packages
#      and the SHA-256 of every file under node_modules.
#   3. build.sh (copied from the Mac, SHA-256 04ea8b35...) in two labs made
#      by git archive of COMMIT: /private/tmp/rb1-ws-pems and
#      /private/tmp/rb1-ws-pems-alt, as on the Mac.
# Results land in OUT (default /private/tmp/rb1-arch-npm) on the Mac.
#
# Written 23 November 2026 for E1-S3-08.

set -euo pipefail
commit=$1
arch=leos@192.168.9.124
repo=${REPO:-$HOME/Dev/Weel-Sandvig/WS.Phoenix}
out=${OUT:-/private/tmp/rb1-arch-npm}
build=$HOME/Dev/leosakharoff/dotnet-rebuild-experiments/1-ws-pems/scripts/3-frontend/build.sh
mkdir -p "$out"
ssh_() { ssh -o BatchMode=yes "$arch" 'bash -s' "$@"; }

# The rb1-npmpin-* folders are this script's own; the two labs must not exist
# unless an earlier run of this script made them (its marker file).
ssh -o BatchMode=yes "$arch" 'rm -rf /private/tmp/rb1-npmpin-node /private/tmp/rb1-npmpin-fill /private/tmp/rb1-npmpin-dl'
for l in /private/tmp/rb1-ws-pems /private/tmp/rb1-ws-pems-alt; do
    ssh -o BatchMode=yes "$arch" "test ! -e $l || test -e $l/.rb1-npmpin" || { echo "$l exists on Arch and is not this script's; not touching it" >&2; exit 1; }
    ssh -o BatchMode=yes "$arch" "rm -rf $l"
done

node_line=$(git -C "$repo" show "$commit:src/WebAPI/ClientApp/node.sha256" | grep -E '  node-v[0-9.]+-linux-x64\.tar\.gz$')
pm=$(git -C "$repo" show "$commit:src/WebAPI/ClientApp/package.json" | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["packageManager"])')
scp -q "$build" "$arch:/private/tmp/rb1-npmpin-build.sh"

ssh_ <<EOF | tee "$out/1-tools.txt"
set -euo pipefail
node_line='$node_line'; pm='$pm'
f=\${node_line##* }; v=\${f#node-v}; v=\${v%-linux-x64.tar.gz}
d=/private/tmp/rb1-npmpin-dl; rm -rf "\$d"; mkdir -p "\$d" /private/tmp/rb1-npmpin-node
curl -fsSL -o "\$d/\$f" "https://nodejs.org/dist/v\$v/\$f"
(cd "\$d" && printf '%s\n' "\$node_line" | sha256sum -c --strict -)
tar -xzf "\$d/\$f" -C /private/tmp/rb1-npmpin-node --strip-components=1 --no-same-owner
[[ \$pm =~ ^npm@([0-9.]+)\+sha512\.([0-9a-f]{128})\$ ]]
nv=\${BASH_REMATCH[1]}; sha=\${BASH_REMATCH[2]}
curl -fsSL -o "\$d/npm-\$nv.tgz" "https://registry.npmjs.org/npm/-/npm-\$nv.tgz"
(cd "\$d" && printf '%s  %s\n' "\$sha" "npm-\$nv.tgz" | sha512sum -c --strict -)
export PATH=/private/tmp/rb1-npmpin-node/bin:/usr/bin:/bin
(cd "\$d" && npm install --global --prefix /private/tmp/rb1-npmpin-node --offline --ignore-scripts --no-audit --no-fund "\$d/npm-\$nv.tgz" > /dev/null)
echo "node \$(node --version), npm \$(npm --version) at \$(command -v npm)"
echo "build.sh sha256 \$(sha256sum /private/tmp/rb1-npmpin-build.sh | cut -d' ' -f1)"
ldd --version 2>&1 | sed -n 1p || true
node -p 'process.report.getReport().header.glibcVersionRuntime'
EOF

git -C "$repo" archive "$commit" src/WebAPI/ClientApp | ssh -o BatchMode=yes "$arch" 'mkdir -p /private/tmp/rb1-npmpin-fill && tar -x -C /private/tmp/rb1-npmpin-fill'
ssh_ <<'EOF' > "$out/2-install.txt" 2>&1
set -euo pipefail
cd /private/tmp/rb1-npmpin-fill/src/WebAPI/ClientApp
env -i HOME="$HOME" PATH=/private/tmp/rb1-npmpin-node/bin:/usr/bin:/bin npm_config_cache=/private/tmp/rb1-npm \
    npm_config_update_notifier=false npm ci --ignore-scripts --no-audit --no-fund
python3 -I - node_modules > /private/tmp/rb1-npmpin-packages.txt <<'PY'
import json, os, sys
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
walk(sys.argv[1])
print('\n'.join(sorted(rows)))
PY
find node_modules -type f ! -path node_modules/.package-lock.json -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > /private/tmp/rb1-npmpin-node_modules.sha256
echo "$(wc -l < /private/tmp/rb1-npmpin-packages.txt) packages, $(wc -l < /private/tmp/rb1-npmpin-node_modules.sha256) files"
EOF
tail -3 "$out/2-install.txt"
scp -q "$arch:/private/tmp/rb1-npmpin-packages.txt" "$out/arch.packages.txt"
scp -q "$arch:/private/tmp/rb1-npmpin-node_modules.sha256" "$out/arch.node_modules.sha256"

for lab in /private/tmp/rb1-ws-pems /private/tmp/rb1-ws-pems-alt; do
    name=$(basename "$lab")
    git -C "$repo" archive "$commit" -- . ':(exclude).claude' | ssh -o BatchMode=yes "$arch" "mkdir -p $lab && touch $lab/.rb1-npmpin && tar -x -C $lab"
    ssh_ > "$out/3-$name.log" 2>&1 <<EOF
set -euo pipefail
cd $lab
env -i HOME="\$HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin NODE_DIR=/private/tmp/rb1-npmpin-node bash /private/tmp/rb1-npmpin-build.sh
EOF
    scp -q "$arch:$lab/hashes.sha256" "$out/$name.hashes.sha256"
    echo "$name: $(wc -l < "$out/$name.hashes.sha256") files, list sha256 $(shasum -a 256 < "$out/$name.hashes.sha256" | cut -d' ' -f1)" | tee -a "$out/summary.txt"
done
