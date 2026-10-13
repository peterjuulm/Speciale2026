"""Census of a .NET project's NuGet packages: what each one declares for a rebuild.

The scope is what the self-contained publish of the PROGRAMs ships for RID:
the packages in each program's lock file, plus the runtime and host packs the
SDK downloads for RID (they are not in the lock files). For each package it
takes the files it ships (from project.assets.json) and opens them in the
NuGet cache. No network, no builds.

Each TOOL named with --tool (a local tool from .config/dotnet-tools.json whose
output ships, such as dotnet-ef) is in scope too, with all its files.

Everything else under REPO (the other src projects' lock files, tests/, the
lock sections and packs for other RIDs, the other local tools) is listed in
scope.md with the reason it is left out.

For each package it records: the repository and commit from the .nuspec,
whether the shipped files are IL or native, where the PDB is (embedded, in
the package, only referenced, none), the compiler record in the PDB, the
Reproducible and PdbChecksum debug entries, Source Link, and signatures.
Then it puts the package in one category (see CATEGORIES).

Usage: python3 -I census.py REPO NUGET_CACHE OUTDIR RID PROGRAM... [--tool NAME]...
Writes OUTDIR/census.csv, OUTDIR/census.md, OUTDIR/scope.md, and
OUTDIR/census.files.csv: one row per shipped managed DLL with its PDB identity
(CodeView name, GUID, age, portable or not, PdbChecksum), for symbol servers.

Written 12 October 2026. Same day: scope narrowed from all src projects to
the programs, runtime packs added. 13 October: the target framework is read
from the assets file (.NET 10), only the lock sections for RID count as
shipped, and --tool added.
"""
import collections, csv, glob, json, os, re, struct, sys, zlib

repo, cache, outdir, rid = sys.argv[1:5]
rest = sys.argv[5:]
tools_in = [rest[i + 1] for i, a in enumerate(rest) if a == '--tool']
programs = [a for i, a in enumerate(rest) if a != '--tool' and (i == 0 or rest[i - 1] != '--tool')]
tfm = list(json.load(open(os.path.join(repo, 'src', programs[0], 'obj', 'project.assets.json')))['project']['frameworks'])[0]
target = f'{tfm}/{rid}'
# A Mac restore of a project with PublishSingleFile and no RuntimeIdentifier adds
# the host RID to the lock file (NU1004 in locked mode). That section is not in
# the commit and is not read.
IGNORED_SECTIONS = {f'{tfm}/osx-arm64', f'{tfm}/osx-x64'}

CATEGORIES = [
    ('N0', 'Ships no files', 'Nothing reaches the release: a meta package, or build-time only'),
    ('N1', 'Native code only', 'Only machine code from a C/C++ build. Scope open'),
    ('C1a', 'No repository declared', 'The .nuspec names no source repository'),
    ('C1b', 'Repository, but no commit', 'The .nuspec names a repository, not the commit'),
    ('C2a', 'No PDB at all', 'The DLL does not point to any PDB'),
    ('C2b', 'PDB not in the package', 'The DLL points to a PDB that is not in the package. Maybe on a symbol server'),
    ('C2c', 'PDB without compiler record', 'A PDB is in the package, but it does not record the compiler'),
    ('R', 'Ready to rebuild', 'Commit and compiler record both declared'),
]

# --- PE and PDB reading -----------------------------------------------------

