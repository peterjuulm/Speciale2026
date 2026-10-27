"""Run a batch of repository builds in order, classify every product, record, commit, clean up.

Usage: python3 -I run-repo-batch.py BATCH ORDER LAB [NAME...]

BATCH names the recipe folder recipes/repository/BATCH/ (made by derive-repo.py) and the
data folder dependencies/data/BATCH/. ORDER is a text file listing recipe names, one per
line, in the order to run them ('#' comments). NAMEs limit the run to those recipes.

For each recipe, one at a time: check the free disk (stop below MIN_FREE_GB); for a runtime
recipe check that cmake and ninja exist (else "not run: cmake missing", rule in the plan);
run repo-build.py with a timeout; classify each product with run-batch.py's level_of; write
every product's row to results.tsv; copy the text outputs into the data folder (the full
build log when it is under 4 MB, else its head, its error lines and its tail, with the full
log kept gzipped in LAB/logs); commit and push; delete the lab's build folder, keeping
only out/ under LAB/keep/<name>/. Everything is logged to LAB/run.log, copied to the data
folder after every recipe.

Repository-build method, 27 October 2026: dependencies/notes/2026-10-27-nupkg-repository-build-plan.md
"""
import gzip, importlib.util, os, shutil, signal, subprocess, sys, threading, time, tomllib

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('rb', os.path.join(HERE, 'run-batch.py'))
rb = importlib.util.module_from_spec(spec); spec.loader.exec_module(rb)
TIMEOUT = 4 * 3600
COLUMNS = ['recipe', 'repository', 'commit', 'inner', 'build_id', 'package', 'version', 'ships', 'publisher_match',
           'differs', 'a_eq_a2', 'variation', 'build', 'environment', 'note']
GIT_ID = ['-c', 'user.name=Leo Sakharoff', '-c', 'user.email=leo@sakharoff.dk']


