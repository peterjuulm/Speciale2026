"""Summarise the reprotest-probe runs without leaking the environment.

Usage: python3 summarize.py OUT PUBLIC
  OUT     the private folder run.sh wrote: runs.txt, rt-<label>.log, store-<label>/
  PUBLIC  a folder for what may be published: summary.txt and scripts/

For every run: its exit code, what reprotest says it fixed and varied, the
values it picked, and which probe files differ between the control and the
experiment build, with the lines that differ. In env.txt only the variables
matching SHOW keep their values, PATH is shown as the parts added or removed,
and the rest only by name. The build scripts reprotest logs at -vv go to
scripts/. /tmp/reprotest.XXXXXX becomes /tmp/reprotest.X. Before anything is
written, every value of a variable outside SHOW is searched for in the
output, and the script stops if one is found.

Written 5 October 2026 for reprotest-probe.
"""
import collections
import os
import re
import sys

SHOW = re.compile(r'(LANG|LANGUAGE|LC_\w+|TZ|HOME|PWD|OLDPWD|USER|LOGNAME|USERNAME|SHELL|SHLVL|'
                  r'MAIL|FAKETIME\w*|NO_FAKE_STAT|LD_PRELOAD|REPROTEST_\w+|CPU_\w+|SUDO_\w+|OUT|_)')
TMP = re.compile(r'/tmp/reprotest\.\w{6}')
ORDER = (['inherited-' + a for a in (
    'none build_path time locales umask exec_path timezone environment home '
    'kernel aslr num_cpus user_group all domain_host fileordering').split()]
    + ['clean-' + a for a in ('none', 'user_group', 'all')])
ERROR = re.compile(r'not found|No such file|[Ee]rror|failed|Traceback|requires these')


def clean(s):
    return TMP.sub('/tmp/reprotest.X', s)


def read_env(path):
    env = {}
    for line in open(path, errors='replace'):
        k, sep, v = line.rstrip('\n').partition('=')
        if sep and re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', k):
            env[k] = v
    return env


def env_diff(a, b):
    out = []
    for k in sorted(set(a) | set(b)):
        va, vb = a.get(k), b.get(k)
        if va == vb:
            continue
        if k == 'PATH' and va is not None and vb is not None:
            pa, pb = va.split(':'), vb.split(':')
            parts = [f'-{p}' for p in pa if p not in pb] + [f'+{p}' for p in pb if p not in pa]
            out.append('PATH: ' + (' '.join(parts) or 'same parts, other order'))
        elif SHOW.fullmatch(k):
            out.append(f'{k}: {va if va is not None else "(unset)"} -> {vb if vb is not None else "(unset)"}')
        else:
            out.append(f'{k}: ' + ('added' if va is None else 'removed' if vb is None else 'value differs'))
    return out


def file_diffs(store):
    c = os.path.join(store, 'control', 'source-root', 'probe')
    e = os.path.join(store, 'experiment-1', 'source-root', 'probe')
    if not os.path.isdir(c):
        return None, []
    if os.path.islink(os.path.join(store, 'experiment-1')):
        return [], []
    if not os.path.isdir(e):  # the experiment build failed
        return None, []
    differ, details = [], []
    for f in sorted(set(os.listdir(c)) | set(os.listdir(e))):
        pc, pe = os.path.join(c, f), os.path.join(e, f)
        tc = open(pc, errors='replace').read() if os.path.exists(pc) else None
        te = open(pe, errors='replace').read() if os.path.exists(pe) else None
        if tc == te:
            continue
        differ.append(f)
        if f == 'env.txt' and tc is not None and te is not None:
            details += [f'  env.txt  {line}' for line in env_diff(read_env(pc), read_env(pe))]
        else:
            show = lambda t: '(missing)' if t is None else ' / '.join(t.strip().splitlines())
            details.append(f'  {f}  control: {show(tc)}  |  experiment: {show(te)}')
    return differ, details


def read_log(path):
    plan, picks, warnings, errors, scripts = {}, [], [], [], collections.defaultdict(list)
    build, in_script = None, False
    for line in open(path, errors='replace'):
        line = line.rstrip('\n')
        m = re.match(r'INFO:reprotest:build "([^"]+)": (.*)', line)
        if m:
            build = m.group(1)
            plan[build] = [p.split()[1] for p in m.group(2).split(', ') if p.startswith('vary ')]
            continue
        if 'BEGIN REPROTEST BUILD SCRIPT' in line:
            in_script = True
            continue
        if 'END REPROTEST BUILD SCRIPT' in line:
            in_script = False
            continue
        if in_script:
            scripts[build].append(line)
        elif re.match(r'INFO:reprotest\.build:.*variation', line):
            pick = f'{build}: {line.split(":", 2)[2]}'
            if pick not in picks:
                picks.append(pick)
        elif 'WARNING' in line:
            if line not in warnings:
                warnings.append(line)
        elif ERROR.search(line) and line not in errors:
            errors.append(line)
    return plan, picks, warnings, errors[-4:], scripts