def pe_info(data):
    """Return None if not a PE file, else a dict of what we need."""
    if data[:2] != b'MZ': return None
    pe = struct.unpack_from('<I', data, 0x3c)[0]
    if data[pe:pe + 4] != b'PE\0\0': return None
    nsec, = struct.unpack_from('<H', data, pe + 6)
    optsize, = struct.unpack_from('<H', data, pe + 20)
    opt = pe + 24
    magic, = struct.unpack_from('<H', data, opt)
    dd = opt + (96 if magic == 0x10b else 112)
    dirs = [struct.unpack_from('<II', data, dd + 8 * i) for i in range(16)]
    secs = []
    for i in range(nsec):
        s = opt + optsize + 40 * i
        vsize, va, rawsize, rawptr = struct.unpack_from('<IIII', data, s + 8)
        secs.append((va, max(vsize, rawsize), rawptr))
    def off(rva):
        for va, size, raw in secs:
            if va <= rva < va + size: return rva - va + raw
        return None
    info = {'managed': False, 'authenticode': dirs[4][1] > 0, 'strongname': False,
            'codeview': None, 'embedded': None, 'reproducible': False, 'pdbchecksum': False,
            'cv_guid': '', 'cv_age': 0, 'cv_portable': False, 'checksum': ''}
    clr_rva, clr_size = dirs[14]
    if clr_size:
        info['managed'] = True
        o = off(clr_rva)
        if o is not None:
            flags, = struct.unpack_from('<I', data, o + 16)
            info['strongname'] = bool(flags & 0x8)
    dbg_rva, dbg_size = dirs[6]
    o = off(dbg_rva) if dbg_size else None
    for i in range((dbg_size // 28) if o is not None else 0):
        _, _, major, minor, typ, size, _, ptr = struct.unpack_from('<IIHHIIII', data, o + 28 * i)
        if typ == 2 and data[ptr:ptr + 4] == b'RSDS':
            info['codeview'] = data[ptr + 24:ptr + size].split(b'\0')[0].decode('utf-8', 'replace')
            d1, d2, d3 = struct.unpack_from('<IHH', data, ptr + 4)
            info['cv_guid'] = f'{d1:08X}{d2:04X}{d3:04X}' + data[ptr + 12:ptr + 20].hex().upper()
            info['cv_age'], = struct.unpack_from('<I', data, ptr + 20)
            info['cv_portable'] = minor == 0x504D   # 'PM': a portable PDB
        elif typ == 16:
            info['reproducible'] = True
        elif typ == 17 and data[ptr:ptr + 4] == b'MPDB':
            try: info['embedded'] = zlib.decompress(data[ptr + 8:ptr + size], -15)
            except zlib.error: info['embedded'] = b''
        elif typ == 19:
            info['pdbchecksum'] = True
            alg, _, digest = data[ptr:ptr + size].partition(b'\0')
            info['checksum'] = alg.decode() + ':' + digest.hex().upper()
    return info

def pdb_info(pdb):
    if pdb[:4] != b'BSJB':
        return {'format': 'windows' if pdb.startswith(b'Microsoft C/C++ MSF') else 'unknown',
                'compiler': '', 'sourcelink': False}
    i = pdb.find(b'compiler-version\0')
    compiler = pdb[i + 17:pdb.find(b'\0', i + 17)].decode('utf-8', 'replace') if i >= 0 else ''
    return {'format': 'portable', 'compiler': compiler,
            'sourcelink': re.search(rb'"documents"\s*:', pdb) is not None}

# --- The package graph -----------------------------------------------------

def lock_graph(path, sections=None):
    out = {}
    for section, deps in json.load(open(path))['dependencies'].items():
        if section in IGNORED_SECTIONS or (sections is not None and section not in sections): continue
        for name, v in deps.items():
            if v['type'] != 'Project':
                out.setdefault((name.lower(), v['resolved'].lower()), [name, v['resolved'], set()])[2].add(v['type'])
    return out

packages, kind, direct, shipped = {}, {}, set(), collections.defaultdict(set)
# Direct: named in one of our own .csproj files, the libraries' included.
declared = {k[0] for lock in glob.glob(os.path.join(repo, 'src', '*', 'packages.lock.json'))
            for k, (_, _, types) in lock_graph(lock).items() if 'Direct' in types}
for prog in programs:
    for k, (name, ver, types) in lock_graph(os.path.join(repo, 'src', prog, 'packages.lock.json'), {tfm, target}).items():
        packages[k] = (name, ver); kind[k] = 'lock file'
    assets = json.load(open(os.path.join(repo, 'src', prog, 'obj', 'project.assets.json')))
    for key, lib in assets['targets'][target].items():
        if lib.get('type') != 'package': continue
        name, ver = key.split('/')
        files = set(lib.get('runtime', {})) | set(lib.get('native', {})) | set(lib.get('resource', {}))
        shipped[(name.lower(), ver.lower())] |= {f for f in files if not f.endswith('_._')}
    # Runtime and host packs: downloaded by the SDK, not in the lock file.
    for dd in assets['project']['frameworks'][tfm].get('downloadDependencies', []):
        name, ver = dd['name'], dd['version'].strip('[]').split(',')[0].strip()
        if not name.lower().endswith('.' + rid): continue
        k = (name.lower(), ver.lower())
        packages[k] = (name, ver); kind[k] = 'runtime pack'
        base = os.path.join(cache, k[0], k[1])
        if '.host.' in k[0]:
            shipped[k] = {f'runtimes/{rid}/native/apphost'}
        else:
            for sub in ('lib', 'native'):
                for root, _, fs in os.walk(os.path.join(base, 'runtimes', rid, sub)):
                    shipped[k] |= {os.path.relpath(os.path.join(root, f), base) for f in fs}

# Local tools whose output ships: all their files count.
tool_manifest = json.load(open(os.path.join(repo, '.config', 'dotnet-tools.json')))['tools']
for name in tools_in:
    ver = tool_manifest[name]['version']
    k = (name.lower(), ver.lower())
    packages[k] = (name, ver); kind[k] = 'tool'
    base = os.path.join(cache, k[0], k[1])
    for root, _, fs in os.walk(os.path.join(base, 'tools')):
        shipped[k] |= {os.path.relpath(os.path.join(root, f), base) for f in fs if f.endswith('.dll')}

direct = {k for k in packages if k[0] in declared and kind[k] == 'lock file'}

# --- One row per package ---------------------------------------------------

rows, file_rows = [], []
for (lid, lver), (name, ver) in sorted(packages.items()):
    pdir = os.path.join(cache, lid, lver)
    nuspec = open(glob.glob(os.path.join(pdir, '*.nuspec'))[0], encoding='utf-8', errors='replace').read()
    authors = (re.search(r'<authors>(.*?)</authors>', nuspec, re.S) or [None, ''])[1].strip()
    m = re.search(r'<repository\b([^>]*)', nuspec)
    attr = lambda k: (re.search(k + r'="([^"]*)"', m.group(1)) or [None, ''])[1] if m else ''
    url, commit = attr('url'), attr('commit')
    managed, native, pdb_where, compilers = 0, 0, set(), set()
    flags = collections.Counter()
    for f in sorted(shipped.get((lid, lver), ())):
        path = os.path.join(pdir, f)
        data = open(path, 'rb').read()
        pe = pe_info(data)
        if pe is None or not pe['managed']:
            native += 1; continue
        managed += 1
        for k in ('authenticode', 'strongname', 'reproducible', 'pdbchecksum'):
            flags[k] += pe[k]
        file_rows.append({'package': name, 'version': ver, 'file': f,
                          'pdb_name': os.path.basename(pe['codeview'].replace('\\', '/')) if pe['codeview'] else '',
                          'guid': pe['cv_guid'], 'age': pe['cv_age'], 'portable': 'yes' if pe['cv_portable'] else 'no',
                          'checksum': pe['checksum'],
                          'pdb': 'embedded' if pe['embedded'] is not None else
                                 'in package' if os.path.exists(path[:-4] + '.pdb') else
                                 'not in package' if pe['codeview'] else 'none'})
        pdb = None
        if pe['embedded'] is not None:
            pdb_where.add('embedded'); pdb = pe['embedded']
        elif os.path.exists(path[:-4] + '.pdb'):
            pdb_where.add('in package'); pdb = open(path[:-4] + '.pdb', 'rb').read()
        elif pe['codeview']:
            pdb_where.add('not in package')
        else:
            pdb_where.add('none')
        if pdb is not None:
            p = pdb_info(pdb)
            flags['sourcelink'] += p['sourcelink']
            flags['pdb ' + p['format']] += 1
            if p['compiler']: compilers.add(p['compiler'])
    def share(k): return '' if not managed else ('yes' if flags[k] == managed else 'no' if flags[k] == 0 else 'some')
    if managed == 0 and native == 0: cat = 'N0'
    elif managed == 0: cat = 'N1'
    elif not url: cat = 'C1a'
    elif not commit: cat = 'C1b'
    elif compilers: cat = 'R'
    elif pdb_where & {'embedded', 'in package'}: cat = 'C2c'
    elif 'not in package' in pdb_where: cat = 'C2b'
    else: cat = 'C2a'
    rows.append({
        'category': cat, 'package': name, 'version': ver,
        'source': kind[(lid, lver)], 'direct': 'yes' if (lid, lver) in direct else '',
        'owner': 'Microsoft' if 'microsoft' in authors.lower() else 'third-party',
        'repository': url, 'commit': commit, 'managed_files': managed, 'native_files': native,
        'pdb': ', '.join(sorted(pdb_where)), 'compiler': ' | '.join(sorted(compilers)),
        'deterministic': share('reproducible'), 'pdbchecksum': share('pdbchecksum'),
        'sourcelink': '' if not pdb_where & {'embedded', 'in package'} else ('yes' if flags['sourcelink'] else 'no'),
        'authenticode': share('authenticode'), 'strongname': share('strongname'),
    })

# --- Output -----------------------------------------------------------------

os.makedirs(outdir, exist_ok=True)
order = {c[0]: i for i, c in enumerate(CATEGORIES)}
rows.sort(key=lambda r: (order[r['category']], r['owner'], r['package'].lower()))
with open(os.path.join(outdir, 'census.csv'), 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0]))
    w.writeheader(); w.writerows(rows)
