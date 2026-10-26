"""Derive release-only recipes for a list of packages, one after the other.

Usage: python3 -I derive-batch.py LIST CENSUS_FILES_CSV LAB OUT

LIST has one "Package Version" per line (# comments allowed). Each package
goes through derive.py into OUT/<Package>/; a derivation that raises stops
nothing: its error is recorded as "skipped (derive.py failed: ...)". The
end is OUT/batch.txt, one line per package with its category and, for a
derived package, its OS, SDK and the recipe's path, so that the Linux ones
can be built here and the Windows ones dispatched to the runner.

Written 26 October 2026 for round A on the packages not seen before.
"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    lst, census, lab, out = sys.argv[1:5]
    os.makedirs(out, exist_ok=True)
    lines = []
    for raw in open(lst, encoding='utf-8'):
        raw = raw.split('#')[0].strip()
        if not raw:
            continue
        pkg, ver = raw.split()
        dest = os.path.join(out, pkg)
        r = subprocess.run([sys.executable, '-I', os.path.join(HERE, 'derive.py'), pkg, ver, census, lab, dest],
                           capture_output=True, text=True)
        facts = os.path.join(dest, 'facts.txt')
        if os.path.exists(facts):
            cat = [l for l in open(facts, encoding='utf-8') if l.startswith('category:')][-1].strip()[len('category: '):]
            os_ = sdk = ''
            rec = os.path.join(dest, 'recipe.toml')
            if os.path.exists(rec):
                import tomllib
                t = tomllib.load(open(rec, 'rb'))
                os_, sdk = t['os'], t['sdk']
            line = f'{pkg} {ver}\t{cat}\t{os_}\t{sdk}\t{rec if os.path.exists(rec) else ""}'
        else:
            err = (r.stderr.strip().splitlines() or [f'exit {r.returncode}'])[-1]
            os.makedirs(dest, exist_ok=True)
            open(os.path.join(dest, 'error.txt'), 'w', encoding='utf-8').write(r.stdout + r.stderr)
            line = f'{pkg} {ver}\tskipped (derive.py failed: {err[:160]})\t\t\t'
        print(line, flush=True)
        lines.append(line)
    with open(os.path.join(out, 'batch.txt'), 'w', encoding='utf-8') as f:
        f.write('package version\tcategory\tos\tsdk\trecipe\n' + '\n'.join(lines) + '\n')


if __name__ == '__main__':
    main()