def group_names(names):
    groups = collections.Counter(n.split('_')[0] for n in names)
    out = []
    for g, count in sorted(groups.items()):
        out.append(f'{g}_* ({count})' if count > 1 else next(n for n in names if n.split('_')[0] == g))
    return ', '.join(out)


def base_env(out, label):
    path = os.path.join(out, f'store-{label}', 'control', 'source-root', 'probe', 'env.txt')
    if not os.path.exists(path):
        return [f'{label}: no env.txt'], {}
    env = read_env(path)
    shown = [f'{k}={v}' for k, v in sorted(env.items()) if SHOW.fullmatch(k)]
    hidden = sorted(k for k in env if not SHOW.fullmatch(k) and k != 'PATH')
    return ([f'{label}: {len(env)} variables',
             '  with values: ' + ' '.join(shown),
             f'  PATH: {env.get("PATH", "(unset)")}',
             '  by name only: ' + group_names(hidden)], env)


def main():
    out, public = sys.argv[1], sys.argv[2]
    exits = dict(line.split(' exit ') for line in open(os.path.join(out, 'runs.txt')).read().splitlines()
                 if ' exit ' in line)
    secrets, shown = set(), set()
    lines =['reprotest-probe: what differs between the control and the experiment build, per run.',
             'Written by summarize.py from the private stores and logs. Values are shown only for the',
             'variables in SHOW (see summarize.py); /tmp/reprotest.XXXXXX is shortened to /tmp/reprotest.X.',
             '']
    table, details, scripts_out = [], [], {}
    for label in ORDER:
        log = os.path.join(out, f'rt-{label}.log')
        if not os.path.exists(log):
            continue
        plan, picks, warnings, errors, scripts = read_log(log)
        differ, diff_lines = file_diffs(os.path.join(out, f'store-{label}'))
        varied = ','.join(plan.get('experiment-1', [])) or '-'
        state = 'no store' if differ is None else ('none' if not differ else ' '.join(differ))
        table.append(f'{label:24} exit {exits.get(label, "?"):3}  control varies: '
                     f'{",".join(plan.get("control", [])) or "-":4}  experiment varies: {varied}')
        table.append(f'{"":24} differing probe files: {state}')
        details.append(f'== {label}')
        details += [f'  reprotest: {clean(p)}' for p in picks]
        details += [f'  {clean(w)}' for w in warnings]
        if exits.get(label, '0') != '0':
            details += [f'  log: {clean(e)}' for e in errors]
        details += [clean(d) for d in diff_lines]
        for build, text in scripts.items():
            scripts_out[f'{label}-{build}.sh'] = clean('\n'.join(text)) + '\n'
        for f in ('control', 'experiment-1'):
            p = os.path.join(out, f'store-{label}', f, 'source-root', 'probe', 'env.txt')
            if os.path.exists(p):
                env = read_env(p)
                secrets |= {(v, k) for k, v in env.items()
                            if not SHOW.fullmatch(k) and k != 'PATH' and len(v) >= 6}
                shown |= {v for k, v in env.items() if SHOW.fullmatch(k) or k == 'PATH'}
                shown |= {part for v in env.get('PATH', '').split(':') for part in [v]}
    lines += table + [''] + details + ['', '== Base environment of the control build']
    inherited, ienv = base_env(out, 'inherited-none')
    cleaned, cenv = base_env(out, 'clean-none')
    lines += [clean(x) for x in inherited + cleaned]
    if ienv and cenv:
        lines.append('  in inherited, not in clean: ' + group_names(sorted(set(ienv) - set(cenv))))
        lines.append('  in clean, not in inherited: ' + (group_names(sorted(set(cenv) - set(ienv))) or '-'))
    text = '\n'.join(lines) + '\n'
    everything = text + ''.join(scripts_out.values())
    # a hidden value that is also a shown one (e.g. /bin/bash) is not a leak
    leaked = sorted({k for v, k in secrets if v not in shown and v in everything})
    if leaked:
        sys.exit(f'stopped: the values of {", ".join(leaked)} would be written')
    os.makedirs(os.path.join(public, 'scripts'), exist_ok=True)
    open(os.path.join(public, 'summary.txt'), 'w').write(text)
    for name, body in scripts_out.items():
        open(os.path.join(public, 'scripts', name), 'w').write(body)
    print(text)


if __name__ == '__main__':
    main()
