"""The reprotest test for one NuGet package, from its release-only recipe.

Usage: python3 -I reprotest-run.py RECIPE WORKDIR [AXIS...]

Round B of the nupkg test (dependencies/notes/2026-10-26-nupkg-release-only.md):
the determinism measure of Benedetti et al., on our own build of a package.
The recipe is the one round A built from (recipes/release-only/), so the
command is the same fixed dotnet pack. Linux only, as reprotest is.

For each axis, reprotest builds the package twice in copies of the clone, the
second time with that one thing varied (--vary=-all,+AXIS), and compares the
artefact: the lib/ folder taken out of the .nupkg, that is every DLL and PDB
the package ships, not the .nupkg itself, whose core-properties file gets a
new id at every pack. The axes, one run each, in this order:

  build_path environment kernel locales exec_path time timezone umask fileordering

The first is the folder, which Benedetti et al. left out and which .NET
embeds unless ContinuousIntegrationBuild is set; the other eight are theirs.
fileordering needs disorderfs; without it reprotest exits 125 and the axis is
recorded as not run. Each build starts with dotnet build-server shutdown, so
no build reuses the previous one's compiler server (W27).

The SDK is installed alone in WORKDIR/sdk; the NuGet cache (WORKDIR/nuget)
and DOTNET_CLI_HOME are fixed paths outside the copied tree, filled by one
restore before the runs, so that no run downloads. WORKDIR/out gets one log,
one command file and one store (reprotest's copies of both artefacts) per
axis, and summary.txt: per axis, reproducible, not reproducible (exit 1),
build failed, or not run.

Written 26 October 2026.
"""
import datetime, os, shutil, subprocess, sys, tomllib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rebuild   # the clone as round A made it

AXES = ['build_path', 'environment', 'kernel', 'locales', 'exec_path', 'time', 'timezone', 'umask', 'fileordering']
REPROTEST = shutil.which('reprotest') or os.path.expanduser('~/.local/bin/reprotest')


def now():
    return datetime.datetime.now().astimezone().isoformat(timespec='seconds')


def main():
    recipe_path, work = sys.argv[1], os.path.abspath(sys.argv[2])
    axes = sys.argv[3:] or AXES
    with open(recipe_path, 'rb') as f:
        r = tomllib.load(f)
    if r.get('os', 'linux') != 'linux':
        sys.exit(f'{r["package"]}: a {r["os"]} package; reprotest runs on Linux only')
    os.makedirs(work)
    out, sdk, nuget, clihome, src = (os.path.join(work, d) for d in ('out', 'sdk', 'nuget', 'clihome', 'src'))
    os.makedirs(out); os.makedirs(nuget); os.makedirs(clihome)
    shutil.copy(recipe_path, os.path.join(out, 'recipe.toml'))
    with open(os.path.join(out, 'setup.log'), 'w', encoding='utf-8') as log:
        log.write(f'start {now()}\n')
        rebuild.must(log, [sys.executable, '-I', os.path.join(HERE, 'install-sdk.py'), r['sdk'], sdk])
        env = dict(os.environ, PATH=f'{sdk}:{os.environ["PATH"]}', DOTNET_ROOT=sdk, DOTNET_CLI_HOME=clihome,
                   NUGET_PACKAGES=nuget, DOTNET_CLI_TELEMETRY_OPTOUT='1', DOTNET_NOLOGO='1', NuGetAudit='false')
        env.update({k: str(v).replace('{src}', src) for k, v in r.get('env', {}).items()})
        rebuild.clone(r, src, env, log)
        # fill the package cache once, so that the runs are offline
        rebuild.must(log, ['dotnet', 'restore', r['project']], env, src)
        rebuild.run(log, ['dotnet', 'build-server', 'shutdown'], env, src)
        log.write(f'ready {now()}\n')
    # every build: the SDK first on PATH, fixed cache and CLI home; reprotest's own variations come through the rest
    pre = (f'export PATH={sdk}:$PATH DOTNET_ROOT={sdk} DOTNET_CLI_HOME={clihome} NUGET_PACKAGES={nuget} '
           f'DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 NuGetAudit=false'
           + ''.join(f' {k}={str(v).replace("{src}", ".")!r}' for k, v in r.get('env', {}).items()))
    cmd = (f'{pre} && dotnet build-server shutdown >/dev/null 2>&1; {r["build"]} && '
           f'rm -rf artifact && mkdir artifact && unzip -q -o {r["packages"]}/*.nupkg "lib/*" -d artifact')
    open(os.path.join(out, 'command.txt'), 'w', encoding='utf-8').write(cmd + '\n')
    results = []
    for axis in axes:
        log = os.path.join(out, f'{axis}.log')
        with open(log, 'w', encoding='utf-8') as f:
            f.write(f'start {now()}\n'); f.flush()
            rc = subprocess.run([REPROTEST, '-v', '--store-dir', os.path.join(out, f'{axis}-store'),
                                 f'--vary=-all,+{axis}', '-c', cmd, src, 'artifact'],
                                stdout=f, stderr=subprocess.STDOUT, env=env).returncode
            f.write(f'end {now()} exit {rc}\n')
        text = open(log, encoding='utf-8').read()
        if rc == 0:
            verdict = 'reproducible'
        elif rc == 1 and 'differences' in text.lower():
            verdict = 'NOT reproducible (artefacts differ)'
        elif rc == 125 or 'disorderfs' in text:
            verdict = 'not run (reprotest could not vary it; disorderfs missing?)'
        else:
            verdict = f'build failed under reprotest (exit {rc})'
        results.append(f'{axis}: {verdict}')
        print(results[-1], flush=True)
        shutil.rmtree(os.path.join(src, 'artifact'), ignore_errors=True)
    with open(os.path.join(out, 'summary.txt'), 'w', encoding='utf-8') as f:
        f.write(f'{r["package"]} {r["version"]}, reprotest, SDK {r["sdk"]}, {now()}\n' + '\n'.join(results) + '\n')


if __name__ == '__main__':
    main()
