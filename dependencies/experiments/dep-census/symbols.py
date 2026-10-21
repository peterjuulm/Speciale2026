"""Look up the PDBs that the census did not find in the packages, on symbol servers.

For every shipped managed DLL of a census C2b package (the DLL points to a PDB
that is not in the package), asks Microsoft's symbol server and nuget.org's
for the PDB with the DLL's exact ID, using the Simple Symbol Query Protocol key
<pdb name>/<GUID><age, or FFFFFFFF for a portable PDB>/<pdb name>. nuget.org's
server also needs the DLL's PdbChecksum in a SymbolChecksum header.

  probe:    asks both servers and records found or not, and the size. Downloads
            nothing.
  download: fetches each found PDB once (Microsoft's first), checks that its
            PDB ID matches the DLL's CodeView GUID, and reads the compiler
            record and Source Link. Then sorts each package again.

Usage: python3 -I symbols.py probe|download CENSUS_DIR PDB_DIR OUTDIR
CENSUS_DIR holds census.csv and census.files.csv. PDB_DIR keeps the downloaded
PDBs (bytes, never in git). Writes OUTDIR/symbols.csv (one row per DLL) and,
after download, OUTDIR/symbols.md.

Written 13 October 2026.
"""
import collections, concurrent.futures, csv, os, re, struct, sys, urllib.error, urllib.request

mode, census_dir, pdb_dir, outdir = sys.argv[1:5]
SERVERS = [('microsoft', 'https://msdl.microsoft.com/download/symbols/'),
           ('nuget', 'https://symbols.nuget.org/download/symbols/')]
UA = {'User-Agent': 'speciale2026-dependency-census'}

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k): return None
no_redirect = urllib.request.build_opener(NoRedirect)

def key(x):
    name = x['pdb_name'].lower()
    sfx = 'ffffffff' if x['portable'] == 'yes' else format(int(x['age']), 'x')
    return f"{name}/{x['guid'].lower()}{sfx}/{name}"

def ask(base, x):
    """Return (found, redirect URL, size). One request, plus one HEAD on the blob for the size."""
    headers = dict(UA)
    if base.startswith('https://symbols.nuget.org') and x['checksum']:
        headers['SymbolChecksum'] = x['checksum']
    for attempt in range(3):
        try:
            r = no_redirect.open(urllib.request.Request(base + key(x), headers=headers), timeout=60)
            r.close()
            return 'yes', base + key(x), r.headers.get('Content-Length', '')   # served directly
        except urllib.error.HTTPError as e:
            if e.code in (301, 302, 307, 308):
                loc = e.headers['Location']
                try:
                    h = urllib.request.urlopen(urllib.request.Request(loc, method='HEAD', headers=UA), timeout=60)
                    return 'yes', loc, h.headers.get('Content-Length', '')
                except urllib.error.HTTPError:
                    return 'yes', loc, ''
            if e.code == 404: return 'no', '', ''
            if attempt == 2: return f'error {e.code}', '', ''
        except OSError as e:
            if attempt == 2: return f'error {type(e).__name__}', '', ''

def pdb_details(pdb, x):
    """Check the PDB ID against the DLL, and read the compiler record and Source Link."""
    if pdb[:4] != b'BSJB':
        return {'format': 'windows' if pdb.startswith(b'Microsoft C/C++ MSF') else 'unknown',
                'id_match': 'not checked', 'compiler': '', 'sourcelink': ''}
    vlen, = struct.unpack_from('<I', pdb, 12)
    pos = 16 + vlen
    _, nstreams = struct.unpack_from('<HH', pdb, pos); pos += 4
    pdb_id = None
    for _ in range(nstreams):
        off, size = struct.unpack_from('<II', pdb, pos); pos += 8
        end = pdb.index(b'\0', pos); name = pdb[pos:end]; pos = (end + 4) & ~3
        if name == b'#Pdb': pdb_id = pdb[off:off + 20]
    match = ''
    if pdb_id:
        d1, d2, d3 = struct.unpack_from('<IHH', pdb_id, 0)
        match = 'yes' if f'{d1:08X}{d2:04X}{d3:04X}' + pdb_id[8:16].hex().upper() == x['guid'] else 'NO'
    i = pdb.find(b'compiler-version\0')
    compiler = pdb[i + 17:pdb.find(b'\0', i + 17)].decode('utf-8', 'replace') if i >= 0 else ''
    return {'format': 'portable', 'id_match': match, 'compiler': compiler,
            'sourcelink': 'yes' if re.search(rb'"documents"\s*:', pdb) else 'no'}

census = {(r['package'], r['version']): r for r in csv.DictReader(open(os.path.join(census_dir, 'census.csv')))}
dlls = [x for x in csv.DictReader(open(os.path.join(census_dir, 'census.files.csv')))
        if census[(x['package'], x['version'])]['category'] == 'C2b' and x['pdb'] == 'not in package']
os.makedirs(outdir, exist_ok=True)
out_csv = os.path.join(outdir, 'symbols.csv')

