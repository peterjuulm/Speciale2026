"""For every stored as-is run whose verdict is 'entry timestamps only' (b1 differs, b2 same): compare the two
packages' ZIP central directories field by field and report which fields differ. Run 1 November 2026 23:35 (557 pairs) and again 2 November 07:05 after worker 1 ended:
584 pairs checked, every one differs in date_time only.

    python3 -I zip-metadata-check.py LAB
"""
import json, os, sys, zipfile, collections
AX = ['build_path', 'environment', 'locales', 'exec_path', 'time', 'timezone', 'umask', 'fileordering']
FIELDS = ['compress_type', 'CRC', 'file_size', 'compress_size', 'external_attr', 'flag_bits', 'extra', 'comment',
          'create_system', 'create_version', 'extract_version', 'internal_attr']
lab = sys.argv[1]
res, examples, checked = collections.Counter(), {}, 0
for pid in sorted(os.listdir(f'{lab}/out')):
    f = f'{lab}/out/{pid}/state.json'
    if not os.path.exists(f):
        continue
    runs = json.load(open(f)).get('runs', {})
    for a in AX:
        v = runs.get(f'asis:{a}')
        if not v or not (v['b1'] == 'differs' and v['b2'] == 'same'):
            continue
        st = f'{lab}/out/{pid}/asis-{a}-store'
        def pk(side):
            d = f'{st}/{side}/source-root/out'
            return sorted(x for x in os.listdir(d) if x.endswith('.nupkg')) if os.path.isdir(d) else []
        ca, cb = pk('control'), pk('experiment-1')
        if not ca or not cb:
            res['no stored package'] += 1
            continue
        ia = zipfile.ZipFile(f'{st}/control/source-root/out/{ca[0]}').infolist()
        ib = zipfile.ZipFile(f'{st}/experiment-1/source-root/out/{cb[0]}').infolist()
        checked += 1
        kinds = set()
        if [i.filename for i in ia] != [i.filename for i in ib]:
            kinds.add('entry order/names')
        for x, y in zip(ia, ib):
            if x.filename != y.filename:
                continue
            for fld in FIELDS:
                if getattr(x, fld) != getattr(y, fld):
                    kinds.add(fld)
            if x.date_time != y.date_time:
                kinds.add('date_time')
        k = ', '.join(sorted(kinds)) or 'nothing in the central directory'
        res[k] += 1
        examples.setdefault(k, (pid, a))
print('pairs checked:', checked)
for k, n in res.most_common():
    print(f'{n:4d}  {k}   e.g. {examples.get(k)}')
