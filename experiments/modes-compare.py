"""Compare two mode lists ("<mode> <path>" per line) and group the files
whose mode differs.

Usage: python3 modes-compare.py A.txt B.txt

Written 24 September 2026 for phoenix-layer2-reprotest.
"""
import collections, sys
def load(p):
    return dict(reversed(l.rstrip('\n').split(' ', 1)) for l in open(p))
a, b = load(sys.argv[1]), load(sys.argv[2])
print(f'{len(a)} vs {len(b)} files; same names: {set(a) == set(b)}')
diff = collections.defaultdict(list)
for p in sorted(set(a) & set(b)):
    if a[p] != b[p]:
        diff[a[p], b[p]].append(p)
print('differing modes:', sum(len(v) for v in diff.values()))
for (ma, mb), ps in sorted(diff.items()):
    print(f'  {ma} -> {mb}: {len(ps)}')
    for p in ps: print('     ', p)
same = collections.Counter(a[p] for p in a if p in b and a[p] == b[p])
print('unchanged modes:', dict(same))
