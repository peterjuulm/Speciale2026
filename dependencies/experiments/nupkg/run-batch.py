"""Round A for a batch of packages, start to finish, with a log and a table.

Usage: python3 -I run-batch.py BATCH LIST LAB [--no-push] [--rederive]

BATCH is a name (the data folder dependencies/data/<BATCH>/ and the recipe
folder recipes/release-only/<BATCH>/ get it). LIST has one "Package Version"
per line. LAB is a folder outside the repositories. Every package is keyed
by name and version together (folders <Package>-<version>, recipes
<package>-<version>.toml), so two versions of one package stay apart. The
steps:

 1. derive every package (derive-batch.py) into LAB/derive, then check that
    the list and the derivations agree pair for pair (check-batch.py);
 2. copy each derived recipe to the repository, commit and push them, so the
    runner builds start from a commit that holds them;
 3. build the local ones here, one after the other (rebuild.py), and
    dispatch one workflow run per runner one (gh);
 4. wait for the runs, download their output;
 5. for every build: the match level (level.py on dllreport.cs reports of
    nuget.org's DLL and ours), which report lines differ, and A against A2;
 6. copy every text output into the data folder and write results.tsv.

results.tsv keeps the three questions apart: publisher_match (the level
against nuget.org), a_eq_a2 (our own repeat), variation (always "not
tested" here; round B's). The other columns: package, version, category,
os, runner, sdk, sdk_alternatives (the SDKs rule 3 did not read because a
lower one matched: an uncertainty, not a match), environment (the runner
image or this machine's kernel, from the build log), build, differs (the
report lines that differ, from level.py), note.

A Linux recipe whose recorded build folder cannot be made here (a GitHub
runner's /home/runner/work/...) goes to GitHub's ubuntu-24.04 runner, where
it can; the runner column says where each build ran.

--no-push: nothing is committed, pushed or dispatched; the local builds
run, the runner-bound packages are marked "awaiting push". A second run in
the same LAB reuses the derivations (unless --rederive) and every local
build whose output exists, so the runner half can follow once the recipes
are on the repository's main branch.

Disk: the run refuses to start a local build with fewer than
MIN_FREE_GB free under LAB, marks the package "not built: disk" and goes
on; the log says what is needed.

Everything it does and every failure goes to LAB/run.log and the console.
A failure in one package never stops the batch. Run it under nohup or in
the background; it takes an hour or more for fifty packages.

Written 26 October 2026 for round A on the packages not tried before;
keys by name and version, staged pushing and the disk guard 27 October.
"""
import datetime, json, os, re, shutil, subprocess, sys, time, tomllib, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
CENSUS = os.path.join(REPO, 'dependencies', 'data', '2026-10-13-dependency-census', 'mac', 'census.files.csv')
GH_REPO = 'peterjuulm/Speciale2026'
REPORT_DOTNET = os.environ.get('DLLREPORT_DOTNET', '/private/tmp/rb1-dotnet10/sdk/dotnet')
MIN_FREE_GB = 8
COLUMNS = ['package', 'version', 'category', 'os', 'runner', 'sdk', 'sdk_alternatives', 'environment',
           'build', 'publisher_match', 'a_eq_a2', 'variation', 'differs', 'note']


def now():
    return datetime.datetime.now().astimezone().isoformat(timespec='seconds')


def key(pkg, ver):
    return f'{pkg}-{ver}'


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


def free_gb(path):
    st = os.statvfs(path)
    return st.f_bavail * st.f_frsize / 2**30


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


def can_make(path):
    """Whether this user can create PATH here: its nearest existing ancestor is writable."""
    if not path or not path.startswith('/'):
        return True
    p = path
    while not os.path.exists(p):
        p = os.path.dirname(p)
    return os.access(p, os.W_OK)


