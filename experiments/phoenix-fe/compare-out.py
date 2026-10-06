#!/usr/bin/env python3
"""Compare two static exports of the frontend.

    compare-out.py DIR1 DIR2 [ID1 ID2]

Prints how many files each tree has, which are only in one of them, and
which differ, with the differing files counted by extension. Given the two
build IDs, it compares again after replacing each tree's ID with BUILD_ID in
paths and contents, so whatever still differs has another cause.

Exit status 0 when the trees are equal (after the replacement, if IDs are
given), 1 otherwise.
"""

import collections
import hashlib
import os
import sys


def read_tree(root, build_id=None):
    files = {}
    for folder, _, names in os.walk(root):
        for name in names:
            path = os.path.join(folder, name)
            rel = os.path.relpath(path, root)
            with open(path, 'rb') as f:
                data = f.read()
            if build_id:
                rel = rel.replace(build_id, 'BUILD_ID')
                data = data.replace(build_id.encode(), b'BUILD_ID')
            files[rel] = hashlib.sha256(data).hexdigest()
    return files


def compare(first, second, title):
    only_first = sorted(set(first) - set(second))
    only_second = sorted(set(second) - set(first))
    differ = sorted(p for p in set(first) & set(second) if first[p] != second[p])
    print(f'{title}: {len(first)} and {len(second)} files, '
          f'{len(only_first)} only in the first, {len(only_second)} only in the second, '
          f'{len(differ)} differ')
    if differ:
        kinds = collections.Counter(os.path.splitext(p)[1] or '(none)' for p in differ)
        print('  differing, by extension:', ', '.join(f'{k} {n}' for k, n in kinds.most_common()))
    for p in only_first[:10]:
        print('  only in the first: ', p)
    for p in only_second[:10]:
        print('  only in the second:', p)
    for p in differ[:20]:
        print('  differs:           ', p)
    return not (only_first or only_second or differ)


def main():
    if len(sys.argv) not in (3, 5):
        sys.exit(__doc__)
    first, second = sys.argv[1], sys.argv[2]
    equal = compare(read_tree(first), read_tree(second), 'as built')
    if len(sys.argv) == 5:
        id1, id2 = sys.argv[3], sys.argv[4]
        print(f'build IDs: {id1} and {id2}')
        equal = compare(read_tree(first, id1), read_tree(second, id2), 'build ID replaced')
    sys.exit(0 if equal else 1)


main()
