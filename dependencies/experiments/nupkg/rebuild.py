"""Rebuild one NuGet package from its declared commit, twice, and compare.

Usage: python -I rebuild.py RECIPE WORKDIR

RECIPE is a TOML file in recipes/ that says how the package's own CI built
it: repository and commit; how the CI checked it out (depth, branch or tag,
git config, directory); the SDK; the build command and its shell (bash, pwsh
or cmd); where the package lands; and the environment variables the CI set.
WORKDIR must not exist.
The script

1. installs the recipe's SDK alone into WORKDIR/sdk (install-sdk.py);
2. builds twice, each time from a fresh clone: A in the recipe's clone_dir
   if it has one (the path the CI built in), else in WORKDIR/A/src, and B in
   WORKDIR/B/src. The directory is the one thing that differs between them;
3. downloads the package from nuget.org, and its .snupkg if there is one;
4. compares A with nuget.org's package, B with nuget.org's, and A with B,
   for the shipped DLL and its PDB, and lists every entry of all three
   (compare.py).

Logs, the built packages and the comparisons land in WORKDIR/out, and a
summary goes to stdout. The exit code is 0 when the script ran to the end,
whatever the verdicts: a build that fails is a result, recorded in the
summary.

The build's environment. On Linux it is empty apart from HOME, PATH (the SDK
first, then /usr/bin), LANG, NUGET_PACKAGES, DOTNET_CLI_TELEMETRY_OPTOUT,
DOTNET_NOLOGO and the recipe's [env], as in build.sh. Windows cannot run a
build in an empty environment, so there the build keeps the runner's
environment minus the runner's own CI identity and .NET settings (GITHUB_*,
RUNNER_*, ACTIONS_*, DOTNET_*, NUGET_*, CI), with no other dotnet on PATH;
the recipe's [env] then sets the CI variables the package's own CI had. In
[env] values, {src} stands for the clone's directory.

Every build gets NuGetAudit=false. The audit checks the restored packages
against today's advisory database, so an advisory published after the
release can fail a restore that passed at the time (Serilog 4.2.0's tests on
Windows, 21/10: NU1902/NU1903 as errors). The audit only warns or fails; it
does not change what is compiled.

Written 21 October 2026 for the nupkg test. For new builds it replaces
build.sh, which built the pilot's Serilog builds A to D on arch.
"""
import datetime, hashlib, os, re, shutil, subprocess, sys, tomllib, urllib.error, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
WINDOWS = os.name == 'nt'
SECRET = re.compile('TOKEN|SECRET|KEY|PASSWORD|CREDENTIAL', re.I)


def now():
    return datetime.datetime.now().astimezone().isoformat(timespec='seconds')


def run(log, cmd, env=None, cwd=None):
    """Run cmd with its output appended to the open log; return the exit code.

    The program is looked up on the build's PATH, not ours: on Windows a child
    process is otherwise found through the parent's PATH, which would pick the
    runner's own dotnet."""
    log.write(f'$ {" ".join(cmd)}\n')
    log.flush()
    exe = shutil.which(cmd[0], path=env['PATH']) if env else cmd[0]
    if not exe:
        log.write(f'{cmd[0]}: not on the build\'s PATH\n')
        return 127
    return subprocess.run([exe] + cmd[1:], env=env, cwd=cwd, stdout=log, stderr=subprocess.STDOUT).returncode


def must(log, cmd, env=None, cwd=None):
    code = run(log, cmd, env, cwd)
    if code:
        raise RuntimeError(f'{" ".join(cmd)} exited {code}')


def build_env(r, sdk, home, nuget, src):
    if WINDOWS:
        drop = ('GITHUB_', 'RUNNER_', 'ACTIONS_', 'DOTNET_', 'NUGET_')
        env = {k: v for k, v in os.environ.items() if not k.upper().startswith(drop) and k.upper() != 'CI'}
        path = [p for p in env.get('PATH', '').split(os.pathsep) if p and 'dotnet' not in p.lower()]
        env.update(PATH=os.pathsep.join([sdk] + path), DOTNET_ROOT=sdk, DOTNET_CLI_HOME=home,
                   NUGET_HTTP_CACHE_PATH=os.path.join(home, 'nuget-http-cache'))
    else:
        env = {'HOME': home, 'PATH': f'{sdk}:/usr/bin', 'LANG': 'C.UTF-8'}
    env.update(NUGET_PACKAGES=nuget, DOTNET_CLI_TELEMETRY_OPTOUT='1', DOTNET_NOLOGO='1', NuGetAudit='false')
    env.update({k: str(v).replace('{src}', src) for k, v in r.get('env', {}).items()})
    return env


