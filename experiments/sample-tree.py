"""Sample every process below a root PID, four times a second.

A process counts as part of the run once it has been seen below ROOT, and it
stays tracked after its parent dies and it is reparented. That way a server
started by reprotest's control build is still followed while the experiment
build runs. One line per process per sample: name, executable, start time,
umask, CPU time, FAKETIME from its environment and whether libfaketime is
mapped into it.

Usage: python3 sample-tree.py OUTFILE ROOTPID    (stop it with kill)

Written 24 September 2026 for toolchain-servers. The .NET-only predecessor
is sample-dotnet.py.
"""
import os
import sys
import time


def read(path, mode='r'):
    with open(path, mode) as f:
        return f.read()


def snapshot():
    procs = {}
    for p in os.listdir('/proc'):
        if not p.isdigit():
            continue
        try:
            st = read(f'/proc/{p}/stat')
        except OSError:
            continue
        r = st.rindex(')')
        comm = st[st.index('(') + 1:r].replace(' ', '_')
        f = st[r + 2:].split()
        procs[int(p)] = (int(f[1]), f[19], comm, int(f[11]) + int(f[12]))
    return procs


def below(procs, root):
    children = {}
    for pid, (ppid, *_) in procs.items():
        children.setdefault(ppid, []).append(pid)
    seen, stack = set(), [root]
    while stack:
        for c in children.get(stack.pop(), []):
            if c not in seen:
                seen.add(c)
                stack.append(c)
    return seen


def main():
    out = open(sys.argv[1], 'a', buffering=1)
    root, me = int(sys.argv[2]), os.getpid()
    known = set()
    while True:
        now = time.time()
        procs = snapshot()
        known |= {(pid, procs[pid][1]) for pid in below(procs, root) if pid != me}
        for pid, (ppid, start, comm, cpu) in procs.items():
            if (pid, start) not in known:
                continue
            try:
                umask = next(l.split()[1] for l in open(f'/proc/{pid}/status') if l.startswith('Umask:'))
                env = read(f'/proc/{pid}/environ', 'rb').split(b'\0')
                faketime = next((e[9:].decode() for e in env if e.startswith(b'FAKETIME=')), '')
                mapped = 'libfaketime' in read(f'/proc/{pid}/maps')
                exe = os.path.basename(os.readlink(f'/proc/{pid}/exe')).replace(' ', '_')
            except (OSError, StopIteration, ValueError):
                continue
            out.write(f'{now:.2f} pid={pid} ppid={ppid} start={start} comm={comm} exe={exe} '
                      f'umask={umask} cpu={cpu} FAKETIME={faketime} libfaketime={int(mapped)}\n')
        time.sleep(0.25)


if __name__ == '__main__':
    main()
