"""Sample the .NET SDK's processes once a second while a build runs.

For every process whose executable is DOTNET, one line per second: its role
(main command, MSBuild worker node, compiler server), start time, umask, CPU
time, and the markers of reprotest's variations: libfaketime, locale, TZ,
PATH, HOME, the capture variable, allowed CPUs, ASLR (from the stack address),
the personality where readable, UTS namespace and working directory. It shows which processes did the work of
a build, and whether the variation reached them.

Usage: python3 sample-dotnet.py OUTFILE    (stop it with kill)
DOTNET_EXE in the environment overrides the dotnet executable to follow.

Written 24 September 2026 for phoenix-layer2-reprotest; markers for the
remaining axes added the same afternoon.
"""
import os
import sys
import time

DOTNET = os.environ.get('DOTNET_EXE', '/home/leos/.dotnet/dotnet')


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
    status = open(f'{base}/status').read().splitlines()
    umask = next(l.split()[1] for l in status if l.startswith('Umask:'))
    uid = next(l.split()[1] for l in status if l.startswith('Uid:'))
    env = dict(e.split('=', 1) for e in
               open(f'{base}/environ', 'rb').read().decode(errors='replace').split('\0') if '=' in e)
    maps = open(f'{base}/maps').read()
    faketime_loaded = 'libfaketime' in maps
    # With ASLR off the main thread's stack always ends at the top of the user
    # address space.
    stack_top = next((l.split()[0].split('-')[1] for l in maps.splitlines() if l.endswith('[stack]')), '')
    aslr = 'off' if stack_top == '7ffffffff000' else 'on'
    ncpus = next(l.split(':')[1].strip() for l in open(f'{base}/status') if l.startswith('Cpus_allowed_list:'))
    ncpus = sum(int(b) - int(a) + 1 if '-' in r_ else 1
                for r_ in ncpus.split(',') for a, _, b in [r_.partition('-')])
    try:  # needs ptrace rights: with Yama's ptrace_scope 1, only for descendants
        personality = open(f'{base}/personality').read().strip()
    except PermissionError:
        personality = 'na'
    utsns = os.readlink(f'{base}/ns/uts').split('[')[-1].rstrip(']')
    cwd = os.path.basename(os.readlink(f'{base}/cwd'))
    r = role(cmd)
    line = (f'pid={pid} ppid={ppid} start={start} role={r} uid={uid} umask={umask} cpu={cpu} '
            f'libfaketime={int(faketime_loaded)} FAKETIME={env.get("FAKETIME", "")} '
            f'LANG={env.get("LANG", "")} LC_ALL={env.get("LC_ALL", "")} TZ={env.get("TZ", "")} '
            f'exec_path={int(env.get("PATH", "").endswith(":/i_capture_the_path"))} '
            f'home={env.get("HOME", "").replace(" ", "_")} capenv={int("REPROTEST_CAPTURE_ENVIRONMENT" in env)} '
            f'ncpus={ncpus} pers={personality} aslr={aslr} utsns={utsns} cwd={cwd.replace(" ", "_")}')
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