with open(os.path.join(outdir, 'census.files.csv'), 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(file_rows[0]))
    w.writeheader(); w.writerows(file_rows)

missing_assets = [packages[k][0] for k in packages if k not in shipped]
count = collections.Counter((r['category'], r['owner']) for r in rows)
builds = {(r['repository'].lower().removesuffix('.git').replace('git://', 'https://'), r['commit'])
          for r in rows if r['commit']}
with open(os.path.join(outdir, 'census.md'), 'w') as f:
    p = lambda *a: print(*a, file=f)
    p('# Dependency census\n')
    p(f'Generated by `experiments/dep-census/census.py`, target `{target}`.')
    nlock = sum(1 for k in kind.values() if k == 'lock file')
    p(f'Programs: {", ".join(programs)}, published self-contained for `{rid}`. '
      f'{len(rows)} packages (id and version): {nlock} from the programs\' lock files '
      f'({len(direct)} direct, {nlock - len(direct)} transitive), '
      f'{sum(1 for k in kind.values() if k == "runtime pack")} runtime packs and '
      f'{sum(1 for k in kind.values() if k == "tool")} tool(s) ({", ".join(tools_in) or "none"}). {len(builds)} distinct repository+commit pairs. '
      'What is left out, and why: [scope.md](scope.md).')
    if missing_assets:
        p(f'In a lock file, but not in the assets file for the target: {", ".join(sorted(missing_assets))}.')
    p('\n## Categories\n')
    p('| Id | Category | Meaning | Microsoft | Third-party | Total |')
    p('| --- | --- | --- | ---: | ---: | ---: |')
    for cid, title, meaning in CATEGORIES:
        ms, tp = count[(cid, 'Microsoft')], count[(cid, 'third-party')]
        p(f'| {cid} | {title} | {meaning} | {ms} | {tp} | {ms + tp} |')
    p(f'| | | | {sum(v for (c, o), v in count.items() if o == "Microsoft")} '
      f'| {sum(v for (c, o), v in count.items() if o == "third-party")} | {len(rows)} |')
    p('\nOwner is "Microsoft" when the .nuspec authors include Microsoft. Columns, for the '
      'managed DLLs the release ships: **pdb** where the PDB is; **det** the Reproducible '
      'debug entry (built with /deterministic); **sum** the PdbChecksum entry; **SL** Source '
      'Link in the PDB; **AC** Authenticode signature; **SN** strong name. '
      '"some" means some of the package\'s DLLs, not all.')
    for cid, title, _ in CATEGORIES:
        sel = [r for r in rows if r['category'] == cid]
        if not sel: continue
        p(f'\n## {cid}: {title} ({len(sel)})\n')
        p('| Package | Version | Direct | Owner | Commit | IL/native | pdb | Compiler | det | sum | SL | AC | SN |')
        p('| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |')
        for r in sel:
            d = {'runtime pack': 'pack', 'tool': 'tool'}.get(r['source'], r['direct'])
            p(f"| {r['package']} | {r['version']} | {d} | {r['owner']} | {r['commit'][:8]} "
              f"| {r['managed_files']}/{r['native_files']} | {r['pdb']} | {r['compiler'].split('+')[0]} "
              f"| {r['deterministic']} | {r['pdbchecksum']} | {r['sourcelink']} | {r['authenticode']} | {r['strongname']} |")

