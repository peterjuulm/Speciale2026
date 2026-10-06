#!/usr/bin/env python3
"""List the files outside ClientApp that the frontend's source imports.

    import-closure.py LAB

LAB is an export of the whole commit. Follows every relative import, export
from, require and dynamic import in ClientApp's .ts/.tsx/.js/.jsx files (not
node_modules, .next or out), and on through the files it reaches outside
ClientApp. Prints those files, the ClientApp files that import them (tests
counted apart), and the packages the outside files import.

It reads import statements with a regex, so it cannot tell an import used
only for types, which the compiler erases, from one that is bundled. Next's
trace answers that; see trace-modules.py.
"""

import os
import re
import sys

IMPORT = re.compile(r'''(?:import|export)\s[^'"]*?from\s*['"]([^'"]+)['"]'''
                    r'''|import\s*['"]([^'"]+)['"]'''
                    r'''|(?:require|import)\(\s*['"]([^'"]+)['"]\s*\)''')
SUFFIXES = ['', '.ts', '.tsx', '.js', '.jsx', '.d.ts', '.json', '/index.ts', '/index.tsx', '/index.js']
TEST = re.compile(r'\.(spec|test)\.[jt]sx?$')


def imports(path):
    with open(path, encoding='utf-8', errors='replace') as f:
        return [a or b or c for a, b, c in IMPORT.findall(f.read())]


def resolve(importer, spec):
    base = os.path.normpath(os.path.join(os.path.dirname(importer), spec))
    for suffix in SUFFIXES:
        if os.path.isfile(base + suffix):
            return base + suffix
    return None


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    lab = os.path.abspath(sys.argv[1])
    app = os.path.join(lab, 'src/WebAPI/ClientApp') + '/'

    sources = []
    for folder, dirs, names in os.walk(app):
        dirs[:] = [d for d in dirs if d not in ('node_modules', '.next', 'out')]
        sources += [os.path.join(folder, n) for n in names if n.endswith(('.ts', '.tsx', '.js', '.jsx'))]

    outside = set()
    importers = set()
    packages = {}
    todo = [(f, True) for f in sources]
    while todo:
        path, inside = todo.pop()
        for spec in imports(path):
            if not spec.startswith('.'):
                if not inside:
                    packages.setdefault(spec, set()).add(os.path.relpath(path, lab))
                continue
            target = resolve(path, spec)
            if target is None or target.startswith(app):
                continue
            if inside:
                importers.add(path)
            if target not in outside:
                outside.add(target)
                todo.append((target, False))

    print(f'ClientApp source files: {len(sources)}')
    print(f'files outside ClientApp in the import closure: {len(outside)}')
    for path in sorted(outside):
        print('  ', os.path.relpath(path, lab))
    tests = sum(1 for p in importers if TEST.search(p))
    print(f'ClientApp files importing them: {len(importers)}, {tests} of them tests')
    print('packages imported by the outside files:')
    for name in sorted(packages):
        print('  ', name, 'from', ', '.join(sorted(packages[name])))


main()