def clone(r, src, env, log):
    git = ['git', '-C', src]
    must(log, ['git', 'init', '-q', src], env)
    must(log, git + ['remote', 'add', 'origin', r['repo']], env)
    for c in r.get('git_config', []):
        must(log, git + ['config'] + c.split('=', 1), env)
    detached = ['-c', 'advice.detachedHead=false', 'checkout', '-q']
    if r.get('tag'):       # as actions/checkout for a pushed tag: the tag only, HEAD detached at it
        ref = f'refs/tags/{r["tag"]}'
        must(log, git + ['fetch', '-q', '--no-tags', f'--depth={r.get("depth", 1)}', 'origin', f'+{ref}:{ref}'], env)
        must(log, git + detached + [ref], env)
    else:
        if r.get('depth'):   # as actions/checkout for a push: the one commit, no tags
            must(log, git + ['fetch', '-q', '--no-tags', f'--depth={r["depth"]}', 'origin', r['commit']], env)
        else:                # a full clone, tags included
            must(log, git + ['fetch', '-q', '--tags', 'origin', '+refs/heads/*:refs/remotes/origin/*'], env)
        if r.get('branch'):  # HEAD on the pushed branch
            must(log, git + ['checkout', '-q', '-B', r['branch'], r['commit']], env)
        else:
            must(log, git + detached + [r['commit']], env)
    head = subprocess.run([shutil.which('git', path=env['PATH']), '-C', src, 'rev-parse', 'HEAD'],
                          env=env, capture_output=True, text=True).stdout.strip()
    if head != r['commit']:
        raise RuntimeError(f'HEAD is {head}, not the declared {r["commit"]}')


def build(r, name, src, work, sdk, out):
    d = os.path.join(work, name)
    home, nuget = os.path.join(d, 'home'), os.path.join(d, 'nuget')
    os.makedirs(home)
    os.makedirs(nuget)
    env = build_env(r, sdk, home, nuget, src)
    dest = os.path.join(out, name)
    os.makedirs(dest)
    with open(os.path.join(dest, 'build.log'), 'w', encoding='utf-8') as log:
        log.write(f'start {now()}\nbuild {name} in {src}\n--- environment\n')
        for k in sorted(env):
            log.write(f'{k}={"<redacted>" if SECRET.search(k) else env[k]}\n')
        log.write(f'--- clone {now()}\n')
        clone(r, src, env, log)
        run(log, ['git', '-C', src, 'config', '--list', '--show-origin'], env)
        for args in (['rev-parse', 'HEAD'], ['rev-parse', '--abbrev-ref', 'HEAD'], ['tag', '--points-at', 'HEAD']):
            run(log, ['git', '-C', src] + args, env)
        log.write(f'--- toolchain {now()}\n')
        run(log, ['dotnet', '--info'], env, src)
        for root, _, files in os.walk(os.path.join(sdk, 'sdk')):
            if 'csc.dll' in files and root.endswith(os.path.join('Roslyn', 'bincore')):
                csc = os.path.join(root, 'csc.dll')
                data = open(csc, 'rb').read()
                # the informational version's attribute blob: prolog 01 00, a length byte, the string
                v = re.search(rb'\x01\x00.(\d+\.\d+\.\d+-[0-9.]+\+[0-9a-f]{40})', data, re.S)
                log.write(f'csc.dll {v.group(1).decode() if v else "version not found"}, '
                          f'sha256 {hashlib.sha256(data).hexdigest()} ({csc})\n')
        log.write(f'--- build {now()}\n')
        run(log, ['dotnet', 'build-server', 'shutdown'], env, src)
        shell = {'pwsh': ['pwsh', '-NoProfile', '-NonInteractive', '-Command'],
                 'cmd': ['cmd', '/c'], 'bash': ['bash', '-c']}[r.get('shell', 'bash')]
        code = run(log, shell + [r['build']], env, src)
        run(log, ['dotnet', 'build-server', 'shutdown'], env, src)
        log.write(f'build exit code {code}\nend {now()}\n')
    found = []
    want = {f'{r["package"]}.{r["version"]}.{x}'.lower() for x in ('nupkg', 'snupkg')}
    pkgdir = os.path.join(src, r.get('packages', '.'))   # where the CI took the package from
    for f in os.listdir(pkgdir) if os.path.isdir(pkgdir) else []:
        if f.lower() in want:
            shutil.copy(os.path.join(pkgdir, f), dest)
            found.append(f)
    return code, sorted(found)