# --- Scope: everything left out, with the reason ------------------------------

ship_versions = collections.defaultdict(set)
for (lid, lver), (name, ver) in packages.items(): ship_versions[lid].add(ver)
seen = collections.defaultdict(set)   # key -> where it occurs
names = {}
excluded = []
other_rid = {}
for prog in programs:
    lock = os.path.join(repo, 'src', prog, 'packages.lock.json')
    for section in json.load(open(lock))['dependencies']:
        if section in (tfm, target) or section in IGNORED_SECTIONS: continue
        for k, (name, ver, _) in lock_graph(lock, {section}).items():
            if k not in packages: other_rid[k] = (name, ver, section)
for k, (name, ver, section) in sorted(other_rid.items()):
    excluded.append(('Other platform', name, ver, f'Only in the `{section}` part of a program\'s lock file. '
                     'The Windows release is later work (decided 5/10).'))
for lock in sorted(glob.glob(os.path.join(repo, 'src', '*', 'packages.lock.json'))) + [os.path.join(repo, 'tests', 'packages.lock.json')]:
    where = os.path.relpath(os.path.dirname(lock), repo)
    if where in (os.path.join('src', p) for p in programs): continue
    for k, (name, ver, _) in lock_graph(lock).items():
        seen[k].add(where); names[k] = (name, ver)
