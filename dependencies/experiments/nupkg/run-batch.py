"""Round A for a batch of packages, start to finish, with a log and a table.

Usage: python3 -I run-batch.py BATCH LIST LAB [--no-push] [--rederive]

BATCH is a name (the data folder dependencies/data/<BATCH>/ and the recipe
folder recipes/release-only/<BATCH>/ get it). LIST has one "Package Version"
per line. LAB is a folder outside the repositories. The steps:

 1. derive every package (derive-batch.py) into LAB/derive;
 2. copy each derived recipe to the repository, commit and push them, so the
    Windows runs start from a commit that holds them;
 3. build the Linux ones here, one after the other (rebuild.py), and
    dispatch one workflow run per Windows one (gh);
 4. wait for the runs, download their output;
 5. for every build: the match level (level.py on dllreport.cs reports of
    nuget.org's DLL and ours) and A against A2;
 6. copy every text output into the data folder and write results.tsv:
    package, version, category, os, sdk, build, level, a_eq_a2, note.

A second run in the same LAB reuses the derivations unless --rederive.
Everything it does and every failure goes to LAB/run.log and the console.
A failure in one package never stops the batch. Run it under nohup or in
the background; it takes an hour or more for fifty packages.

Written 26 October 2026 for round A on the packages not tried before.
"""
import datetime, json, os, re, shutil, subprocess, sys, time, tomllib, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
CENSUS = os.path.join(REPO, 'dependencies', 'data', '2026-10-13-dependency-census', 'mac', 'census.files.csv')
GH_REPO = 'peterjuulm/Speciale2026'
REPORT_DOTNET = os.environ.get('DLLREPORT_DOTNET', '/private/tmp/rb1-dotnet10/sdk/dotnet')


def now():
    return datetime.datetime.now().astimezone().isoformat(timespec='seconds')


class Log:
    def __init__(self, path):
        self.f = open(path, 'a', encoding='utf-8')

    def __call__(self, msg):
        line = f'{now()} {msg}'
        print(line, flush=True)
        self.f.write(line + '\n'); self.f.flush()


def sh(args, log, cwd=None, timeout=None):
    log('$ ' + ' '.join(args))
    r = subprocess.run(args, capture_output=True, text=True, cwd=cwd, timeout=timeout)
    if r.returncode:
        log(f'  exit {r.returncode}: {(r.stderr or r.stdout).strip()[-600:]}')
    return r


def copy_text(src, dst):
    n = 0
    for root, dirs, files in os.walk(src):
        dirs[:] = [d for d in dirs if d != 'nuget-org']
        for f in files:
            if f.endswith(('.txt', '.log', '.toml', '.json')):
                rel = os.path.relpath(os.path.join(root, f), src)
                os.makedirs(os.path.dirname(os.path.join(dst, rel)), exist_ok=True)
                shutil.copy(os.path.join(root, f), os.path.join(dst, rel)); n += 1
    return n


def report(dll, out, log):
    r = subprocess.run([REPORT_DOTNET, 'run', os.path.join(HERE, 'dllreport.cs'), '--', dll], capture_output=True, text=True)
    open(out, 'w', encoding='utf-8').write(r.stdout + r.stderr)
    if r.returncode:
        log(f'  dllreport failed on {dll}: exit {r.returncode}')
    return r.returncode == 0


def level_of(outdir, recipe, log):
    """The level of A's shipped DLL against nuget.org's, from their reports; '' when a package is missing."""
    ships = recipe['ships']
    lid, lver = recipe['package'].lower(), recipe['version'].lower()
    ref = os.path.join(outdir, 'nuget-org', f'{lid}.{lver}.nupkg')
    a = next((os.path.join(outdir, 'A', f) for f in os.listdir(os.path.join(outdir, 'A')) if f.lower() == f'{lid}.{lver}.nupkg'), None) if os.path.isdir(os.path.join(outdir, 'A')) else None
    if not (a and os.path.exists(ref)):
        return '', 'no package to compare'
    lv = os.path.join(outdir, 'level'); os.makedirs(lv, exist_ok=True)
    for src, name in ((ref, 'nugetorg'), (a, 'A')):
        try:
            data = zipfile.ZipFile(src).read(ships)
        except KeyError:
            return '', f'{ships} not in {os.path.basename(src)}'
        open(os.path.join(lv, f'{name}.dll'), 'wb').write(data)
        if not report(os.path.join(lv, f'{name}.dll'), os.path.join(lv, f'report-{name}.txt'), log):
            return '', 'report failed'
    r = subprocess.run([sys.executable, '-I', os.path.join(HERE, 'level.py'), os.path.join(lv, 'report-nugetorg.txt'), os.path.join(lv, 'report-A.txt')],
                       capture_output=True, text=True)
    m = re.match(r'level (\d)', r.stdout)
    return (m.group(1) if m else ''), r.stdout.strip()