def download(url, path):
    try:
        with urllib.request.urlopen(url, timeout=300) as resp, open(path, 'wb') as f:
            shutil.copyfileobj(resp, f)
        return True
    except urllib.error.HTTPError as e:
        print(f'{url}: HTTP {e.code}')
        return False


def main():
    recipe_path, work = sys.argv[1], os.path.abspath(sys.argv[2])
    with open(recipe_path, 'rb') as f:
        r = tomllib.load(f)
    os.makedirs(work)
    out = os.path.join(work, 'out')
    os.makedirs(out)
    shutil.copy(recipe_path, os.path.join(out, 'recipe.toml'))
    pid, ver = r['package'], r['version']
    print(f'{pid} {ver} from {r["repo"]} at {r["commit"]}, SDK {r["sdk"]}, start {now()}', flush=True)

    sdk = os.path.join(work, 'sdk')
    with open(os.path.join(out, 'sdk.txt'), 'w', encoding='utf-8') as log:
        must(log, [sys.executable, '-I', os.path.join(HERE, 'install-sdk.py'), r['sdk'], sdk])
        for rt in r.get('runtimes', []):   # runtimes the CI image had, for the tests
            must(log, [sys.executable, '-I', os.path.join(HERE, 'install-sdk.py'), '--runtime', rt, sdk])

    results = {}
    for name, src in (('A', r.get('clone_dir') or os.path.join(work, 'A', 'src')), ('B', os.path.join(work, 'B', 'src'))):
        if os.path.exists(src):
            sys.exit(f'{src} exists')
        results[name] = build(r, name, src, work, sdk, out)
        print(f'build {name} in {src}: exit {results[name][0]}, packages {results[name][1]}', flush=True)

    ref = os.path.join(out, 'nuget-org')
    os.makedirs(ref)
    lid, lver = pid.lower(), ver.lower()
    download(f'https://api.nuget.org/v3-flatcontainer/{lid}/{lver}/{lid}.{lver}.nupkg', os.path.join(ref, f'{lid}.{lver}.nupkg'))
    download(f'https://www.nuget.org/api/v2/symbolpackage/{pid}/{ver}', os.path.join(ref, f'{lid}.{lver}.snupkg'))

    summary = [f'{pid} {ver}: builds ' + ', '.join(f'{n} exit {c}' for n, (c, _) in results.items())]
    pdb = r['ships'][:-4] + '.pdb'
    for kind, inner in (('nupkg', r['ships']), ('snupkg', pdb)):
        def pkg(d):
            return next((os.path.join(d, f) for f in os.listdir(d) if f.lower() == f'{lid}.{lver}.{kind}'), None)
        p = {'nuget.org': pkg(ref), 'A': pkg(os.path.join(out, 'A')), 'B': pkg(os.path.join(out, 'B'))}
        present = [n for n in p if p[n]]
        if len(present) < 2:
            summary.append(f'{kind}: not compared, fewer than two packages')
            continue
        # every entry of every package, for reading; then one verdict per pair
        with open(os.path.join(out, f'compare-{kind}.txt'), 'w', encoding='utf-8') as f:
            subprocess.run([sys.executable, '-I', os.path.join(HERE, 'compare.py'), inner] + [p[n] for n in present], stdout=f)
        for x, y in (('A', 'nuget.org'), ('B', 'nuget.org'), ('A', 'B')):
            if p[x] and p[y]:
                same = subprocess.run([sys.executable, '-I', os.path.join(HERE, 'compare.py'), inner, p[y], p[x]],
                                      stdout=subprocess.DEVNULL).returncode == 0
                summary.append(f'{kind}: {inner} {x} vs {y}: {"identical" if same else "differs"}')
            else:
                summary.append(f'{kind}: {x} vs {y}: not compared, a package is missing')
    summary.append(f'end {now()}')
    with open(os.path.join(out, 'summary.txt'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(summary) + '\n')
    print('\n'.join(summary))


if __name__ == '__main__':
    main()
