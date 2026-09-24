"""Mirror the Benedetti et al. (2025) replication package from OSF.

Downloads every file of the public OSF project vmnsh, the replication package
the paper cites as [18], into ./osf/, and checks each file against the SHA-256
that OSF reports and against SHA256SUMS in this folder.

The project carries no license, so the files are not redistributed in this
repo: ./osf/ is gitignored. Run this script to get the same copy.

Usage: python3 fetch.py

Written 24 September 2026.
"""
import hashlib
import json
import os
import sys
import urllib.request

NODE = 'vmnsh'
KEY = 'c8e26e10cbf145839bfa6820de76792d'  # view-only key, printed in the paper
HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.join(HERE, 'osf')


def get_json(url):
    if 'view_only=' not in url:
        url += ('&' if '?' in url else '?') + 'view_only=' + KEY
    with urllib.request.urlopen(url, timeout=120) as r:
        return json.load(r)


def listing(url, prefix=''):
    while url:
        d = get_json(url)
        for f in d['data']:
            a = f['attributes']
            path = prefix + a['name']
            if a['kind'] == 'folder':
                yield from listing(f['relationships']['files']['links']['related']['href'], path + '/')
            else:
                yield path, a['size'], a['extra']['hashes']['sha256'], f['links']['download']
        url = d['links'].get('next')


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as fh:
        for block in iter(lambda: fh.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def main():
    expected = {}
    sums = os.path.join(HERE, 'SHA256SUMS')
    if os.path.exists(sums):
        for line in open(sums):
            digest, path = line.rstrip('\n').split('  ', 1)
            expected[path] = digest
    files = list(listing(f'https://api.osf.io/v2/nodes/{NODE}/files/osfstorage/'))
    bad = 0
    for path, size, digest, url in files:
        target = os.path.join(DEST, path)
        if not (os.path.exists(target) and sha256(target) == digest):
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with urllib.request.urlopen(url, timeout=600) as r, open(target + '.part', 'wb') as out:
                while block := r.read(1 << 20):
                    out.write(block)
            os.replace(target + '.part', target)
        got = sha256(target)
        ok = got == digest and expected.get(path, digest) == digest
        bad += not ok
        print(f'{"ok " if ok else "BAD"} {size:>10} {path}')
    missing = set(expected) - {p for p, *_ in files}
    for p in sorted(missing):
        print(f'GONE {p} (in SHA256SUMS, no longer on OSF)')
    sys.exit(1 if bad or missing else 0)


if __name__ == '__main__':
    main()
