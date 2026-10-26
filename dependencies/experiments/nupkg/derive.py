"""Derive a release-only rebuild recipe for one NuGet package.

Usage: python -I derive.py PACKAGE VERSION CENSUS_FILES_CSV LAB OUT

The release-only method (decided 26 October 2026): the recipe may use only
what the release publishes (the .nupkg with its .nuspec, the shipped DLL's
attributes, its PDB) and the source at the declared commit with its standard
.NET files. CI files and build scripts are not read. Every value in the
recipe gets one of three marks: "read", with where it was read from;
"inferred", where a rule turns an observation into a choice (the lowest SDK
with the compiler, LF means Linux, mapped paths mean ContinuousIntegration-
Build, version properties from the informational version); or "default",
with the reason. A package the rules cannot handle gets "skipped" with the
rule that failed. Nothing is left out silently.

The rules, in the order they run (dependencies/notes/2026-10-26-nupkg-release-only.md):

 1. Package: the .nupkg from nuget.org; the shipped file from the census
    (census.files.csv); the PDB from the package, else from the .snupkg, else
    from the NuGet symbol server by the DLL's CodeView key.
 2. Source: the .nuspec's commit; the clone URL from the PDB's Source Link,
    else the .nuspec's URL; a branch or tag only if the .nuspec names one.
 3. SDK: the SDK release whose csc.dll has the PDB's compiler version, among
    the SDKs that bundle the PDB's runtime version. Candidates are installed
    into LAB/sdk/<version> and their csc.dll read. No match: skipped.
 4. OS: Windows if the PDB's SDK-generated files have CRLF, else Linux; no
    such file embedded: Linux by default.
 5. Build folder and NuGet cache: the PDB's document paths when absolute.
 6. Line endings of the checkout: the ones whose checksums the PDB has, from
    a shallow clone at the commit; no decision possible: the OS's default.
 7. Project: the .csproj whose assembly name is the DLL's; none or several:
    skipped.
 8. Command, the same for all (version 2, 26 October, after GuardClauses):
    dotnet build PROJECT -c Release, then dotnet pack PROJECT -c Release
    --no-build, with ContinuousIntegrationBuild when the PDB's paths start
    with /_/, the version prefix and suffix from the DLL's informational
    version, and the package version from the .nuspec. Version 1 was one
    dotnet pack, which skips the build for a project with
    GeneratePackageOnBuild and then has nothing to pack.

OUT gets recipe.toml (for rebuild.py), facts.txt (one line per rule, with
its mark) and the report of the published DLL. Written 26 October 2026.
"""
import hashlib, json, os, re, subprocess, sys, tomllib, urllib.error, urllib.request, zipfile
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
REPORT_SDK = os.environ.get('DLLREPORT_DOTNET', '/private/tmp/rb1-dotnet10/sdk/dotnet')
facts, defaults, skipped = [], [], None


inferred = []


def fact(rule, value, mark):
    facts.append(f'{rule}: {value}  [{mark}]')
    if mark.startswith('default'):
        defaults.append(rule)
    if mark.startswith('inferred'):
        inferred.append(rule)


def skip(rule, why):
    global skipped
    skipped = skipped or f'{rule}: {why}'
    facts.append(f'{rule}: SKIPPED, {why}')


def download(url, path):
    try:
        with urllib.request.urlopen(url, timeout=300) as r, open(path, 'wb') as f:
            f.write(r.read())
        return True
    except urllib.error.HTTPError:
        return False


def sha256(b):
    return hashlib.sha256(b).hexdigest()


