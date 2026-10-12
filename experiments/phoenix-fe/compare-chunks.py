#!/usr/bin/env python3
"""Compare two chunk logs of module-order-plugin.js (MODULE_CHUNK_LOG=1).

Each log line: id, name, number of modules, hash of the sorted module
identifiers, hash of the root modules, ids. Prints the chunks whose module
set occurs in only one log, and the module sets that got other ids.

Usage: compare-chunks.py A-chunks.txt B-chunks.txt
Written 12 October 2026 for W51.
"""
import collections
import sys


def load(path):
    rows = [line.split() for line in open(path) if line.strip()]
    by_set = collections.defaultdict(list)
    for pos, (cid, name, n, mods, roots, ids) in enumerate(rows):
        by_set[(name, mods)].append((cid, int(n), roots, ids, pos))
    return rows, by_set


a_rows, a = load(sys.argv[1])
b_rows, b = load(sys.argv[2])
print(f'chunks: {len(a_rows)} and {len(b_rows)}')
for key in sorted(set(a) - set(b)):
    print('only in A:', key[0], key[1], a[key])
for key in sorted(set(b) - set(a)):
    print('only in B:', key[0], key[1], b[key])
for key in sorted(set(a) & set(b)):
    ida = sorted(x[0] for x in a[key])
    idb = sorted(x[0] for x in b[key])
    if ida != idb or [x[3] for x in a[key]] != [x[3] for x in b[key]]:
        print('other ids:', key[0], key[1], 'A', a[key], 'B', b[key])
