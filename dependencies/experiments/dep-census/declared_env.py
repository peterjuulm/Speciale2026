"""What each package's repository declares about the build environment.

For every repository+commit in the census, reads the repository's tree at that
commit through GitHub's API (`gh api`, read only) and looks for:

- global.json: sdk.version, rollForward, allowPrerelease, Arcade's tools.dotnet;
- CI configuration: GitHub Actions, Azure Pipelines, AppVeyor, Travis, GitLab,
  and build scripts (Cake, Nuke, FAKE, build.ps1/sh). From the CI files it
  takes the OS images (runs-on, vmImage, image) and the SDK versions
  (setup-dotnet, UseDotNet).

CI logs are not read: a log is not a declaration (decided 13 October 2026).

Usage: python3 -I declared_env.py CENSUS_CSV CACHE_DIR OUTDIR
Writes OUTDIR/declared-env.csv (one row per package) and
OUTDIR/declared-env.md. CACHE_DIR keeps the API responses, so a rerun is
offline.

Written 13 October 2026.
"""
import collections, concurrent.futures, csv, hashlib, json, os, re, subprocess, sys

census_csv, cache_dir, outdir = sys.argv[1:4]
os.makedirs(cache_dir, exist_ok=True)
# go.microsoft.com/fwlink/?linkid=868515 redirects here (checked 13/10 with curl -I).
REDIRECTS = {'https://go.microsoft.com/fwlink/?linkid=868515': 'https://github.com/mono/SkiaSharp'}
MAX_CI_FILES = 40

def gh(path, raw=False):
    """GET from the GitHub API through gh, cached. Returns (ok, text)."""
    key = hashlib.sha256((path + str(raw)).encode()).hexdigest()
    f = os.path.join(cache_dir, key)
    if os.path.exists(f):
        ok, text = json.load(open(f))
        return ok, text
    cmd = ['gh', 'api', path] + (['-H', 'Accept: application/vnd.github.raw'] if raw else [])
    r = subprocess.run(cmd, capture_output=True, text=True)
    ok, text = r.returncode == 0, r.stdout if r.returncode == 0 else r.stderr
    json.dump([ok, text], open(f, 'w'))
    return ok, text

def norm(url):
    url = REDIRECTS.get(url, url)
    url = url.replace('git://', 'https://').removesuffix('/').removesuffix('.git')
    m = re.match(r'https?://github\.com/([^/]+)/([^/?#]+)', url, re.I)
    return (m.group(1), m.group(2)) if m else None

def list_paths(owner, name, sha):
    ok, text = gh(f'repos/{owner}/{name}/git/trees/{sha}?recursive=1')
    if not ok: return None, False
    t = json.loads(text)
    paths = [e['path'] for e in t['tree'] if e['type'] == 'blob']
    if t.get('truncated'):
        # Too large for one listing: read the folders that hold CI files directly.
        for d in ('', '.github/workflows', 'eng/pipelines', '.azure-pipelines', 'build'):
            ok, text = gh(f'repos/{owner}/{name}/contents/{d}?ref={sha}')
            if ok and text.startswith('['):
                paths += [e['path'] for e in json.loads(text) if e['type'] == 'file']
    return sorted(set(paths)), bool(t.get('truncated'))

def is_ci(p):
    low = p.lower()
    return (low.startswith('.github/workflows/') and low.endswith(('.yml', '.yaml'))
            or re.fullmatch(r'(\.?azure-pipelines[^/]*|\.azure-pipelines/.*|eng/pipelines/[^/]*)\.ya?ml', low)
            or low in ('appveyor.yml', '.appveyor.yml', '.travis.yml', '.gitlab-ci.yml'))

def ci_system(p):
    low = p.lower()
    if low.startswith('.github/workflows/'): return 'GitHub Actions'
    if 'azure-pipelines' in low or low.startswith('eng/pipelines/'): return 'Azure Pipelines'
    if 'appveyor' in low: return 'AppVeyor'
    if 'travis' in low: return 'Travis'
    if 'gitlab' in low: return 'GitLab'

