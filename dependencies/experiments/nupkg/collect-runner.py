"""Collect a Windows runner run of the repository-build method into a data folder.

Usage: python3 -I collect-runner.py BATCH RUN_ID [RUN_ID...]

BATCH names the recipe folder recipes/repository/BATCH/ and the data folder
dependencies/data/BATCH/. Each RUN_ID is a run of .github/workflows/nupkg-repository-build.yml;
its artifacts (one per recipe, <recipe>-<runner>, the out/ folder of repo-build.py) are
downloaded with gh into LAB/runner/<run>/<recipe>/, every product is classified with
run-batch.py's level_of (the same level.py as the Linux batches), and the rows go to
results.tsv in the shape of run-repo-batch.py; a later RUN_ID's artifact replaces an earlier
one's rows for the same recipe (a rerun after a script fault). The text outputs are copied
into the data folder under arch/<recipe>/ (packages and DLLs stay in the lab). Nothing is
committed: that is done by hand after reading the rows.

Written 28 October 2026 for the Windows run of version 3.
"""
import csv, importlib.util, os, shutil, subprocess, sys, tomllib

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('rb', os.path.join(HERE, 'run-batch.py'))
rb = importlib.util.module_from_spec(spec); spec.loader.exec_module(rb)
spec2 = importlib.util.spec_from_file_location('rrb', os.path.join(HERE, 'run-repo-batch.py'))
rrb = importlib.util.module_from_spec(spec2); spec2.loader.exec_module(rrb)
LAB = os.environ.get('NUPKG_LAB', '/private/tmp/nupkg-repobuild')


def main():
    batch, runs = sys.argv[1], sys.argv[2:]
    recipes = os.path.join(HERE, 'recipes', 'repository', batch)
    data = os.path.join(rb.REPO, 'dependencies', 'data', batch)
    os.makedirs(os.path.join(data, 'arch'), exist_ok=True)
    log = rb.Log(os.path.join(data, 'run.log'))
    results = os.path.join(data, 'results.tsv')
    rows = list(csv.DictReader(open(results, encoding='utf-8'), delimiter='\t')) if os.path.exists(results) else []
    for run in runs:
        dl = os.path.join(LAB, 'runner', run)
        shutil.rmtree(dl, ignore_errors=True); os.makedirs(dl)
        log(f'run {run}: downloading artifacts to {dl}')
        r = subprocess.run(['gh', 'run', 'download', run, '-D', dl], capture_output=True, text=True)
        if r.returncode:
            log(f'  gh run download failed: {(r.stderr or r.stdout).strip()[-300:]}'); continue
        for art in sorted(os.listdir(dl)):
            name, runner = art.rsplit('-', 2)[0], '-'.join(art.rsplit('-', 2)[1:])   # <recipe>-windows-2022
            out = os.path.join(dl, art)
            rpath = os.path.join(recipes, name, 'recipe.toml')
            if not os.path.exists(rpath):
                log(f'{art}: no recipe {name}'); continue
            r = tomllib.load(open(rpath, 'rb'))
            rows = [x for x in rows if x['recipe'] != name]
            base = {'recipe': name, 'repository': r['repo'], 'commit': r['commit'], 'inner': r.get('inner', ''), 'build_id': r['official_build_id'],
                    'a_eq_a2': 'not tested', 'variation': 'not tested'}
            first = open(os.path.join(out, 'summary.txt'), encoding='utf-8').readline() if os.path.exists(os.path.join(out, 'summary.txt')) else ''
            exit_code = first.split('build exit ')[1].split(',')[0] if 'build exit ' in first else ''
            build = 'ran' if exit_code == '0' else (f'did not build (exit {exit_code})' if exit_code else 'no summary')
            env = rb.environment(os.path.join(out, next((p['package'] + '-' + p['version'] for p in r['products']), '')))
            log(f'{name} on {runner} (run {run}): build {build}')
            for p in r['products']:
                pd = os.path.join(out, f'{p["package"]}-{p["version"]}')
                row = {**base, 'package': p['package'], 'version': p['version'], 'ships': p['ships'], 'build': build, 'environment': env}
                if os.path.isdir(pd):
                    row['publisher_match'], row['differs'], row['note'] = rb.level_of(pd, p, log)
                else:
                    row['note'] = 'no output folder'
                rows.append(row)
                log(f'  {p["package"]} {p["version"]}: level {row.get("publisher_match") or "-"}; {row.get("note", "")}')
            dest = os.path.join(data, 'arch', name)
            shutil.rmtree(dest, ignore_errors=True)
            rb.copy_text(out, dest)
            if os.path.exists(os.path.join(out, 'build.log')):
                rrb.excerpt(os.path.join(out, 'build.log'), os.path.join(dest, 'build.log'), LAB, f'{name}-{runner}')
    order = {n: i for i, n in enumerate(sorted(os.listdir(recipes)))}
    rows.sort(key=lambda x: (order.get(x['recipe'], 99), x['package']))
    rrb.write_rows(results, rows)
    log(f'{len(rows)} rows in {results}')


if __name__ == '__main__':
    main()
