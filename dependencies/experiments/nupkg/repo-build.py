"""Build one repository at its declared commit with its own build script, and compare its packages.

Usage: python3 -I repo-build.py RECIPE WORKDIR

RECIPE is a TOML file made by derive-repo.py (repository-build method, see
dependencies/notes/2026-10-27-nupkg-repository-build-plan.md): repository, commit, inner
repository (for the VMR), the build command and its [[products]], each a package with its
version and the DLL that ships in Phoenix. WORKDIR must not exist.

The script clones as rebuild.py does (full clone from the mirror in NUPKG_GIT_MIRRORS, the
commit checked out detached, the recipe's git config), removes the internal feeds from the
checked-in NuGet.config when the recipe says so (rule R5, every removal logged), runs the
build command once in rebuild.py's controlled environment (HOME, PATH /usr/bin, LANG,
NUGET_PACKAGES, no dotnet on PATH: the repository's own tools.sh installs the SDK from its
global.json into .dotnet), then for every product copies its .nupkg from the recipe's
packages folder, downloads the nuget.org package and compares the shipped DLL (compare.py).
Each product gets WORKDIR/out/<Package>-<version>/ in the shape run-batch.py classifies:
A/<nupkg>, A/build.log, nuget-org/<nupkg>, summary.txt. The repository build's full log is
WORKDIR/out/build.log; the toolchain the script installed is in WORKDIR/out/toolchain.txt.

One build only: A against A2 is not measured here (a second run of the small repositories is
the follow-up). Exit code 0 when the script ran to the end, whatever the verdicts.
"""
import glob, hashlib, importlib.util, os, re, shutil, subprocess, sys, tomllib
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('rebuild', os.path.join(HERE, 'rebuild.py'))
rebuild = importlib.util.module_from_spec(spec); spec.loader.exec_module(rebuild)
now, run, download = rebuild.now, rebuild.run, rebuild.download


def strip_internal_feeds(src, inner, log):
    """Remove feeds under pkgs.dev.azure.com/dnceng/internal from the checked-in NuGet.config files (rule R5)."""
    edits = []
    for d in {src, os.path.join(src, inner) if inner else src}:
        for cfg in glob.glob(os.path.join(d, '[Nn][Uu][Gg][Ee][Tt].[Cc]onfig')):
            tree = ET.parse(cfg); root = tree.getroot()
            removed = []
            for sources in root.findall('packageSources'):
                for add in list(sources.findall('add')):
                    if 'dnceng/internal' in add.get('value', ''):
                        sources.remove(add); removed.append(add.get('key'))
            if not removed:
                continue
            for sect, tag in (('disabledPackageSources', 'add'), ('packageSourceMapping', 'packageSource')):
                for s in root.findall(sect):
                    for e in list(s.findall(tag)):
                        if e.get('key') in removed:
                            s.remove(e)
            for creds in root.findall('packageSourceCredentials'):
                for e in list(creds):
                    if e.tag in removed:
                        creds.remove(e)
            tree.write(cfg, encoding='utf-8', xml_declaration=True)
            edits.append(f'{os.path.relpath(cfg, src)}: removed internal feeds {", ".join(removed)}')
    for e in edits:
        log.write(f'nuget.config edit: {e}\n')
    return edits


def fetch(url, path, log, tries=3):
    """Download with retries; a timeout or a partial file is not a crash."""
    import time, urllib.request
    for i in range(tries):
        try:
            with urllib.request.urlopen(url, timeout=300) as resp, open(path, 'wb') as f:
                shutil.copyfileobj(resp, f)
            return True
        except Exception as e:
            log.write(f'download {url}: {e} (try {i + 1})\n')
            if os.path.exists(path):
                os.remove(path)
            time.sleep(10)
    return False


