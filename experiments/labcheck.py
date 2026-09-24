"""Compare a lab directory with a git commit, file by file.

Checks every file of the commit (without .claude/) against the lab by git
blob hash and executable bit, and lists files missing from or extra in the
lab.

Usage: python3 labcheck.py REPO COMMIT LAB

Written 24 September 2026.
"""
import hashlib, os, subprocess, sys
repo, commit, lab = sys.argv[1:4]
out = subprocess.run(['git', '-C', repo, 'ls-tree', '-r', '-z', commit], capture_output=True, check=True).stdout
tree = {}
for rec in out.split(b'\0'):
    if not rec: continue
    meta, path = rec.split(b'\t', 1)
    mode, typ, sha = meta.split()
    path = path.decode()
    if path == '.claude' or path.startswith('.claude/'): continue
    tree[path] = (mode.decode(), sha.decode())
lab_files = set()
for root, dirs, files in os.walk(lab):
    for f in files:
        lab_files.add(os.path.relpath(os.path.join(root, f), lab))
missing = sorted(set(tree) - lab_files)
extra = sorted(lab_files - set(tree))
differ = []
for p in sorted(set(tree) & lab_files):
    mode, sha = tree[p]
    full = os.path.join(lab, p)
    if mode == '120000':
        data = os.readlink(full).encode()
    else:
        data = open(full, 'rb').read()
        if (mode == '100755') != bool(os.stat(full).st_mode & 0o100):
            differ.append(p + ' (exec bit)')
            continue
    h = hashlib.sha1(b'blob %d\0' % len(data) + data).hexdigest()
    if h != sha: differ.append(p)
print(f'{len(tree)} files in commit, {len(lab_files)} in lab: {len(missing)} missing, {len(differ)} differing, {len(extra)} extra')
for p in missing[:10]: print('missing', p)
for p in differ[:10]: print('differs', p)
for p in extra[:10]: print('extra', p)