def build_scripts(paths):
    found = set()
    for p in paths:
        low = p.lower()
        if low.endswith('build.cake'): found.add('Cake')
        elif low.endswith('_build.csproj') or low.endswith('.nuke'): found.add('Nuke')
        elif low.endswith('build.fsx'): found.add('FAKE')
        elif '/' not in low and low in ('build.ps1', 'build.sh', 'build.cmd'): found.add(low)
        elif '/' not in low and low == 'dockerfile': found.add('Dockerfile')
    return found

IMAGE_RE = re.compile(r'^\s*(?:runs-on|vmImage|image|os)\s*:\s*(.+?)\s*$', re.M)
LIST_RE = re.compile(r'^\s*(?:os|image)\s*:\s*\[(.+?)\]', re.M)
SDK_RE = re.compile(r'^\s*(?:dotnet-version|version)\s*:\s*[|>]?\s*(.*?)\s*$', re.M)
def ci_details(text, system):
    text = re.sub(r'\s+#.*$', '', text, flags=re.M)   # YAML comments
    images, sdks = set(), set()
    for m in LIST_RE.finditer(text):
        images |= {v.strip(' \'"') for v in m.group(1).split(',')}
    for m in IMAGE_RE.finditer(text):
        v = m.group(1).strip(' \'"').removeprefix('- ').strip(' \'"')
        if v and not v.startswith(('[', 'name:')): images.add(v)
    if system in ('GitHub Actions', 'Azure Pipelines'):
        for block in re.split(r'\n(?=\s*- )', text):
            if 'setup-dotnet' in block or 'UseDotNet' in block:
                if 'global-json-file' in block or 'useGlobalJson' in block: sdks.add('from global.json')
                for m in SDK_RE.finditer(block):
                    v = m.group(1).strip(' \'"')
                    if v: sdks.add(v)
                # dotnet-version: | followed by a list of lines
                m = re.search(r'dotnet-version\s*:\s*\|\s*\n((?:\s+[\w.*-]+\s*\n?)+)', block)
                if m: sdks |= {v.strip() for v in m.group(1).split() if v.strip()}
    # Keep values that look like OS images, not every "image:" in a file.
    images = {i for i in images if re.search(r'ubuntu|windows|macos|vs20|visual studio|linux|1es|\$\{\{|\$\(', i, re.I)}
    return images, sdks

def image_class(images):
    if not images: return 'none found'
    kinds = set()
    for i in images:
        low = i.lower()
        if '${{' in low or '$(' in low: kinds.add('expression')
        elif 'latest' in low: kinds.add('floating')
        elif re.search(r'\d', low): kinds.add('fixed label')
        else: kinds.add('other')
    if kinds == {'fixed label'}: return 'fixed label'
    if 'floating' in kinds: return 'floating' if kinds <= {'floating', 'expression'} else 'mixed'
    return 'expression or other'

def sdk_class(gj, ci_sdks):
    if gj.get('tools_dotnet'): return 'exact (Arcade tools.dotnet)'
    v, rf = gj.get('sdk_version'), (gj.get('roll_forward') or '').lower()
    if v:
        if rf == 'disable': return 'exact (rollForward disable)'
        if rf in ('', 'patch', 'latestpatch'): return 'version, later patch allowed'
        return f'lower bound (rollForward {gj["roll_forward"]})'
    exact = {s for s in ci_sdks if re.fullmatch(r'\d+\.\d+\.\d+', s)}
    if exact: return 'exact in CI only'
    if ci_sdks - {'from global.json'}: return 'wildcard in CI only'
    return 'none'