def toolchain(src, inner):
    lines = []
    dn = os.path.join(src, inner, '.dotnet') if inner else os.path.join(src, '.dotnet')
    for sdk in sorted(glob.glob(os.path.join(dn, 'sdk', '*'))):
        csc = os.path.join(sdk, 'Roslyn', 'bincore', 'csc.dll')
        v = ''
        if os.path.exists(csc):
            data = open(csc, 'rb').read()
            m = re.search(rb'\x01\x00.(\d+\.\d+\.\d+-[0-9.]+\+[0-9a-f]{40})', data, re.S)
            v = f', csc {m.group(1).decode() if m else "version not found"}, sha256 {hashlib.sha256(data).hexdigest()}'
        lines.append(f'sdk {os.path.basename(sdk)} installed by the repository into {os.path.relpath(dn, src)}{v}')
    for rt in sorted(glob.glob(os.path.join(dn, 'shared', '*', '*'))):
        lines.append(f'runtime {os.path.basename(os.path.dirname(rt))} {os.path.basename(rt)}')
    for tool in ('clang', 'cmake', 'ninja', 'git', 'curl', 'openssl'):
        p = shutil.which(tool, path='/usr/bin')
        ver = subprocess.run([p, '--version'], capture_output=True, text=True).stdout.split('\n')[0] if p else 'missing'
        lines.append(f'{tool}: {ver}')
    for pkg in ('icu', 'openssl', 'glibc', 'krb5', 'zlib'):
        r = subprocess.run(['pacman', '-Q', pkg], capture_output=True, text=True)
        lines.append(f'system package {r.stdout.strip() or pkg + ": not installed"}')
    return lines