def main():
    pkg, ver, census, lab, out = sys.argv[1:6]
    os.makedirs(out, exist_ok=True)
    lid, lver = pkg.lower(), ver.lower()

    # 1. package, shipped file, PDB
    nupkg = os.path.join(out, f'{lid}.{lver}.nupkg')
    if not download(f'https://api.nuget.org/v3-flatcontainer/{lid}/{lver}/{lid}.{lver}.nupkg', nupkg):
        sys.exit(f'{pkg} {ver}: not on nuget.org')
    rows = [l.rstrip('\n').split(',') for l in open(census, encoding='utf-8')]
    head = rows[0]
    ships = [dict(zip(head, r)) for r in rows[1:] if r[0] == pkg and r[1] == ver]
    if not ships:
        sys.exit(f'{pkg} {ver}: not in {census}')
    ship = ships[0]['file']
    fact('shipped file', ship, 'read: census.files.csv')
    z = zipfile.ZipFile(nupkg)
    nuspec = ET.fromstring(z.read(next(n for n in z.namelist() if n.endswith('.nuspec'))))
    ns = {'n': nuspec.tag.split('}')[0].strip('{')}
    repo_el = nuspec.find('.//n:repository', ns)
    dll_name = os.path.basename(ship)
    dll = os.path.join(out, dll_name)
    open(dll, 'wb').write(z.read(ship))
    pdb_in = ship[:-4] + '.pdb'
    pdb = os.path.join(out, os.path.basename(pdb_in))
    if pdb_in in z.namelist():
        open(pdb, 'wb').write(z.read(pdb_in))
        fact('pdb', 'in the package', 'read: .nupkg')
    else:
        snupkg = os.path.join(out, f'{lid}.{lver}.snupkg')
        if download(f'https://www.nuget.org/api/v2/symbolpackage/{pkg}/{ver}', snupkg):
            zs = zipfile.ZipFile(snupkg)
            if pdb_in in zs.namelist():
                open(pdb, 'wb').write(zs.read(pdb_in))
                fact('pdb', 'in the .snupkg', 'read: nuget.org symbol package')
    report = os.path.join(out, 'report-nugetorg.txt')
    args = [REPORT_SDK, 'run', os.path.join(HERE, 'dllreport.cs'), '--', dll] + ([pdb] if os.path.exists(pdb) else [])
    text = subprocess.run(args, capture_output=True, text=True).stdout
    if 'EmbeddedPortablePdb' in text and not os.path.exists(pdb):
        fact('pdb', 'embedded in the DLL', 'read: .nupkg')
    if '## Compiler record' not in text:
        cv = re.search(r'CodeView: .*guid ([0-9a-f-]+), age (\d+)', text)
        if cv and not os.path.exists(pdb):
            key = cv.group(1).replace('-', '').upper() + 'FFFFFFFF'
            name = os.path.basename(pdb)
            if download(f'https://symbols.nuget.org/download/symbols/{name.lower()}/{key}/{name.lower()}', pdb) or \
               download(f'https://msdl.microsoft.com/download/symbols/{name}/{key}/{name}', pdb):
                fact('pdb', 'from the symbol server', 'read: symbol server by CodeView key')
                text = subprocess.run(args + [pdb], capture_output=True, text=True).stdout
    open(report, 'w', encoding='utf-8').write(text)
    if '## Compiler record' not in text:
        skip('pdb', 'no PDB with a compiler record')
        return finish(out, pkg, ver, None)

    # what the report says
    compiler = re.search(r'^compiler-version: (\S+)', text, re.M).group(1)
    runtime = re.search(r'^runtime-version: (\S+)', text, re.M).group(1)
    docs = re.findall(r'^document: (.+?) (sha256|sha1) ([0-9a-f]+)( embedded \(crlf (\d+), lf (\d+)\))?$', text, re.M)
    info = re.search(r'AssemblyInformationalVersionAttribute\((.+?)\)$', text, re.M)
    asm = re.search(r'^name: (\S+?), version', text, re.M).group(1)
    sl = re.search(r'^\{"documents":(.+)\}$', text, re.M)

    # 2. source
    commit = repo_el.get('commit') if repo_el is not None else None
    if not commit:
        skip('source', 'the .nuspec names no commit')
        return finish(out, pkg, ver, None)
    fact('commit', commit, 'read: .nuspec repository/@commit')
    url = None
    if sl:
        m = re.search(r'https://raw\.githubusercontent\.com/([^/]+)/([^/]+)/', sl.group(1))
        if m:
            url = f'https://github.com/{m.group(1)}/{m.group(2)}'
            fact('clone url', url, 'read: PDB Source Link')
    if not url:
        url = re.sub(r'\.git$', '', repo_el.get('url', ''))
        fact('clone url', url, 'default: no Source Link in the PDB, the .nuspec URL')
    branch = tag = None
    ref = repo_el.get('branch', '')
    if ref.startswith('refs/heads/'):
        branch = ref[len('refs/heads/'):]
        fact('branch', branch, 'read: .nuspec repository/@branch')
    elif ref.startswith('refs/tags/'):
        tag = ref[len('refs/tags/'):]
        fact('tag', tag, 'read: .nuspec repository/@branch')
    else:
        fact('branch or tag', 'none, the commit detached', 'read: .nuspec has no branch')

    # 3. SDK
    rt = runtime.split('+')[0].split('-')[0]
    channel = '.'.join(rt.split('.')[:2])
    if rt.startswith('4.'):
        # the compiler ran on .NET Framework: Visual Studio's MSBuild, not a dotnet SDK
        meta = {'releases': []}
        skip('sdk', f'the compiler ran on .NET Framework {rt} (Visual Studio or msbuild.exe); no dotnet SDK bundles it')
    else:
        try:
            meta = json.load(urllib.request.urlopen(f'https://builds.dotnet.microsoft.com/dotnet/release-metadata/{channel}/releases.json', timeout=60))
        except urllib.error.HTTPError as e:
            meta = {'releases': []}
            skip('sdk', f'no release metadata for runtime channel {channel} (HTTP {e.code})')
    cands = sorted({s['version'] for r in meta['releases'] for s in r.get('sdks', []) if s.get('runtime-version') == rt and '-' not in s['version']},
                   key=lambda v: [int(x) for x in v.split('.')])
    sdk = None
    for c in cands:
        d = os.path.join(lab, 'sdk', c)
        if not os.path.isdir(d):
            subprocess.run([sys.executable, '-I', os.path.join(HERE, 'install-sdk.py'), c, d], check=True, stdout=subprocess.DEVNULL)
        csc = os.path.join(d, 'sdk', c, 'Roslyn', 'bincore', 'csc.dll')
        data = open(csc, 'rb').read()
        v = re.search(rb'\x01\x00.(\d+\.\d+\.\d+-[0-9.]+\+[0-9a-f]{40})', data, re.S)
        if v and v.group(1).decode() == compiler:
            sdk = c
            break
    if sdk:
        same = [c for c in cands if c >= sdk]   # later candidates were not read; the rule stops at the first match
        fact('sdk', f'{sdk} (csc {compiler}, runtime {rt}; candidates {", ".join(cands)}; the lowest match is taken, not read: {", ".join(same[1:]) or "none"})',
             'read: PDB compiler record, verified in csc.dll' if len(cands) == 1 else 'inferred: the lowest SDK whose csc.dll has the compiler')
    else:
        skip('sdk', f'no public SDK with runtime {rt} has csc {compiler} (tried {", ".join(cands) or "none"})')
        return finish(out, pkg, ver, None)

    # 4. OS, from the SDK-generated files embedded in the PDB
    gen = [(p, int(c or 0), int(l or 0)) for p, _, _, e, c, l in docs if e and re.search(r'AssemblyInfo\.cs$|AssemblyAttributes\.cs$|GlobalUsings\.g\.cs$', p)]
    if gen:
        crlf = sum(c for _, c, _ in gen); lf = sum(l for _, _, l in gen)
        win = crlf > lf
        fact('os', f'{"windows" if win else "linux"} (generated files: crlf {crlf}, lf {lf})', 'inferred: CRLF in the SDK-generated files means Windows, LF means Linux (macOS would look the same)')
    else:
        win = False
        fact('os', 'linux', 'default: no SDK-generated file embedded in the PDB')

    # a shallow clone at the commit, for rules 5 to 7 (no conversion of line endings)
    src = os.path.join(lab, 'src', f'{lid}-{lver}')
    if not os.path.isdir(src):
        subprocess.run(['git', 'init', '-q', src], check=True)
        subprocess.run(['git', '-C', src, 'config', 'core.autocrlf', 'false'], check=True)
        subprocess.run(['git', '-C', src, 'remote', 'add', 'origin', url], check=True)
        subprocess.run(['git', '-C', src, 'fetch', '-q', '--depth=1', 'origin', commit], check=True)
        subprocess.run(['git', '-C', src, '-c', 'advice.detachedHead=false', 'checkout', '-q', commit], check=True)
    tracked = subprocess.run(['git', '-C', src, 'ls-files', '-z'], capture_output=True, check=True).stdout.decode().split('\0')
    tracked = [t for t in tracked if t]

    # 5. build folder and NuGet cache
    paths = [p for p, *_ in docs]
    mapped = all(p.startswith('/_/') for p in paths)
    clone_dir = nuget_packages = None
    if not mapped:
        # the clone's root: a document path minus the tracked file it ends with
        roots = {}
        suffixes = {t.replace('/', '\\'): t for t in tracked}
        for p in paths:
            if re.match(r'^[A-Za-z]:\\', p):
                sep, sufs = '\\', suffixes
            elif p.startswith('/') and not p.startswith('/_/'):
                sep, sufs = '/', {t: t for t in tracked}   # an absolute Unix path (a Linux or macOS build)
            else:
                continue
            for suf in sufs:
                if p.endswith(sep + suf):
                    roots[p[:-len(suf) - 1]] = roots.get(p[:-len(suf) - 1], 0) + 1
        if roots:
            clone_dir = max(roots, key=roots.get)
            fact('build folder', f'{clone_dir} ({roots[clone_dir]} source paths end in a tracked file there)', 'read: PDB document paths')
        else:
            fact('build folder', 'not found: no absolute path ends in a tracked file', 'default: any folder')
        caches = [p for p in paths if '.nuget\\packages\\' in p.lower()]
        if caches:
            nuget_packages = caches[0][:caches[0].lower().index('\\.nuget\\packages\\')] + '\\.nuget\\packages'
            fact('nuget cache', nuget_packages, 'read: PDB document path of a package source file')
    else:
        fact('build folder', 'mapped (/_/), any folder', 'read: PDB document paths')

    # 6. line endings of the checkout: as stored, or converted to CRLF or LF
    by_asis, by_lf, by_crlf = {}, {}, {}
    for t in tracked:
        if not t.endswith(('.cs', '.xml', '.resx', '.txt', '.json', '.targets', '.props')):
            continue
        b = open(os.path.join(src, t), 'rb').read()
        lfb = b.replace(b'\r\n', b'\n'); crlfb = lfb.replace(b'\n', b'\r\n')
        by_asis[sha256(b)] = t; by_lf[sha256(lfb)] = t; by_crlf[sha256(crlfb)] = t
    n_asis = n_lf = n_crlf = n_doc = 0
    for p, alg, h, e, *_ in docs:
        if alg != 'sha256' or e:
            continue
        n_doc += 1; n_asis += h in by_asis; n_lf += h in by_lf; n_crlf += h in by_crlf
    best = max(n_asis, n_lf, n_crlf)
    counts = f'of {n_doc} source checksums: as stored {n_asis}, as CRLF {n_crlf}, as LF {n_lf}; unmatched by the chosen form {n_doc - best}'
    if n_asis and n_asis >= max(n_lf, n_crlf):
        eol = 'asis'; fact('checkout line endings', f'as stored in git, no conversion ({counts})', 'read: PDB source checksums against the clone')
    elif n_crlf > n_lf:
        eol = 'crlf'; fact('checkout line endings', f'converted to CRLF, core.autocrlf=true ({counts})', 'read: PDB source checksums against the clone')
    elif n_lf > n_crlf:
        # git converts to CRLF at checkout (autocrlf=true) but never to LF: "input" converts at commit only
        eol = 'asis'; fact('checkout line endings', f'the PDB has LF where git stores CRLF; git cannot convert at checkout, so as stored ({counts})', 'default: no checkout conversion to LF')
    else:
        eol = 'asis'; fact('checkout line endings', f'as stored in git ({counts}, nothing decides)', 'default: no checksum decides')
    if n_doc - best:
        fact('checkout line endings, unmatched', f'{n_doc - best} source checksums match no form of a tracked file', 'read: a difference the build will show')

    # 7. project
    projects = []
    for t in tracked:
        if t.endswith('.csproj'):
            try:
                x = ET.parse(os.path.join(src, t)).getroot()
            except ET.ParseError:
                continue
            an = [e.text.strip() for e in x.iter('AssemblyName') if e.text]
            name = an[-1] if an else os.path.basename(t)[:-7]
            if name == asm:
                projects.append(t)
    if len(projects) != 1:
        skip('project', f'{len(projects)} .csproj with assembly name {asm}: {projects}')
        return finish(out, pkg, ver, None)
    fact('project', projects[0], 'read: .csproj assembly name = the DLL name')

    # 8. command
    props = []
    if mapped:
        props.append('-p:ContinuousIntegrationBuild=true')
        fact('ContinuousIntegrationBuild', 'true', 'inferred: the PDB paths are mapped to /_/, which that property does (DeterministicSourcePaths alone would too)')
    if info:
        iv = info.group(1).split('+')[0]
        prefix, _, suffix = iv.partition('-')
        props.append(f'-p:VersionPrefix={prefix}')
        if suffix:
            props.append(f'-p:VersionSuffix={suffix}')
        fact('version', f'prefix {prefix}, suffix {suffix or "none"}', 'inferred: VersionPrefix/VersionSuffix from the DLL AssemblyInformationalVersion; a project that sets Version itself, or MinVer, keeps its own')
    else:
        fact('version', 'none passed', 'default: the DLL has no informational version')
    props.append(f'-p:PackageVersion={ver}')
    proj = projects[0].replace('\\', '/')
    build = f'dotnet build {proj} -c Release {" ".join(props)} && dotnet pack {proj} -c Release --no-build -o out-nupkg {" ".join(props)}'
    fact('command', build, 'rule 8, version 2')

    recipe = {'package': pkg, 'version': ver, 'ships': ship, 'repo': url, 'commit': commit, 'project': proj,
              'sdk': sdk, 'shell': 'bash', 'build': build, 'packages': 'out-nupkg', 'os': 'windows' if win else 'linux'}
    if branch: recipe['branch'] = branch
    if tag: recipe['tag'] = tag
    if not tag: recipe['depth'] = 1
    if clone_dir: recipe['clone_dir'] = clone_dir
    if nuget_packages: recipe['nuget_packages'] = nuget_packages
    # explicit on every OS: GitHub's Windows runners set core.autocrlf=true system-wide, and a
    # repository with "* text=auto" checks out with core.eol, which is CRLF on Windows by default
    # (Cronos, run 1 on 26/10); "as stored" therefore also pins core.eol=lf
    recipe['git_config'] = {'asis': ['core.autocrlf=false', 'core.eol=lf'], 'crlf': ['core.autocrlf=true']}[eol]
    finish(out, pkg, ver, recipe)


