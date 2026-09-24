"""Sample the .NET SDK's processes once a second while a build runs.

For every process whose executable is DOTNET, one line per second: its role
(main command, MSBuild worker node, compiler server), start time, umask, CPU
time, and the markers of reprotest's variations: libfaketime, locale, TZ,
PATH, HOME, the capture variable, allowed CPUs, personality (uname-2.6, ASLR),
UTS namespace and working directory. It shows which processes did the work of
a build, and whether the variation reached them.

Usage: python3 sample-dotnet.py OUTFILE    (stop it with kill)

Written 24 September 2026 for phoenix-layer2-reprotest; markers for the
remaining axes added the same afternoon.
"""
import os
import sys
import time

DOTNET = '/home/leos/.dotnet/dotnet'


def role(cmd):
    if 'VBCSCompiler.dll' in cmd:
        return 'vbcscompiler'
    if 'nodemode:' in cmd.lower():
        return 'msbuild-node'
    for verb in ('build-server', 'restore', 'publish', 'build'):
        if f' {verb} ' in f' {cmd} ':
            return 'main-' + verb
    return 'other'


def sample(pid):
    base = f'/proc/{pid}'
    if os.readlink(f'{base}/exe') != DOTNET:
        return None
    cmd = open(f'{base}/cmdline', 'rb').read().replace(b'\0', b' ').decode(errors='replace')
    if 'JetBrains' in cmd:  # Rider's own MSBuild hosts
        return None
    stat = open(f'{base}/stat').read()
    fields = stat[stat.rindex(')') + 2:].split()
    ppid, cpu, start = fields[1], int(fields[11]) + int(fields[12]), fields[19]
    umask = next(l.split()[1] for l in open(f'{base}/status') if l.startswith('Umask:'))
    env = dict(e.split('=', 1) for e in
               open(f'{base}/environ', 'rb').read().decode(errors='replace').split('\0') if '=' in e)
    faketime_loaded = 'libfaketime' in open(f'{base}/maps').read()
    ncpus = next(l.split(':')[1].strip() for l in open(f'{base}/status') if l.startswith('Cpus_allowed_list:'))
    ncpus = sum(int(b) - int(a) + 1 if '-' in r_ else 1
                for r_ in ncpus.split(',') for a, _, b in [r_.partition('-')])
    personality = open(f'{base}/personality').read().strip()
    utsns = os.readlink(f'{base}/ns/uts').split('[')[-1].rstrip(']')
    cwd = os.path.basename(os.readlink(f'{base}/cwd'))
    r = role(cmd)
    line = (f'pid={pid} ppid={ppid} start={start} role={r} umask={umask} cpu={cpu} '
            f'libfaketime={int(faketime_loaded)} FAKETIME={env.get("FAKETIME", "")} '
            f'LANG={env.get("LANG", "")} LC_ALL={env.get("LC_ALL", "")} TZ={env.get("TZ", "")} '
            f'exec_path={int(env.get("PATH", "").endswith(":/i_capture_the_path"))} '
            f'home={env.get("HOME", "").replace(" ", "_")} capenv={int("REPROTEST_CAPTURE_ENVIRONMENT" in env)} '
            f'ncpus={ncpus} pers={personality} utsns={utsns} cwd={cwd.replace(" ", "_")}')
    if r == 'other':  # name it, so unrelated dotnet tools can be told apart
        line += ' cmd=' + '|'.join(cmd.split()[:3])[:120]
    return line


def main():
    out = open(sys.argv[1], 'a', buffering=1)
    while True:
        now = f'{time.time():.0f}'
        for pid in os.listdir('/proc'):
            if not pid.isdigit():
                continue
            try:
                line = sample(pid)
            except (OSError, ValueError, StopIteration):
                continue
            if line:
                out.write(f'{now} {line}\n')
        time.sleep(1)


if __name__ == '__main__':
    main()