def main():
    recipe_path, work = sys.argv[1], os.path.abspath(sys.argv[2])
    r = tomllib.load(open(recipe_path, 'rb'))
    os.makedirs(work)
    out = os.path.join(work, 'out'); os.makedirs(out)
    shutil.copy(recipe_path, os.path.join(out, 'recipe.toml'))
    inner = r.get('inner', '')
    print(f'{r["name"]}: {r["repo"]} at {r["commit"]}, {len(r["products"])} products, start {now()}', flush=True)
    src, home, nuget = os.path.join(work, 'A', 'src'), os.path.join(work, 'A', 'home'), os.path.join(work, 'A', 'nuget') + os.sep
    os.makedirs(home); os.makedirs(nuget)
    env = rebuild.build_env(r, '', home, nuget, src)
    env['PATH'] = '/usr/bin'
    env.update(GIT_HTTP_LOW_SPEED_LIMIT='1000', GIT_HTTP_LOW_SPEED_TIME='120')   # a stalled fetch aborts instead of hanging
    env['DOTNET_INSTALL_DIR'] = os.path.join(src, inner, '.dotnet') if inner else os.path.join(src, '.dotnet')
    code = None
    with open(os.path.join(out, 'build.log'), 'w', encoding='utf-8') as log:
        log.write(f'start {now()}\nrepository build {r["name"]} in {src}\n')
        u = os.uname(); log.write(f'kernel {u.sysname} {u.release} {u.machine}\n')
        log.write('--- environment\n')
        for k in sorted(env):
            log.write(f'{k}={"<redacted>" if rebuild.SECRET.search(k) else env[k]}\n')
        log.write(f'--- clone {now()}\n')
        try:
            rebuild.clone(r, src, env, log)
        except Exception as e:
            log.write(f'clone failed: {e}\n')
            code = 'clone failed'
        if code is None:
            run(log, ['git', '-C', src, 'rev-parse', 'HEAD'], env)
            # the source at the commit includes its submodules (aspnetcore: MessagePack-CSharp, googletest), as the
            # publisher's checkout had them; rebuild.clone does not take them (27/10 21:52: CS2001 in App.Runtime)
            log.write(f'--- submodules {now()}\n')
            if run(log, ['git', '-C', src, 'submodule', 'update', '--init', '--recursive', '--depth', '1'], env):
                log.write('submodule checkout failed\n')
                code = 'submodule checkout failed'
        if code is None:
            edits = strip_internal_feeds(src, inner, log) if r.get('strip_internal_feeds') else []
            open(os.path.join(out, 'nuget-config-edits.txt'), 'w', encoding='utf-8').write('\n'.join(edits) + ('\n' if edits else 'no internal feeds removed\n'))
            log.write(f'--- build {now()}\n')
            code = run(log, ['bash', '-c', r['build']], env, src)
            run(log, ['bash', '-c', '[ -x "$DOTNET_INSTALL_DIR/dotnet" ] && "$DOTNET_INSTALL_DIR/dotnet" build-server shutdown; true'], env, src)
            # Arcade's tools.sh exits 0 after a failed build in --ci mode and writes ##vso[task.complete result=Failed;]
            # instead (27/10 23:13); that marker is the build's own verdict, so it sets the exit code here
            log.flush()
            failed = open(os.path.join(out, 'build.log'), encoding='utf-8', errors='replace').read().count('##vso[task.complete result=Failed')
            if code == 0 and failed:
                log.write(f'build exit code 0 but {failed} x "##vso[task.complete result=Failed" in the log: Arcade --ci hides the exit code, counted as exit 1\n')
                code = 1
            log.write(f'build exit code {code}\nend {now()}\n')
    open(os.path.join(out, 'toolchain.txt'), 'w', encoding='utf-8').write('\n'.join(toolchain(src, inner)) + '\n')
    print(f'build: exit {code}', flush=True)
    header = ''.join(open(os.path.join(out, 'build.log'), encoding='utf-8').read().split('--- clone')[0])
    pkgdir = os.path.join(src, r['packages'])
    found = {f.lower(): os.path.join(pkgdir, f) for f in os.listdir(pkgdir)} if os.path.isdir(pkgdir) else {}
    open(os.path.join(out, 'packages-produced.txt'), 'w', encoding='utf-8').write('\n'.join(sorted(found)) + '\n')
    summary_all = []
    dl_log = open(os.path.join(out, 'downloads.log'), 'a', encoding='utf-8')
    for p in r['products']:
        pid, ver, ships = p['package'], p['version'], p['ships']
        lid, lver = pid.lower(), ver.lower()
        d = os.path.join(out, f'{pid}-{ver}')
        os.makedirs(os.path.join(d, 'A')); os.makedirs(os.path.join(d, 'nuget-org'))
        open(os.path.join(d, 'A', 'build.log'), 'w', encoding='utf-8').write(
            header + f'--- build: the repository build, see ../../build.log\nbuild exit code {code}\n')
        assets = os.path.join(src, os.path.dirname(p.get('project', '')), 'obj', 'project.assets.json')
        if p.get('project') and os.path.exists(assets):   # the resolved dependencies, for the record (rule R5)
            shutil.copy(assets, os.path.join(d, 'project.assets.json'))
        got = []
        for kind in ('nupkg', 'snupkg'):
            f = found.get(f'{lid}.{lver}.{kind}')
            if f:
                shutil.copy(f, os.path.join(d, 'A', f'{lid}.{lver}.{kind}')); got.append(kind)   # lower-case name: the comparison looks for it so
        if 'nupkg' not in got:   # packed under another version: copied too, so the DLL is still compared (run-batch's fallback)
            others = [k for k in found if k.startswith(lid + '.') and k.endswith('.nupkg') and re.fullmatch(rf'{re.escape(lid)}\.\d[^/]*\.nupkg', k)]
            for k in others[:1]:
                shutil.copy(found[k], os.path.join(d, 'A', k))
        fetch(f'https://api.nuget.org/v3-flatcontainer/{lid}/{lver}/{lid}.{lver}.nupkg', os.path.join(d, 'nuget-org', f'{lid}.{lver}.nupkg'), dl_log)
        summary = [f'{pid} {ver}: builds A exit {code}']
        a, ref = os.path.join(d, 'A', f'{lid}.{lver}.nupkg'), os.path.join(d, 'nuget-org', f'{lid}.{lver}.nupkg')
        if 'nupkg' in got and os.path.exists(ref):
            with open(os.path.join(d, 'compare-nupkg.txt'), 'w', encoding='utf-8') as f:
                subprocess.run([sys.executable, '-I', os.path.join(HERE, 'compare.py'), ships, ref, a], stdout=f)
            same = subprocess.run([sys.executable, '-I', os.path.join(HERE, 'compare.py'), ships, ref, a], stdout=subprocess.DEVNULL).returncode == 0
            summary.append(f'nupkg: {ships} A vs nuget.org: {"identical" if same else "differs"}')
        else:
            summary.append('nupkg: not compared, ' + (f'{lid}.{lver}.nupkg not produced by the repository build' + (f' (produced: {", ".join(sorted(k for k in found if k.startswith(lid + ".")))})' if any(k.startswith(lid + '.') for k in found) else '') if 'nupkg' not in got else 'nuget.org download failed'))
        summary.append(f'end {now()}')
        open(os.path.join(d, 'summary.txt'), 'w', encoding='utf-8').write('\n'.join(summary) + '\n')
        summary_all.append(summary[1])
        print(f'{pid} {ver}: {summary[1]}', flush=True)
    open(os.path.join(out, 'summary.txt'), 'w', encoding='utf-8').write(
        f'{r["name"]}: build exit {code}, {len(r["products"])} products\n' + '\n'.join(summary_all) + f'\nend {now()}\n')


if __name__ == '__main__':
    main()