def main():
    batch, lst, lab = sys.argv[1], os.path.abspath(sys.argv[2]), os.path.abspath(sys.argv[3])
    push = '--no-push' not in sys.argv
    os.makedirs(lab, exist_ok=True)
    log = Log(os.path.join(lab, 'run.log'))
    data = os.path.join(REPO, 'dependencies', 'data', batch)
    recipes = os.path.join(HERE, 'recipes', 'release-only', batch)
    os.makedirs(data, exist_ok=True); os.makedirs(recipes, exist_ok=True)
    log(f'batch {batch}: list {lst}, lab {lab}, repo at {sh(["git", "-C", REPO, "rev-parse", "--short", "HEAD"], log).stdout.strip()}')

    # 1. derive
    derive = os.path.join(lab, 'derive')
    if os.path.exists(os.path.join(derive, 'batch.txt')) and '--rederive' not in sys.argv:
        log('derive: reusing the derivations in ' + derive)
    else:
        sh([sys.executable, '-I', os.path.join(HERE, 'derive-batch.py'), lst, CENSUS, lab, derive], log, timeout=14400)
    rows = [l.rstrip('\n').split('\t') for l in open(os.path.join(derive, 'batch.txt'), encoding='utf-8')][1:]
    results = {}
    for pv, cat, os_, sdk, rec in rows:
        pkg, ver = pv.split()
        results[pkg] = dict(package=pkg, version=ver, category=cat, os=os_, sdk=sdk, build='', level='', a_eq_a2='', note='')
        d = os.path.join(data, 'derive', pkg); os.makedirs(d, exist_ok=True)
        copy_text(os.path.join(derive, pkg), d)
        for f in os.listdir(d):
            if f.endswith('.nupkg') or f.endswith('.dll') or f.endswith('.pdb'):
                os.remove(os.path.join(d, f))
    derived = {pkg: r for pkg, r in results.items() if r['category'].startswith('derived')}
    log(f'derived {len(derived)} of {len(results)}; skipped: ' + ', '.join(p for p, r in results.items() if p not in derived))

    # 2. recipes into the repository
    for pkg in derived:
        shutil.copy(os.path.join(derive, pkg, 'recipe.toml'), os.path.join(recipes, f'{pkg.lower()}.toml'))
    if push and derived:
        sh(['git', '-C', REPO, 'add', recipes], log)
        sh(['git', '-C', REPO, 'commit', '-q', '-m', f'Release-only recipes, batch {batch}',
            '-m', f'Derived by derive.py, {len(derived)} of {len(results)} packages in the list; the facts are in the batch data folder.'], log)
        sh(['git', '-C', REPO, 'pull', '--rebase', '--autostash', '-q'], log)
        sh(['git', '-C', REPO, 'push', '-q', 'origin', 'main'], log)
    commit = sh(['git', '-C', REPO, 'rev-parse', '--short', 'HEAD'], log).stdout.strip()
    log(f'recipes at {commit}')

    # 3. builds: Windows dispatched first, Linux built here meanwhile
    runs = {}
    for pkg, r in derived.items():
        if r['os'] == 'windows':
            res = sh(['gh', 'workflow', 'run', 'nupkg-rebuild.yml', '-R', GH_REPO, '-f', f'recipe=release-only/{batch}/{pkg.lower()}.toml', '-f', 'runner=windows-2022'], log, timeout=120)
            if res.returncode:
                r['build'] = 'dispatch failed'; r['note'] = res.stderr.strip()[-200:]
            else:
                time.sleep(3)
                runs[pkg] = None   # id found below
    time.sleep(10)
    if runs:
        res = sh(['gh', 'run', 'list', '-R', GH_REPO, '-w', 'nupkg-rebuild.yml', '-L', str(len(runs) + 10), '--json', 'databaseId,displayTitle,headSha,createdAt'], log, timeout=120)
        for run in json.loads(res.stdout or '[]'):
            for pkg in runs:
                if runs[pkg] is None and f'release-only/{batch}/{pkg.lower()}.toml' in run['displayTitle'] and run['headSha'].startswith(commit):
                    runs[pkg] = run['databaseId']
        log('windows runs: ' + ', '.join(f'{p}={i}' for p, i in runs.items()))
    for pkg, r in derived.items():
        if r['os'] != 'linux':
            continue
        work = os.path.join(lab, 'build', pkg)
        res = sh([sys.executable, '-I', os.path.join(HERE, 'rebuild.py'), os.path.join(recipes, f'{pkg.lower()}.toml'), work], log, timeout=3600)
        r['build'] = 'ran' if res.returncode == 0 else f'rebuild.py exit {res.returncode}'
        log(f'{pkg}: ' + res.stdout.strip().replace('\n', ' | ')[-400:])

    # 4. wait for the Windows runs
    pending = {p: i for p, i in runs.items() if i}
    for pkg in runs:
        if not runs[pkg]:
            derived[pkg]['build'] = 'run id not found'
    while pending:
        time.sleep(30)
        for pkg, rid in list(pending.items()):
            res = subprocess.run(['gh', 'run', 'view', str(rid), '-R', GH_REPO, '--json', 'status,conclusion'], capture_output=True, text=True)
            try:
                st = json.loads(res.stdout)
            except json.JSONDecodeError:
                continue
            if st.get('status') == 'completed':
                dest = os.path.join(lab, 'gh', str(rid))
                dl = sh(['gh', 'run', 'download', str(rid), '-R', GH_REPO, '-D', dest], log, timeout=300)
                derived[pkg]['build'] = f'ran ({st.get("conclusion")})' if dl.returncode == 0 else f'run {rid} {st.get("conclusion")}, no artifact'
                del pending[pkg]
                log(f'{pkg}: run {rid} {st.get("conclusion")}')

    # 5. levels and A = A2; 6. data and table
    for pkg, r in derived.items():
        recipe = tomllib.load(open(os.path.join(recipes, f'{pkg.lower()}.toml'), 'rb'))
        if r['os'] == 'linux':
            outdir = os.path.join(lab, 'build', pkg, 'out')
        else:
            rid = runs.get(pkg)
            outdir = next((root for root, _, fs in os.walk(os.path.join(lab, 'gh', str(rid))) if 'summary.txt' in fs), None) if rid else None
        if not outdir or not os.path.isdir(outdir):
            r['note'] = r['note'] or 'no output folder'
            continue
        summary = open(os.path.join(outdir, 'summary.txt'), encoding='utf-8').read() if os.path.exists(os.path.join(outdir, 'summary.txt')) else ''
        m = re.search(r'builds A exit (\d+), A2 exit (\d+)', summary)
        if m and m.group(1) != '0':
            r['build'] = f'did not build (exit {m.group(1)})'
        a2 = re.search(r'\.dll A vs A2: (\w+)', summary)
        r['a_eq_a2'] = {'identical': 'yes', 'differs': 'no'}.get(a2.group(1), '') if a2 else ''
        r['level'], note = level_of(outdir, recipe, log)
        r['note'] = note
        dest = os.path.join(data, 'windows' if r['os'] == 'windows' else 'arch', pkg)
        copy_text(outdir, dest)
        log(f'{pkg}: build {r["build"]}, level {r["level"] or "-"}, A=A2 {r["a_eq_a2"] or "-"}; {note}')
    with open(os.path.join(data, 'results.tsv'), 'w', encoding='utf-8') as f:
        keys = ['package', 'version', 'category', 'os', 'sdk', 'build', 'level', 'a_eq_a2', 'note']
        f.write('\t'.join(keys) + '\n')
        for r in results.values():
            f.write('\t'.join(str(r[k]) for k in keys) + '\n')
    shutil.copy(os.path.join(lab, 'run.log'), os.path.join(data, 'run.log'))
    log(f'done: results in {os.path.join(data, "results.tsv")}')


if __name__ == '__main__':
    main()