def inspect(pair):
    url, sha = pair
    repo = norm(url)
    row = {'repository': url, 'commit': sha, 'github': '/'.join(repo) if repo else ''}
    if not repo:
        return {**row, 'found': 'no repository URL' if not url else 'not on GitHub'}
    owner, name = repo
    paths, truncated = list_paths(owner, name, sha)
    if paths is None:
        return {**row, 'found': 'commit not found'}
    row['found'] = 'yes' + (' (tree truncated)' if truncated else '')
    gj = {}
    gjs = sorted((p for p in paths if p.lower().endswith('global.json')), key=lambda p: (p.count('/'), p))
    if gjs:
        ok, text = gh(f'repos/{owner}/{name}/contents/{gjs[0]}?ref={sha}', raw=True)
        try: d = json.loads(re.sub(r'^\s*//.*$', '', text, flags=re.M)) if ok else {}
        except json.JSONDecodeError: d = {}
        sdk = d.get('sdk', {})
        gj = {'path': gjs[0], 'sdk_version': sdk.get('version', ''), 'roll_forward': sdk.get('rollForward', ''),
              'prerelease': str(sdk.get('allowPrerelease', '')), 'tools_dotnet': d.get('tools', {}).get('dotnet', ''),
              'arcade': d.get('msbuild-sdks', {}).get('Microsoft.DotNet.Arcade.Sdk', '')}
    ci_files = [p for p in paths if is_ci(p)]
    systems, images, sdks = set(), set(), set()
    for p in ci_files[:MAX_CI_FILES]:
        system = ci_system(p); systems.add(system)
        ok, text = gh(f'repos/{owner}/{name}/contents/{p}?ref={sha}', raw=True)
        if ok:
            i, s = ci_details(text, system); images |= i; sdks |= s
    scripts = build_scripts(paths)
    sc = sdk_class(gj, sdks)
    ic = image_class(images)
    if not gj and not ci_files and not scripts: level = 'E1'
    elif sc == 'none' or sc.startswith('wildcard'): level = 'E2'
    elif sc.startswith('lower bound'): level = 'E3'
    elif ic != 'fixed label': level = 'E4'
    else: level = 'E5'
    return {**row, 'level': level, 'global_json': gj.get('path', ''), 'sdk_version': gj.get('sdk_version', ''),
            'roll_forward': gj.get('roll_forward', ''), 'tools_dotnet': gj.get('tools_dotnet', ''),
            'arcade': gj.get('arcade', ''), 'sdk_class': sc,
            'ci_systems': ', '.join(sorted(systems)), 'ci_files': len(ci_files),
            'os_images': ', '.join(sorted(images)), 'image_class': ic,
            'ci_sdks': ', '.join(sorted(sdks)), 'build_scripts': ', '.join(sorted(scripts))}

LEVELS = [
    ('E0', 'Not found', 'No repository URL, or the commit is not in the repository'),
    ('E1', 'Nothing declared', 'No global.json, no CI configuration, no build script'),
    ('E2', 'No SDK version', 'CI or scripts exist, but no SDK version (or only a wildcard)'),
    ('E3', 'SDK lower bound only', 'global.json names an SDK but lets it roll forward to a later feature band, minor or major'),
    ('E4', 'SDK version, OS not fixed', 'An exact SDK (or exact up to the patch); the OS image is floating, mixed or not found'),
    ('E5', 'SDK version and fixed OS label', 'An exact SDK (or up to the patch) and only fixed OS labels such as ubuntu-22.04'),
    ('-', 'No commit declared', 'Level 1 already failed (census C1a, C1b): nothing to look up'),
]

packages = list(csv.DictReader(open(census_csv)))
for p in packages:   # one spelling per repository, so git:// and https:// count once
    repo = norm(p['repository'])
    if repo: p['repository'] = 'https://github.com/' + '/'.join(repo).lower()
pairs = sorted({(p['repository'], p['commit']) for p in packages if p['commit']})
with concurrent.futures.ThreadPoolExecutor(8) as ex:
    results = dict(zip(pairs, ex.map(inspect, pairs)))
