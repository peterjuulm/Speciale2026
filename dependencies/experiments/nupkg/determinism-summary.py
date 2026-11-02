"""Tables for the determinism experiment's result note, from the lab's state files.

    python3 -I determinism-summary.py LAB [OUTDIR]

Writes (to OUTDIR, default LAB) `summary.md` with:
  1. population: screened / excluded / not built, with causes
  2. per axis, as is: how many packages differ at each boundary
  3. per package, the Figure-4 category at each boundary (as is / with configuration / unreproducible / not reached)
  4. the packages the configuration does not fix, with the first difference
and `packages.tsv` with one row per package and the category columns.

Category rules, per boundary B in {1 whole file, 2 content, 3 DLLs}:
  as is            every per-axis as-is run is `same` at B
  with configuration   not as is; every as-is run that differed at B has a configured run that is `same` at B, or
                   differed on entry timestamps only and the configured `time` run is `same` at B
  unreproducible   some configured run differs or fails at B
  not reached      per-axis runs missing (pass B did not get to the package)
"""
import collections, json, os, sys

AXES = ['build_path', 'environment', 'locales', 'exec_path', 'time', 'timezone', 'umask', 'fileordering']


def category(runs, b):
    asis = {a: runs.get(f'asis:{a}') for a in AXES}
    if any(v is None for v in asis.values()):
        return 'not reached'
    if all(v[b] == 'same' for v in asis.values()):
        return 'as is'
    for a, v in asis.items():
        if v[b] == 'same':
            continue
        c = runs.get(f'configured:{a}')
        if c is None:
            # timestamps-only at boundary 1 is covered by the configured `time` run
            if b == 'b1' and v['b2'] == 'same' and v['b3'] == 'same':
                c = runs.get('configured:time')
            if c is None:
                return 'not reached'
        if c[b] != 'same':
            return 'unreproducible'
    return 'with configuration'


def main():
    lab = os.path.abspath(sys.argv[1])
    outdir = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else lab
    states = []
    for pid in sorted(os.listdir(os.path.join(lab, 'out'))):
        f = os.path.join(lab, 'out', pid, 'state.json')
        if os.path.exists(f):
            s = json.load(open(f))
            s['id'] = pid
            states.append(s)
    built = [s for s in states if s.get('screen') == 'built']
    excluded = [s for s in states if s.get('screen') == 'excluded']
    failed = [s for s in states if s.get('screen') not in ('built', 'excluded', None)]
    lines = [f'# Determinism experiment, summary ({len(states)} packages)', '']

    lines += ['## 1. Population', '', '| outcome | packages |', '|---|---|',
              f'| built under the fixed SDK | {len(built)} |',
              f'| excluded before the screen (batch 3 causes) | {len(excluded)} |',
              f'| did not build (first error logged) | {len(failed)} |', '']
    lines += ['Excluded, by cause:', '']
    for cause, n in collections.Counter(s['screen_error'].split(';')[0][:90] for s in excluded).most_common():
        lines.append(f'- {n}: {cause}')
    lines += ['', 'Did not build:', '']
    for s in failed:
        lines.append(f'- {s["recipe"]["package"]} {s["recipe"]["version"]}: {s.get("screen")}; {s.get("screen_error", "")[:140]}')
    lines.append('')

    lines += ['## 2. Per axis, as is: packages that differ', '',
              '| axis | runs | differs at 1 (whole file) | differs at 2 (content) | differs at 3 (DLL) | build failed |', '|---|---|---|---|---|---|']
    for a in AXES:
        vs = [s['runs'][f'asis:{a}'] for s in built if f'asis:{a}' in s.get('runs', {})]
        lines.append(f'| {a} | {len(vs)} | {sum(v["b1"] == "differs" for v in vs)} | {sum(v["b2"] == "differs" for v in vs)} | '
                     f'{sum(v["b3"] == "differs" for v in vs)} | {sum(v["b1"] == "failed" for v in vs)} |')
    vs = [s['runs']['asis:all'] for s in built if 'asis:all' in s.get('runs', {})]
    lines.append(f'| all eight at once | {len(vs)} | {sum(v["b1"] == "differs" for v in vs)} | {sum(v["b2"] == "differs" for v in vs)} | '
                 f'{sum(v["b3"] == "differs" for v in vs)} | {sum(v["b1"] == "failed" for v in vs)} |')
    lines.append('')

    lines += ['## 3. Per package category, by boundary', '']
    cats = {}
    for s in built:
        cats[s['id']] = {b: category(s.get('runs', {}), b) for b in ('b1', 'b2', 'b3')}
    order = ['as is', 'with configuration', 'unreproducible', 'not reached']
    lines += ['| boundary | ' + ' | '.join(order) + ' |', '|---|' + '---|' * len(order)]
    for b, name in (('b1', '1 whole file'), ('b2', '2 content'), ('b3', '3 DLLs')):
        c = collections.Counter(cats[i][b] for i in cats)
        lines.append(f'| {name} | ' + ' | '.join(str(c.get(o, 0)) for o in order) + ' |')
    lines.append('')

    lines += ['## 4. Not fixed by the configuration (boundary 3, DLLs)', '']
    for s in built:
        if cats[s['id']]['b3'] != 'unreproducible':
            continue
        bad = []
        for a in AXES:
            c = s['runs'].get(f'configured:{a}')
            if c and c['b3'] != 'same':
                bad.append(f'{a}: {c["b3"]}' + (f' ({c["first"]})' if c.get('first') else '') + (f' [{c["note"][:80]}]' if c.get('note') else ''))
        lines.append(f'- {s["recipe"]["package"]} {s["recipe"]["version"]}: ' + '; '.join(bad))
    lines.append('')

    lines += ['## 5. Identical DLLs under every axis as is (boundary 3 "as is")', '']
    for s in built:
        if cats[s['id']]['b3'] == 'as is':
            lines.append(f'- {s["recipe"]["package"]} {s["recipe"]["version"]}')
    lines.append('')

    os.makedirs(outdir, exist_ok=True)
    open(os.path.join(outdir, 'summary.md'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    with open(os.path.join(outdir, 'packages.tsv'), 'w', encoding='utf-8') as f:
        f.write('package\tversion\trepo\tscreen\tglobal_json\tcat_whole_file\tcat_content\tcat_dll\taxes_run\tfirst_difference_all_axes\n')
        for s in states:
            c = cats.get(s['id'], {})
            runs = s.get('runs', {})
            f.write('\t'.join([s['recipe']['package'], s['recipe']['version'], s['recipe']['repo'], s.get('screen', ''), s.get('global_json', ''),
                               c.get('b1', ''), c.get('b2', ''), c.get('b3', ''), str(sum(1 for k in runs if k.startswith('asis:') and k != 'asis:all')),
                               runs.get('asis:all', {}).get('first', '')]) + '\n')
    print('\n'.join(lines[:60]))


if __name__ == '__main__':
    main()