def run_build(args, lab, log, timeout):
    """Run repo-build.py in its own process group; kill the whole group on timeout or when the disk runs low."""
    log('$ ' + ' '.join(args))
    p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)
    reason = {}

    def watch():
        start = time.time()
        while p.poll() is None:
            if time.time() - start > timeout:
                reason['why'] = f'timed out after {timeout // 3600} h'
            elif rb.free_gb(lab) < rb.MIN_FREE_GB:
                reason['why'] = f'stopped, {rb.free_gb(lab):.1f} GB free during the build'
            if reason:
                log(f'  {reason["why"]}: killing the build\'s process group')
                try:
                    os.killpg(p.pid, signal.SIGTERM); time.sleep(20); os.killpg(p.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                return
            time.sleep(30)
    t = threading.Thread(target=watch, daemon=True); t.start()
    out = p.communicate()[0]
    t.join(timeout=5)
    return p.returncode, out, reason.get('why')


def write_rows(path, rows):
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\t'.join(COLUMNS) + '\n')
        for r in rows:
            f.write('\t'.join(str(r.get(c, '')).replace('\t', ' ').replace('\n', ' ') for c in COLUMNS) + '\n')


def excerpt(src, dst, lab, name):
    """Copy a build log whole when small; else head, error lines and tail, with the whole log gzipped in the lab."""
    if os.path.getsize(src) <= 4 * 1024 * 1024:
        shutil.copy(src, dst); return
    lines = open(src, encoding='utf-8', errors='replace').read().split('\n')
    errs = [l for l in lines if 'error' in l.lower()][:400]
    os.makedirs(os.path.join(lab, 'logs'), exist_ok=True)
    with open(src, 'rb') as f, gzip.open(os.path.join(lab, 'logs', f'{name}.build.log.gz'), 'wb') as g:
        shutil.copyfileobj(f, g)
    with open(dst, 'w', encoding='utf-8') as f:
        f.write(f'# excerpt: the log is {len(lines)} lines; the first 300, up to 400 lines with "error", and the last 300; whole log in LAB/logs/{name}.build.log.gz\n')
        f.write('\n'.join(lines[:300]) + '\n# --- error lines ---\n' + '\n'.join(errs) + '\n# --- tail ---\n' + '\n'.join(lines[-300:]) + '\n')


def commit(data_dir, recipes_dir, msg, log):
    for args in (['add', '-A', data_dir, recipes_dir], GIT_ID + ['commit', '-q', '-m', msg], ['pull', '--rebase', '--autostash', '-q'], ['push', '-q', 'origin', 'main']):
        r = subprocess.run(['git', '-C', rb.REPO] + args, capture_output=True, text=True)
        if r.returncode and 'nothing to commit' not in r.stdout + r.stderr:
            log(f'  git {args[0]} failed: {(r.stderr or r.stdout).strip()[-300:]}')
            if args[0] in ('commit', 'add'):
                return


def main():
    batch, order_file, lab = sys.argv[1:4]; only = set(sys.argv[4:])
    recipes = os.path.join(rb.HERE, 'recipes', 'repository', batch)
    data = os.path.join(rb.REPO, 'dependencies', 'data', batch)
    os.makedirs(os.path.join(data, 'arch'), exist_ok=True); os.makedirs(os.path.join(lab, 'build'), exist_ok=True)
    os.environ.setdefault('NUPKG_GIT_MIRRORS', os.path.join(lab, 'mirrors'))
    log = rb.Log(os.path.join(lab, 'run.log'))
    results = os.path.join(data, 'results.tsv')
    rows = []
    if os.path.exists(results):
        import csv
        rows = list(csv.DictReader(open(results, encoding='utf-8'), delimiter='\t'))
    names = [l.split('#')[0].strip() for l in open(order_file, encoding='utf-8')]
    names = [n for n in names if n and (not only or n in only)]
    log(f'batch {batch}: {len(names)} recipes in order, lab {lab}')
    for name in names:
        rpath = os.path.join(recipes, name, 'recipe.toml')
        if not os.path.exists(rpath):
            log(f'{name}: no recipe'); continue
        r = tomllib.load(open(rpath, 'rb'))
        rows = [x for x in rows if x['recipe'] != name]   # a rerun replaces the recipe's rows
        base = {'recipe': name, 'repository': r['repo'], 'commit': r['commit'], 'inner': r.get('inner', ''), 'build_id': r['official_build_id'],
                'a_eq_a2': 'not tested', 'variation': 'not tested'}
        free = rb.free_gb(lab)
        if free < rb.MIN_FREE_GB:
            log(f'{name}: stopping, {free:.1f} GB free'); break
        missing = [t for t in ('cmake', 'ninja', 'clang') if not shutil.which(t, path='/usr/bin')] if r['kind'] == 'runtime' else []
        if missing:
            log(f'{name}: not run, missing {", ".join(missing)}')
            for p in r['products']:
                rows.append({**base, **p, 'build': f'not run: {", ".join(missing)} missing on this machine'})
            write_rows(results, rows); continue
        work = os.path.join(lab, 'build', name)
        shutil.rmtree(work, ignore_errors=True)
        log(f'{name}: {len(r["products"])} products, {free:.0f} GB free, start')
        code, stdout, why = run_build([sys.executable, '-I', os.path.join(rb.HERE, 'repo-build.py'), rpath, work], lab, log, TIMEOUT)
        build = why or ('ran' if code == 0 else f'repo-build.py exit {code}')
        log(f'{name}: ' + (stdout or '').strip().replace('\n', ' | ')[-600:])
        out = os.path.join(work, 'out')
        exit_code = ''
        if os.path.exists(os.path.join(out, 'summary.txt')):
            first = open(os.path.join(out, 'summary.txt'), encoding='utf-8').readline()
            exit_code = first.split('build exit ')[1].split(',')[0] if 'build exit ' in first else ''
        if exit_code and exit_code != '0':
            build = f'did not build (exit {exit_code})'
        env = rb.environment(os.path.join(out, next((p['package'] + '-' + p['version'] for p in r['products']), ''))) if os.path.isdir(out) else ''
        for p in r['products']:
            pd = os.path.join(out, f'{p["package"]}-{p["version"]}')
            row = {**base, 'package': p['package'], 'version': p['version'], 'ships': p['ships'], 'build': build, 'environment': env}
            if os.path.isdir(pd):
                row['publisher_match'], row['differs'], row['note'] = rb.level_of(pd, p, log)
            else:
                row['note'] = 'no output folder'
            rows.append(row)
            log(f'  {p["package"]} {p["version"]}: level {row.get("publisher_match") or "-"}; {row.get("note", "")}')
        write_rows(results, rows)
        dest = os.path.join(data, 'arch', name)
        shutil.rmtree(dest, ignore_errors=True)
        if os.path.isdir(out):
            rb.copy_text(out, dest)
            if os.path.exists(os.path.join(out, 'build.log')):
                excerpt(os.path.join(out, 'build.log'), os.path.join(dest, 'build.log'), lab, name)
        shutil.copy(os.path.join(lab, 'run.log'), os.path.join(data, 'run.log'))
        commit(data, recipes, f'Repository build {name}: {sum(1 for x in rows if x["recipe"] == name and x.get("publisher_match"))} of {len(r["products"])} compared', log)
        keep = os.path.join(lab, 'keep', name)
        shutil.rmtree(keep, ignore_errors=True)
        if os.path.isdir(out):
            shutil.move(out, keep)
        shutil.rmtree(work, ignore_errors=True)
        log(f'{name}: done, lab cleaned, {rb.free_gb(lab):.0f} GB free')
    log('batch done')


if __name__ == '__main__':
    main()