for r in results.values():
    if r['found'] != 'yes' and not r['found'].startswith('yes'): r['level'] = 'E0'

fields = ['level', 'global_json', 'sdk_version', 'roll_forward', 'tools_dotnet', 'arcade', 'sdk_class',
          'ci_systems', 'ci_files', 'os_images', 'image_class', 'ci_sdks', 'build_scripts', 'github', 'found']
rows = []
for p in packages:
    r = results.get((p['repository'], p['commit']), {'level': '-'})
    rows.append({'package': p['package'], 'version': p['version'], 'census': p['category'],
                 'owner': p['owner'], 'commit': p['commit'], **{k: r.get(k, '') for k in fields}})
order = {l[0]: i for i, l in enumerate(LEVELS)}
rows.sort(key=lambda r: (order[r['level']], r['owner'], r['package'].lower(), r['version']))
os.makedirs(outdir, exist_ok=True)
with open(os.path.join(outdir, 'declared-env.csv'), 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)

pair_levels = collections.Counter((results[k]['level'], 'Microsoft' if any(
    p['owner'] == 'Microsoft' for p in packages if (p['repository'], p['commit']) == k) else 'third-party') for k in results)
pkg_levels = collections.Counter((r['level'], r['owner']) for r in rows)
with open(os.path.join(outdir, 'declared-env.md'), 'w') as f:
    p = lambda *a: print(*a, file=f)
    p('# Declared build environment, level 2 (the repository at the declared commit)\n')
    p(f'Generated by `dependencies/experiments/dep-census/declared_env.py` from the census. {len(pairs)} repository+commit '
      f'pairs, {len(rows)} packages. CI logs not read.\n')
    p('| Level | Meaning | Pairs, Microsoft | Pairs, third-party | Packages, Microsoft | Packages, third-party |')
    p('| --- | --- | ---: | ---: | ---: | ---: |')
    for lid, title, meaning in LEVELS:
        p(f'| {lid} {title} | {meaning} | {pair_levels[(lid, "Microsoft")]} | {pair_levels[(lid, "third-party")]} '
          f'| {pkg_levels[(lid, "Microsoft")]} | {pkg_levels[(lid, "third-party")]} |')
    sc = collections.Counter(r['sdk_class'] for r in results.values() if r['level'] != 'E0')
    ic = collections.Counter(r['image_class'] for r in results.values() if r['level'] != 'E0')
    cs = collections.Counter(s for r in results.values() for s in r.get('ci_systems', '').split(', ') if s)
    p('\n**SDK, per pair:** ' + '; '.join(f'{k} {v}' for k, v in sc.most_common()))
    p('\n**OS image, per pair:** ' + '; '.join(f'{k} {v}' for k, v in ic.most_common()))
    p('\n**CI systems, per pair:** ' + '; '.join(f'{k} {v}' for k, v in cs.most_common()))
    p('\n## One row per repository+commit\n')
    p('| Level | Repository | Commit | Packages | global.json SDK | rollForward | tools.dotnet | SDK class | CI | OS images | CI SDKs | Scripts |')
    p('| --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- |')
    npk = collections.Counter((p_['repository'], p_['commit']) for p_ in packages if p_['commit'])
    for k, r in sorted(results.items(), key=lambda kv: (order[kv[1]['level']], kv[1]['github'].lower())):
        p(f"| {r['level']} | {r['github'] or r['repository']} | {k[1][:8]} | {npk[k]} | {r.get('sdk_version', '')} "
          f"| {r.get('roll_forward', '')} | {r.get('tools_dotnet', '')} | {r.get('sdk_class', '')} "
          f"| {r.get('ci_systems', '')} | {r.get('os_images', '')[:80]} | {r.get('ci_sdks', '')[:60]} | {r.get('build_scripts', '')} |")
print(f'{len(pairs)} pairs, {len(rows)} packages -> {outdir}')