for k in sorted(set(seen) - set(packages) - set(other_rid)):
    name, ver = names[k]
    places = sorted(seen[k])
    other = ship_versions.get(k[0])
    also = f' The programs ship version {", ".join(sorted(other))}.' if other else ''
    if all(pl == 'tests' for pl in places):
        excluded.append(('Test only', name, ver, 'Used only by `tests/`; does not ship.' + also))
    else:
        excluded.append(('Library lock file only', name, ver,
                         f'Only in the lock file of {", ".join("`" + pl + "`" for pl in places)}. '
                         'A library is compiled into the programs; the programs\' own graph decides what ships.' + also))
for prog in programs:
    assets = json.load(open(os.path.join(repo, 'src', prog, 'obj', 'project.assets.json')))
    for dd in assets['project']['frameworks'][tfm].get('downloadDependencies', []):
        name, ver = dd['name'], dd['version'].strip('[]').split(',')[0].strip()
        if name.lower().endswith(('.osx-arm64', '.osx-x64')): continue   # host RID of a Mac restore, see IGNORED_SECTIONS
        if not name.lower().endswith('.' + rid) and ('Other platform', name, ver) not in [e[:3] for e in excluded]:
            excluded.append(('Other platform', name, ver, f'Runtime pack for another platform. The Windows release is later work (decided 5/10).'))
tools = json.load(open(os.path.join(repo, '.config', 'dotnet-tools.json')))['tools']
for name, t in sorted(tools.items()):
    if name in tools_in: continue
    excluded.append(('Local tool', name, t['version'], 'Local tool for code formatting. Never part of a build or the release.'))
with open(os.path.join(outdir, 'scope.md'), 'w') as f:
    p = lambda *a: print(*a, file=f)
    p('# Dependency scope: what is in, what is out\n')
    p(f'Generated by `experiments/dep-census/census.py`. **In:** the {len(rows)} packages the self-contained '
      f'`{rid}` publish of {", ".join(programs)} ships, and the tools whose output ships '
      f'({", ".join(tools_in) or "none"}); one row each in [census.md](census.md).\n')
    p('**Out, not NuGet packages:** the frontend\'s npm packages (layer 3, measured separately), and the '
      '.NET SDK itself (the toolchain that builds everything; recorded by its `csc.dll` hash, not rebuilt).\n')
    groups = collections.Counter(e[0] for e in excluded)
    p('| Reason | Packages |\n| --- | ---: |')
    for g, n in groups.items(): p(f'| {g} | {n} |')
    p(f'| Total left out | {len(excluded)} |')
    for g in groups:
        p(f'\n## {g} ({groups[g]})\n')
        p('| Package | Version | Why |\n| --- | --- | --- |')
        for e in excluded:
            if e[0] == g: p(f'| {e[1]} | {e[2]} | {e[3]} |')
print(f'{len(rows)} packages in, {len(excluded)} out -> {outdir}')
