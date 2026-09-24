"""Summarise a sample-dotnet.py file from one reprotest run.

The main processes (restore, publish, build-server) of each build carry that
build's variation. They split the samples into a control window and an
experiment window. For every compiler server and MSBuild worker node the
script prints when it started, its umask and variation markers, and how much
CPU time it used in each window. A server started in the control window that
uses CPU in the experiment window did the experiment's work without its
variation.

Usage: python3 analyze-samples.py SAMPLES AXIS
AXIS is a reprotest variation, or "all" (marked by umask 0002). For
num_cpus, MIN_CPUS in the environment gives the control build's CPU count.
The time marker is FAKETIME in the environment; libfaketime mapped is
reported separately.

Written 24 September 2026 for phoenix-layer2-reprotest.
"""
import collections
import datetime
import os
import sys

HOST_UTS = os.readlink('/proc/self/ns/uts').split('[')[-1].rstrip(']')

MIN_CPUS = int(os.environ.get('MIN_CPUS', '2'))
UNAME26, ADDR_NO_RANDOMIZE = 0x0020000, 0x0040000
MARKER = {
    'umask': lambda s: s['umask'] == '0002',
    'time': lambda s: s['FAKETIME'] != '',
    'locales': lambda s: s['LANG'] == 'et_EE.UTF-8',
    'exec_path': lambda s: s['exec_path'] == '1',
    'timezone': lambda s: s.get('TZ') == 'GMT-14',
    'environment': lambda s: s.get('capenv') == '1',
    'home': lambda s: s.get('home', '').startswith('/nonexistent'),
    'num_cpus': lambda s: int(s.get('ncpus', '0')) > MIN_CPUS,
    'kernel': lambda s: s.get('pers', 'na') != 'na' and bool(int(s['pers'], 16) & UNAME26),
    'aslr': lambda s: s.get('aslr') == 'on',
    'build_path': lambda s: s.get('cwd', '').startswith('build-experiment'),
    'domain_host': lambda s: s.get('utsns', '') != HOST_UTS,
    'all': lambda s: s['umask'] == '0002',
}


def boot_time():
    for line in open('/proc/stat'):
        if line.startswith('btime'):
            return int(line.split()[1])


def main():
    path, axis = sys.argv[1], sys.argv[2]
    varied = MARKER[axis]
    tick = os.sysconf('SC_CLK_TCK')
    btime = boot_time()
    samples = collections.defaultdict(list)
    for line in open(path):
        t, *kv = line.split()
        s = dict(x.split('=', 1) for x in kv)
        s['t'] = int(t)
        samples[s['pid'], s['start']].append(s)

    windows = {'control': [], 'experiment': []}
    for key, ss in samples.items():
        if ss[0]['role'].startswith('main-'):
            build = 'experiment' if varied(ss[0]) else 'control'
            windows[build] += [ss[0]['t'], ss[-1]['t']]
    span = {b: (min(ts), max(ts)) for b, ts in windows.items() if ts}

    def clock(t):
        return datetime.datetime.fromtimestamp(t).strftime('%H:%M:%S')

    for b, (lo, hi) in span.items():
        mains = sum(1 for ss in samples.values()
                    if ss[0]['role'].startswith('main-') and (varied(ss[0]) == (b == 'experiment')))
        print(f'{b:10} window {clock(lo)}-{clock(hi)}, {mains} main processes')
    exp = [ss for ss in samples.values() if varied(ss[0])]
    print(f'experiment processes carrying the marker: {len(exp)}', end='')
    if axis == 'time':
        mapped = sum(1 for ss in exp if any(s['libfaketime'] == '1' for s in ss))
        print(f', libfaketime mapped in {mapped}', end='')
    print()

    def cpu_in(ss, lo, hi):
        inside = [s for s in ss if lo <= s['t'] <= hi]
        before = [s for s in ss if s['t'] < lo]
        if not inside:
            return 0
        start = int(before[-1]['cpu']) if before else 0
        return int(inside[-1]['cpu']) - start

    print(f'\n{"role":13} {"pid":>8} {"started":>8} {"umask":5} {"varied":6} '
          f'{"cpu control":>11} {"cpu experiment":>14}   (cpu in 1/{tick} s)')
    for (pid, start), ss in sorted(samples.items(), key=lambda kv: int(kv[0][1])):
        r = ss[0]['role']
        if r.startswith('main-'):
            continue
        started = clock(btime + int(start) / tick)
        c = cpu_in(ss, *span['control']) if 'control' in span else 0
        e = cpu_in(ss, *span['experiment']) if 'experiment' in span else 0
        print(f'{r:13} {pid:>8} {started:>8} {ss[0]["umask"]:5} {str(varied(ss[0])):6} '
              f'{c:>11} {e:>14}   {ss[0].get("cmd", "")}')


if __name__ == '__main__':
    main()
