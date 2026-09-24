"""Summarise a sample-tree.py file from one reprotest run.

Processes that carry the variation's marker belong to the experiment build;
their first and last sample span the experiment window. The script lists

- every process started before that window that is still alive in it, with
  the CPU time it used there. reprotest's own processes are expected; a build
  tool here is a survivor from the control build;
- for the experiment's processes, how many carry the marker and, for time,
  how many actually have libfaketime mapped.

Usage: python3 analyze-tree.py SAMPLES AXIS    AXIS: umask or time

Written 24 September 2026 for toolchain-servers.
"""
import collections
import datetime
import sys

MARKER = {
    'umask': lambda s: s['umask'] == '0002',
    'time': lambda s: s['FAKETIME'] != '',
}
INFRA = {'reprotest', 'autopkgtest-vir', 'tee', 'sleep', 'sh', 'bash', 'diffoscope', 'run.sh', 'timeout'}


def main():
    path, axis = sys.argv[1], sys.argv[2]
    varied = MARKER[axis]
    procs = collections.defaultdict(list)
    for line in open(path):
        t, *kv = line.split()
        s = dict(x.split('=', 1) for x in kv)
        s['t'] = float(t)
        procs[s['pid'], s['start']].append(s)

    exp = [ss for ss in procs.values() if varied(ss[0])]
    if not exp:
        print('no process carries the marker')
        return
    lo = min(ss[0]['t'] for ss in exp)
    hi = max(ss[-1]['t'] for ss in exp)
    clock = lambda t: datetime.datetime.fromtimestamp(t).strftime('%H:%M:%S')
    print(f'experiment window {clock(lo)}-{clock(hi)}, {len(exp)} processes with the marker')

    names = collections.Counter(ss[0]['comm'] for ss in exp)
    print('  by name:', ', '.join(f'{n} x{c}' for n, c in sorted(names.items())))
    if axis == 'time':
        faked = collections.Counter((ss[0]['comm'], any(s['libfaketime'] == '1' for s in ss)) for ss in exp)
        print('  libfaketime mapped:', ', '.join(f'{n}={"yes" if m else "NO"} x{c}' for (n, m), c in sorted(faked.items())))

    print('\nprocesses started before the window and alive in it:')
    for (pid, start), ss in sorted(procs.items(), key=lambda kv: kv[1][0]['t']):
        if varied(ss[0]) or ss[0]['t'] >= lo:
            continue
        inside = [s for s in ss if lo <= s['t'] <= hi]
        if not inside:
            continue
        before = [s for s in ss if s['t'] < lo]
        cpu = int(inside[-1]['cpu']) - int(before[-1]['cpu'])
        kind = 'reprotest itself' if ss[0]['comm'] in INFRA else 'SURVIVOR'
        print(f'  {kind:16} {ss[0]["comm"]:16} pid {pid:>8} since {clock(ss[0]["t"])} '
              f'umask {ss[0]["umask"]} cpu in window {cpu / 100:.2f} s')

    last = max(s['t'] for ss in procs.values() for s in ss)
    alive = [ss for ss in procs.values() if ss[-1]['t'] >= last - 0.5 and ss[0]['comm'] not in INFRA]
    print('\nstill alive at the last sample:', ', '.join(f'{ss[0]["comm"]} (pid {ss[0]["pid"]})' for ss in alive) or 'none')


if __name__ == '__main__':
    main()