def level_of(outdir, recipe, log):
    """The level of A's shipped DLL against nuget.org's, from their reports, and the differing lines; '' when a package is missing."""
    ships = recipe['ships']
    lid, lver = recipe['package'].lower(), recipe['version'].lower()
    ref = os.path.join(outdir, 'nuget-org', f'{lid}.{lver}.nupkg')
    packed = sorted(f for f in os.listdir(os.path.join(outdir, 'A')) if f.lower().endswith('.nupkg')) if os.path.isdir(os.path.join(outdir, 'A')) else []
    a = next((os.path.join(outdir, 'A', f) for f in packed if f.lower() == f'{lid}.{lver}.nupkg'), None)
    other = ''
    if not a and len(packed) == 1:   # packed under another version (a version tool's own); the DLL is still compared
        a = os.path.join(outdir, 'A', packed[0]); other = f'packed as {packed[0]}, not {lid}.{lver}.nupkg; '
    if not (a and os.path.exists(ref)):
        return '', '', 'no package to compare' + (f' (packed: {", ".join(packed)})' if packed else '')
    lv = os.path.join(outdir, 'level'); os.makedirs(lv, exist_ok=True)
    for src, name in ((ref, 'nugetorg'), (a, 'A')):
        try:
            data = zipfile.ZipFile(src).read(ships)
        except KeyError:
            return '', '', f'{ships} not in {os.path.basename(src)}'
        open(os.path.join(lv, f'{name}.dll'), 'wb').write(data)
        if not report(os.path.join(lv, f'{name}.dll'), os.path.join(lv, f'report-{name}.txt'), log):
            return '', '', 'report failed'
    r = subprocess.run([sys.executable, '-I', os.path.join(HERE, 'level.py'), os.path.join(lv, 'report-nugetorg.txt'), os.path.join(lv, 'report-A.txt')],
                       capture_output=True, text=True)
    m = re.match(r'level (\d); differing lines: (.*)', r.stdout.strip())
    if not m:
        return '', '', other + r.stdout.strip()
    return m.group(1), m.group(2), other.rstrip('; ')


def sdk_alternatives(facts_path):
    """The SDKs rule 3 did not read, from the derivation's facts."""
    for line in open(facts_path, encoding='utf-8'):
        if line.startswith('sdk:'):
            m = re.search(r'not read: ([^)]*)\)', line)
            return '' if not m or m.group(1) == 'none' else m.group(1)
    return ''


def environment(outdir):
    """The runner image, or the kernel, as rebuild.py logged it for build A."""
    p = os.path.join(outdir, 'A', 'build.log')
    if not os.path.exists(p):
        return ''
    found = []
    for line in open(p, encoding='utf-8', errors='replace'):
        if line.startswith('runner ImageOS=') or line.startswith('runner ImageVersion=') or line.startswith('kernel '):
            found.append(line.strip().replace('runner ', ''))
        if line.startswith('--- build'):
            break
    return ', '.join(found)


