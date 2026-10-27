"""Check a batch list against its derivations: nothing lost, nothing merged.

Usage: python3 -I check-batch.py LIST [DERIVE_OUT]

Checks, and exits 1 on the first failure:
 - every "Package Version" line of LIST is a distinct pair (the same package
   in two versions is allowed; the same pair twice is not);
 - with DERIVE_OUT: batch.txt has exactly one row per pair, in the list's
   order, and every pair has its own folder <Package>-<version> holding
   facts.txt (derived or skipped) or error.txt (derive.py failed).

Prints one line: the counts. Written 27 October 2026, after the Microsoft
list (139 pairs, 129 names) showed that keying by name alone drops ten.
"""
import os, sys


def pairs(path):
    out = []
    for raw in open(path, encoding='utf-8'):
        raw = raw.split('#')[0].strip()
        if raw:
            out.append(tuple(raw.split()))
    return out


def main():
    lst = pairs(sys.argv[1])
    if len(set(lst)) != len(lst):
        dup = sorted({p for p in lst if lst.count(p) > 1})
        sys.exit(f'FAIL: pairs listed twice: {dup}')
    names = {p for p, _ in lst}
    msg = f'{len(lst)} pairs, {len(names)} names, {len(lst) - len(names)} names in more than one version'
    if len(sys.argv) > 2:
        out = sys.argv[2]
        if not os.path.exists(os.path.join(out, 'batch.txt')):
            sys.exit(f'FAIL: {out} has no batch.txt (derivation did not finish)')
        rows = [l.rstrip('\n').split('\t') for l in open(os.path.join(out, 'batch.txt'), encoding='utf-8')][1:]
        got = [tuple(r[0].split()) for r in rows]
        if got != lst:
            missing = [p for p in lst if p not in got]; extra = [p for p in got if p not in lst]
            sys.exit(f'FAIL: batch.txt differs from the list: missing {missing}, extra {extra}, order {"ok" if sorted(got) == sorted(lst) else "differs"}')
        for pkg, ver in lst:
            d = os.path.join(out, f'{pkg}-{ver}')
            if not (os.path.exists(os.path.join(d, 'facts.txt')) or os.path.exists(os.path.join(d, 'error.txt'))):
                sys.exit(f'FAIL: no derivation folder with facts.txt or error.txt for {pkg} {ver} ({d})')
        derived = sum(1 for r in rows if r[1].startswith('derived'))
        msg += f'; batch.txt {len(rows)} rows, {derived} derived, one folder per pair'
    print('OK: ' + msg)


if __name__ == '__main__':
    main()