def finish(out, pkg, ver, recipe):
    with open(os.path.join(out, 'facts.txt'), 'w', encoding='utf-8') as f:
        f.write(f'{pkg} {ver}, release-only derivation\n')
        f.write('\n'.join(facts) + '\n')
        if skipped:
            cat = f'skipped ({skipped})'
        elif defaults:
            cat = f'derived with defaults ({", ".join(defaults)}); inferred: {", ".join(inferred) or "none"}'
        else:
            cat = f'derived, every value read from the release or the source; inferred: {", ".join(inferred) or "none"}'
        f.write(f'category: {cat}\n')
    if recipe:
        with open(os.path.join(out, 'recipe.toml'), 'w', encoding='utf-8') as f:
            f.write(f'# Derived by derive.py (release-only method), see facts.txt beside it.\n')
            for k, v in recipe.items():
                if isinstance(v, list):
                    f.write(f'{k} = [{", ".join(json.dumps(x) for x in v)}]\n')
                elif isinstance(v, int):
                    f.write(f'{k} = {v}\n')
                else:
                    f.write(f'{k} = {json.dumps(v)}\n')
        tomllib.load(open(os.path.join(out, 'recipe.toml'), 'rb'))
    print(open(os.path.join(out, 'facts.txt'), encoding='utf-8').read())


if __name__ == '__main__':
    main()