def main():
    batch, lst, lab = sys.argv[1], os.path.abspath(sys.argv[2]), os.path.abspath(sys.argv[3])
    push = '--no-push' not in sys.argv
    os.makedirs(lab, exist_ok=True)
    os.environ.setdefault('NUPKG_GIT_MIRRORS', os.path.join(lab, 'mirrors'))   # one mirror per repository for the local builds
    log = Log(os.path.join(lab, 'run.log'))
    data = os.path.join(REPO, 'dependencies', 'data', batch)
    recipes = os.path.join(HERE, 'recipes', 'release-only', batch)
    os.makedirs(data, exist_ok=True); os.makedirs(recipes, exist_ok=True)
    log(f'batch {batch}: list {lst}, lab {lab}, repo at {sh(["git", "-C", REPO, "rev-parse", "--short", "HEAD"], log).stdout.strip()}, '
        f'{free_gb(lab):.0f} GB free under the lab, push {"on" if push else "off"}')

    # 1. derive, and check the list against the derivations
    derive = os.path.join(lab, 'derive')
    if os.path.exists(os.path.join(derive, 'batch.txt')) and '--rederive' not in sys.argv:
        log('derive: reusing the derivations in ' + derive)
    else:
        sh([sys.executable, '-I', os.path.join(HERE, 'derive-batch.py'), lst, CENSUS, lab, derive], log, timeout=14400)
    chk = sh([sys.executable, '-I', os.path.join(HERE, 'check-batch.py'), lst, derive], log)
    log('check-batch: ' + (chk.stdout.strip() or chk.stderr.strip()))
    rows = [l.rstrip('\n').split('\t') for l in open(os.path.join(derive, 'batch.txt'), encoding='utf-8')][1:]
    results = {}
    for pv, cat, os_, sdk, rec in rows:
        pkg, ver = pv.split()
        k = key(pkg, ver)
        results[k] = dict(package=pkg, version=ver, category=cat, os=os_, runner='', sdk=sdk, sdk_alternatives='', environment='',
                          build='', publisher_match='', a_eq_a2='', variation='not tested (round B)', differs='', note='')
        d = os.path.join(data, 'derive', k); os.makedirs(d, exist_ok=True)
        copy_text(os.path.join(derive, k), d)
        for f in os.listdir(d):
            if f.endswith('.nupkg') or f.endswith('.dll') or f.endswith('.pdb'):
                os.remove(os.path.join(d, f))
        if os.path.exists(os.path.join(derive, k, 'facts.txt')):
            results[k]['sdk_alternatives'] = sdk_alternatives(os.path.join(derive, k, 'facts.txt'))
    derived = {k: r for k, r in results.items() if r['category'].startswith('derived')}
    for k, r in derived.items():
        recipe = tomllib.load(open(os.path.join(derive, k, 'recipe.toml'), 'rb'))
        r['runner'] = 'windows-2022' if r['os'] == 'windows' else ('arch' if can_make(recipe.get('clone_dir')) else 'ubuntu-24.04')
    log(f'derived {len(derived)} of {len(results)}; skipped: ' + ', '.join(k for k in results if k not in derived))

    # 2. recipes into the repository
    for k in derived:
        shutil.copy(os.path.join(derive, k, 'recipe.toml'), os.path.join(recipes, f'{k.lower()}.toml'))
    if push and derived:
        sh(['git', '-C', REPO, 'add', recipes], log)
        sh(['git', '-C', REPO, 'commit', '-q', '-m', f'Release-only recipes, batch {batch}',
            '-m', f'Derived by derive.py, {len(derived)} of {len(results)} packages in the list; the facts are in the batch data folder.'], log)
        sh(['git', '-C', REPO, 'pull', '--rebase', '--autostash', '-q'], log)
        sh(['git', '-C', REPO, 'push', '-q', 'origin', 'main'], log)
    commit = sh(['git', '-C', REPO, 'rev-parse', '--short', 'HEAD'], log).stdout.strip()
    log(f'recipes at {commit}' + ('' if push else ' (not committed: --no-push)'))

    # 3. builds: the runner ones dispatched first, the local ones built here meanwhile
    runs = {}
    for k, r in derived.items():
        if r['runner'] == 'arch':
            continue
        if not push:
            r['build'] = 'awaiting push'
            continue
        res = sh(['gh', 'workflow', 'run', 'nupkg-rebuild.yml', '-R', GH_REPO, '-f', f'recipe=release-only/{batch}/{k.lower()}.toml', '-f', f'runner={r["runner"]}'], log, timeout=120)
        if res.returncode:
            r['build'] = 'dispatch failed'; r['note'] = res.stderr.strip()[-200:]
        else:
            time.sleep(3)
            runs[k] = None   # id found below

    def find_ids():
        # a queued run shows the workflow's name, not its run-name, so the lookup is repeated while waiting
        res = subprocess.run(['gh', 'run', 'list', '-R', GH_REPO, '-w', 'nupkg-rebuild.yml', '-L', str(len(runs) + 20), '--json', 'databaseId,displayTitle,headSha'], capture_output=True, text=True)
        for run in json.loads(res.stdout or '[]'):
            for k in runs:
                if runs[k] is None and f'release-only/{batch}/{k.lower()}.toml' in run['displayTitle'] and run['headSha'].startswith(commit):
                    runs[k] = run['databaseId']
    if runs:
        time.sleep(15); find_ids()
        log('runner runs: ' + ', '.join(f'{p}={i}' for p, i in runs.items()))
    for k, r in derived.items():
        if r['runner'] != 'arch':
            continue
        work = os.path.join(lab, 'build', k)
        if os.path.exists(os.path.join(work, 'out', 'summary.txt')):
            r['build'] = 'ran (earlier run, output reused)'
            log(f'{k}: reusing the build output in {work}')
            continue
        if free_gb(lab) < MIN_FREE_GB:
            r['build'] = 'not built: disk'; r['note'] = f'{free_gb(lab):.1f} GB free under the lab, {MIN_FREE_GB} needed'
            log(f'{k}: {r["note"]}')
            continue
        shutil.rmtree(work, ignore_errors=True)
        res = sh([sys.executable, '-I', os.path.join(HERE, 'rebuild.py'), os.path.join(recipes, f'{k.lower()}.toml'), work], log, timeout=7200)
        r['build'] = 'ran' if res.returncode == 0 else f'rebuild.py exit {res.returncode}'
        log(f'{k}: ' + res.stdout.strip().replace('\n', ' | ')[-400:])
        for d in ('A', 'sdk'):   # the clone, cache and SDK go once the output is saved; out/ stays
            shutil.rmtree(os.path.join(work, d), ignore_errors=True)
        recipe = tomllib.load(open(os.path.join(recipes, f'{k.lower()}.toml'), 'rb'))
        if recipe.get('clone_dir'):
            shutil.rmtree(recipe['clone_dir'], ignore_errors=True)

    # 4. wait for the runner runs
    pending = dict(runs)
    waited = 0
    while pending:
        time.sleep(30); waited += 30
        if not all(pending.values()):
            find_ids()
            pending = {p: runs[p] for p in pending}
        for k, rid in list(pending.items()):
            if rid is None:
                if waited > 3600:
                    derived[k]['build'] = 'run id not found in an hour'; del pending[k]
                    log(f'{k}: no run found for its dispatch')
                continue
            res = subprocess.run(['gh', 'run', 'view', str(rid), '-R', GH_REPO, '--json', 'status,conclusion'], capture_output=True, text=True)
            try:
                st = json.loads(res.stdout)
            except json.JSONDecodeError:
                continue
            if st.get('status') == 'completed':
                dest = os.path.join(lab, 'gh', str(rid))
                dl = sh(['gh', 'run', 'download', str(rid), '-R', GH_REPO, '-D', dest], log, timeout=300)
                derived[k]['build'] = f'ran ({st.get("conclusion")})' if dl.returncode == 0 else f'run {rid} {st.get("conclusion")}, no artifact'
                del pending[k]
                log(f'{k}: run {rid} {st.get("conclusion")}')

    # 5. levels, differing lines and A = A2; 6. data and table
    for k, r in derived.items():
        recipe = tomllib.load(open(os.path.join(recipes, f'{k.lower()}.toml'), 'rb'))
        if r['runner'] == 'arch':
            outdir = os.path.join(lab, 'build', k, 'out')
        else:
            rid = runs.get(k)
            outdir = next((root for root, _, fs in os.walk(os.path.join(lab, 'gh', str(rid))) if 'summary.txt' in fs), None) if rid else None
        if not outdir or not os.path.isdir(outdir):
            r['note'] = r['note'] or ('no output folder' if r['build'] not in ('awaiting push', 'not built: disk') else '')
            continue
        summary = open(os.path.join(outdir, 'summary.txt'), encoding='utf-8').read() if os.path.exists(os.path.join(outdir, 'summary.txt')) else ''
        m = re.search(r'builds A exit (\d+), A2 exit (\d+)', summary)
        if m and m.group(1) != '0':
            r['build'] = f'did not build (exit {m.group(1)})'
        a2 = re.search(r'\.dll A vs A2: (\w+)', summary)
        r['a_eq_a2'] = {'identical': 'yes', 'differs': 'no'}.get(a2.group(1), '') if a2 else 'not compared'
        r['environment'] = environment(outdir)
        r['publisher_match'], r['differs'], note = level_of(outdir, recipe, log)
        r['note'] = note
        dest = os.path.join(data, r['runner'], k)
        copy_text(outdir, dest)
        log(f'{k}: build {r["build"]}, level {r["publisher_match"] or "-"}, A=A2 {r["a_eq_a2"] or "-"}; {note}')
    with open(os.path.join(data, 'results.tsv'), 'w', encoding='utf-8') as f:
        f.write('\t'.join(COLUMNS) + '\n')
        for r in results.values():
            f.write('\t'.join(str(r[c]) for c in COLUMNS) + '\n')
    shutil.copy(os.path.join(lab, 'run.log'), os.path.join(data, 'run.log'))
    log(f'done: results in {os.path.join(data, "results.tsv")}')


if __name__ == '__main__':
    main()
