#!/usr/bin/env python3
"""List the modules outside ClientApp that webpack built, from Next's trace.

    trace-modules.py TRACE LAB

TRACE is .next/trace from a build of the export in LAB. Next records one
build-module event per module it compiles, with the module's path and its
layer: pages-dir-browser for the bundle the browser gets, pages-dir-node for
the server-side prerender. Prints the modules outside ClientApp, with their
layers.
"""

import json
import os
import sys


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    trace = sys.argv[1]
    lab = os.path.abspath(sys.argv[2]) + '/'
    app = lab + 'src/WebAPI/ClientApp/'

    built = {}
    inside = 0
    with open(trace) as f:
        for line in f:
            try:
                events = json.loads(line)
            except ValueError:
                continue
            for event in events if isinstance(events, list) else [events]:
                tags = event.get('tags') or {}
                path = str(tags.get('name') or '').split('?')[0]
                if not event.get('name', '').startswith('build-module') or not path.startswith(lab):
                    continue
                if path.startswith(app):
                    inside += 1
                    continue
                built.setdefault(path[len(lab):], set()).add(str(tags.get('layer')))

    print(f'module builds inside ClientApp: {inside}')
    print(f'modules outside ClientApp: {len(built)}')
    for path in sorted(built):
        print('  ', path, ', '.join(sorted(built[path])))


main()