if mode == 'probe':
    def probe(x):
        row = {k: x[k] for k in ('package', 'version', 'file', 'pdb_name', 'guid', 'age', 'portable')}
        row['key'] = key(x)
        for name, base in SERVERS:
            found, url, size = ask(base, x)
            row[f'{name}'], row[f'{name}_url'], row[f'{name}_size'] = found, url, size
        return row
    with concurrent.futures.ThreadPoolExecutor(8) as ex:
        rows = list(ex.map(probe, dlls))
    with open(out_csv, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
    c = collections.Counter((r['microsoft'], r['nuget']) for r in rows)
    size = sum(int(r['microsoft_size'] or r['nuget_size'] or 0) for r in rows if 'yes' in (r['microsoft'], r['nuget']))
    print(f'{len(rows)} DLLs. (microsoft, nuget): {dict(c)}. To download: '
          f'{sum(1 for r in rows if "yes" in (r["microsoft"], r["nuget"]))} PDBs, {size / 1e6:.1f} MB')

elif mode == 'download':
    rows = list(csv.DictReader(open(out_csv)))
    os.makedirs(pdb_dir, exist_ok=True)
    def fetch(r):
        src = 'microsoft' if r['microsoft'] == 'yes' else 'nuget' if r['nuget'] == 'yes' else ''
        r['source'] = src
        if not src: return r
        path = os.path.join(pdb_dir, r['key'].replace('/', '_'))
        if not os.path.exists(path):
            data = urllib.request.urlopen(urllib.request.Request(r[f'{src}_url'], headers=UA), timeout=300).read()
            open(path, 'wb').write(data)
        x = {'guid': r['guid']}
        r.update(pdb_details(open(path, 'rb').read(), x))
        return r
    with concurrent.futures.ThreadPoolExecutor(8) as ex:
        rows = list(ex.map(fetch, rows))
    fields = list(rows[0]) + [k for k in ('format', 'id_match', 'compiler', 'sourcelink') if k not in rows[0]]
    with open(out_csv, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=fields, restval=''); w.writeheader(); w.writerows(rows)

    # Sort each C2b package again: all its DLLs found with a compiler record -> R.
    per = collections.defaultdict(list)
    for r in rows: per[(r['package'], r['version'])].append(r)
    def verdict(rs):
        if all(r.get('compiler') for r in rs): return 'R2', 'All PDBs found, with compiler record'
        if all(r['source'] for r in rs): return 'S1', 'All PDBs found, but not all have a compiler record (Windows-format PDBs carry none)'
        if any(r['source'] for r in rs): return 'S2', 'Some PDBs found'
        return 'S3', 'No PDB on either server'
    pk = {k: verdict(v) for k, v in per.items()}
    counts = collections.Counter((pk[k][0], census[k]['owner']) for k in pk)
    labels = {v[0]: v[1] for v in pk.values()}
    srv = collections.Counter((r['microsoft'], r['nuget']) for r in rows)
    with open(os.path.join(outdir, 'symbols.md'), 'w') as f:
        p = lambda *a: print(*a, file=f)
        p('# The C2b packages on the symbol servers\n')
        p(f'Generated by `dependencies/experiments/dep-census/symbols.py`. {len(per)} packages, {len(rows)} DLLs whose PDB '
          'is not in the package.\n')
        p('| Result | Meaning | Microsoft | Third-party | Total |\n| --- | --- | ---: | ---: | ---: |')
        for v in ('R2', 'S1', 'S2', 'S3'):
            if v in labels:
                p(f'| {v} | {labels[v]} | {counts[(v, "Microsoft")]} | {counts[(v, "third-party")]} '
                  f'| {counts[(v, "Microsoft")] + counts[(v, "third-party")]} |')
        p('\n**Per DLL (Microsoft server, nuget.org server):** ' + '; '.join(f'{a}/{b} {n}' for (a, b), n in srv.most_common()))
        p('\n**PDB ID matches the DLL:** ' + '; '.join(f'{k or "-"} {v}' for k, v in collections.Counter(r.get('id_match', '') for r in rows).most_common()))
        p('\n## Per package\n')
        p('| Result | Package | Version | Owner | DLLs | Found | With compiler | Server | Compiler |')
        p('| --- | --- | --- | --- | ---: | ---: | ---: | --- | --- |')
        for k in sorted(per, key=lambda k: (pk[k][0], census[k]['owner'], k[0].lower())):
            rs = per[k]
            p(f"| {pk[k][0]} | {k[0]} | {k[1]} | {census[k]['owner']} | {len(rs)} | {sum(1 for r in rs if r['source'])} "
              f"| {sum(1 for r in rs if r.get('compiler'))} | {', '.join(sorted({r['source'] for r in rs if r['source']}))} "
              f"| {', '.join(sorted({r['compiler'].split('+')[0] for r in rs if r.get('compiler')}))} |")
    print(f'{len(per)} packages: {dict(collections.Counter(v[0] for v in pk.values()))}')
