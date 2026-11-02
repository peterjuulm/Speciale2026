"""Determinism experiment, Benedetti style: one fixed SDK, reprotest's
variations, our own builds on both sides of every comparison.

Plan: notes/2026-10-28-determinism-plan.md. Linux only.

    python3 -I determinism.py prepare RECIPE LAB           clone at the commit, fix global.json, restore (online, once)
    python3 -I determinism.py screen  RECIPE LAB           one plain pack: does the project build under the fixed SDK?
    python3 -I determinism.py run     RECIPE LAB MODE AXES reprotest; MODE asis|configured; AXES all | axis[,axis...] | each
    python3 -I determinism.py batch   RECIPEDIR LAB STEP   every recipe in RECIPEDIR, in sequence, resumable
    python3 -I determinism.py classify LAB OUT.tsv         one row per (package, mode, axes) with the three boundaries
    python3 -I determinism.py environment LAB              environment.txt: host, SDK, tools
    python3 -I determinism.py recompare LAB                recompute every verdict from the stored packages

LAB/sdk holds the one SDK (install-sdk.py 10.0.403 LAB/sdk), LAB/nuget the one
package cache, LAB/src/<id> the clones, LAB/out/<id> everything measured.

A build is `dotnet pack PROJECT -c Release --no-restore -o out`, nothing from
the recipe's own build line: the experiment builds as the ecosystem's default
command does, not as the publisher did. The configured mode adds
ContinuousIntegrationBuild, Deterministic and DeterministicTimestamp (the
commit time). Comparison boundaries, from the artifacts reprotest stores:
1 the whole .nupkg; 2 every entry but the packaging files; 3 the DLLs under
lib/, ref/ and runtimes/.
"""
import datetime, hashlib, io, json, os, re, shutil, subprocess, sys, tomllib, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rebuild

AXES = ['build_path', 'environment', 'locales', 'exec_path', 'time', 'timezone', 'umask', 'fileordering']
PACKAGING = ('package/services/metadata/core-properties/', '_rels/.rels', '[Content_Types].xml')
REPROTEST = shutil.which('reprotest') or os.path.expanduser('~/.local/bin/reprotest')


def now():
    return datetime.datetime.now().astimezone().isoformat(timespec='seconds')


def load(recipe_path):
    with open(recipe_path, 'rb') as f:
        r = tomllib.load(f)
    r['id'] = f'{r["package"].lower()}-{r["version"].lower()}'
    return r


def paths(r, lab):
    lab = os.path.abspath(lab)
    return dict(lab=lab, sdk=os.path.join(lab, 'sdk'), nuget=os.path.join(lab, 'nuget'),
                clihome=os.path.join(lab, 'clihome'), src=os.path.join(lab, 'src', r['id']),
                out=os.path.join(lab, 'out', r['id']))


def build_env(p, r):
    # NUGET_PACKAGES with a trailing slash: Source Link's SourceRoot check rejects a package root without one
    # when a project maps the package folder itself (ExCSS, 1/11)
    env = dict(os.environ, PATH=f'{p["sdk"]}:{p["lab"]}/tools:{os.environ["PATH"]}', DOTNET_ROOT=p['sdk'],
               DOTNET_CLI_HOME=p['clihome'], NUGET_PACKAGES=p['nuget'] + '/', DOTNET_CLI_TELEMETRY_OPTOUT='1',
               DOTNET_NOLOGO='1', DOTNET_SKIP_FIRST_TIME_EXPERIENCE='1', NuGetAudit='false',
               NUPKG_GIT_MIRRORS=os.path.join(p['lab'], 'mirrors'))
    env.update({k: str(v).replace('{src}', p['src']) for k, v in r.get('env', {}).items()})
    return env


def pack_props(mode, commit_time):
    props = '-p:UseSharedCompilation=false'
    if mode == 'configured':
        props += f' -p:ContinuousIntegrationBuild=true -p:Deterministic=true -p:DeterministicTimestamp={commit_time}'
    return props


def pack_cmd(r, mode, commit_time):
    """Build, then pack what was built: `dotnet pack` alone trips over GeneratePackageOnBuild in
    multi-targeting projects (NU5026, GuardClauses in the pilot), and the two-step form packs the same bytes."""
    props = pack_props(mode, commit_time)
    return (f'dotnet build {r["project"]} -c Release --no-restore {props} && '
            f'dotnet pack {r["project"]} -c Release --no-build -o out {props}')


def state(p):
    f = os.path.join(p['out'], 'state.json')
    return json.load(open(f)) if os.path.exists(f) else {}


def save_state(p, s):
    os.makedirs(p['out'], exist_ok=True)
    json.dump(s, open(os.path.join(p['out'], 'state.json'), 'w'), indent=1)


def clone(r, p, env, log):
    """A working tree of the commit whose objects are the mirror's (`git clone --shared`): no copy of the
    repository per package. The first full clones filled the disk (106 GB for 60 packages, 1/11 11:00)."""
    mirror = os.path.join(p['lab'], 'mirrors', re.sub(r'[^A-Za-z0-9._-]+', '_', r['repo']) + '.git')
    if not os.path.isdir(mirror):
        os.makedirs(os.path.dirname(mirror), exist_ok=True)
        rebuild.must(log, ['git', 'clone', '-q', '--mirror', r['repo'], mirror], env)
    elif subprocess.run(['git', '-C', mirror, 'cat-file', '-e', f'{r["commit"]}^{{tree}}'], capture_output=True).returncode:
        # the commit or its tree is not in the mirror: refresh it, and ask for the commit itself (it may be on no branch)
        rebuild.run(log, ['git', '-C', mirror, 'fetch', '-q', '--prune', 'origin'], env)
        rebuild.run(log, ['git', '-C', mirror, 'fetch', '-q', 'origin', r['commit']], env)
    if subprocess.run(['git', '-C', mirror, 'cat-file', '-e', f'{r["commit"]}^{{tree}}'], capture_output=True).returncode:
        raise RuntimeError(f'commit {r["commit"]} is not in {r["repo"]} (not on any branch or tag, and not served on request)')
    shutil.rmtree(p['src'], ignore_errors=True)
    rebuild.must(log, ['git', 'clone', '-q', '--shared', '--no-checkout', mirror, p['src']], env)
    rebuild.must(log, ['git', '-C', p['src'], 'config', 'core.autocrlf', 'false'], env)
    # origin names the real repository, as a developer's clone would: Arcade and Source Link read RepositoryUrl
    # from it ("RepositoryUrl must be specified", EFCore.Design 1/11 11:06, with the mirror path as origin)
    rebuild.must(log, ['git', '-C', p['src'], 'remote', 'set-url', 'origin', r['repo']], env)
    rebuild.must(log, ['git', '-C', p['src'], '-c', 'advice.detachedHead=false', 'checkout', '-q', r['commit']], env)
    if os.path.exists(os.path.join(p['src'], '.gitmodules')):   # SixLabors keeps its build props in a submodule (1/11)
        rebuild.must(log, ['git', '-C', p['src'], 'submodule', 'update', '--init', '--recursive', '-q'], env)


def prepare(r, lab):
    p = paths(r, lab)
    s = state(p)
    if 'recipe' not in s:
        s['recipe'] = {k: r[k] for k in ('package', 'version', 'repo', 'commit', 'project')}
        save_state(p, s)
    if s.get('prepared') and os.path.isdir(os.path.join(p['src'], '.git')):
        return s
    for d in (p['nuget'], p['clihome'], p['out']):
        os.makedirs(d, exist_ok=True)
    env = build_env(p, r)
    with open(os.path.join(p['out'], 'prepare.log'), 'a', encoding='utf-8') as log:
        log.write(f'start {now()}\n')
        try:
            clone(r, p, env, log)
        except RuntimeError as e:   # the source cannot be had: a screen result of its own, not a driver error
            s.update(screen='clone failed', screen_error=str(e)[:300], global_json='', nupkgs=[])
            log.write(f'clone failed: {e}\n')
            save_state(p, s)
            return s
        s['commit_time'] = subprocess.run(['git', '-C', p['src'], 'log', '-1', '--format=%ct'],
                                          capture_output=True, text=True).stdout.strip()
        s['global_json'] = fix_global_json(p['src'])
        log.write(f'global.json: {s["global_json"]}\n')
        s['prepared'] = now()
        if 'screen' in s:   # a clone made again for a later pass: restore it, as the screen left it
            restore(r, p, env, log)
    save_state(p, s)
    return s


def drop_src(r, lab):
    shutil.rmtree(paths(r, lab)['src'], ignore_errors=True)


def fix_global_json(src):
    """global.json: keep msbuild-sdks (Arcade in tree), drop the sdk pin the fixed SDK cannot satisfy.
    Applied after every checkout, since `git checkout -- .` puts the file back (1/11, Azure SDK)."""
    gj = os.path.join(src, 'global.json')
    if not os.path.exists(gj):
        return 'none'
    try:
        g = json.load(open(gj, encoding='utf-8-sig'))
    except ValueError:
        return 'kept (unreadable)'
    if 'sdk' not in g:
        return 'kept'
    pinned = g['sdk'].get('version', '?')
    del g['sdk']
    if g:
        json.dump(g, open(gj, 'w'), indent=2)
    else:
        os.remove(gj)
    return f'sdk-removed (pinned {pinned})'


def restore(r, p, env, log):
    """Fill the cache, then leave the tree clean but restored: obj/ holds only restore output."""
    rebuild.must(log, ['git', '-C', p['src'], 'clean', '-xdfq'], env)
    rebuild.run(log, ['git', '-C', p['src'], 'checkout', '-q', '--', '.'], env)
    fix_global_json(p['src'])
    code = rebuild.run(log, ['dotnet', 'restore', r['project'], '-p:UseSharedCompilation=false'], env, p['src'])
    rebuild.run(log, ['dotnet', 'build-server', 'shutdown'], env, p['src'])
    return code


def first_error(text):
    for line in text.splitlines():
        if re.search(r'error [A-Z]*\d*\s*:|fatal:|Unhandled exception|command not found', line):
            return line.strip()[:300]
    return ''


def screen(r, lab):
    p = paths(r, lab)
    s = prepare(r, lab)
    if 'screen' in s:
        return s
    env = build_env(p, r)
    t0 = datetime.datetime.now()
    with open(os.path.join(p['out'], 'screen.log'), 'w', encoding='utf-8') as log:
        log.write(f'start {now()}\n')
        if restore(r, p, env, log):
            s['screen'] = 'restore failed'
        else:
            code = rebuild.run(log, ['bash', '-c', pack_cmd(r, 'asis', s['commit_time'])], env, p['src'])
            rebuild.run(log, ['dotnet', 'build-server', 'shutdown'], env, p['src'])
            outdir = os.path.join(p['src'], 'out')
            nupkgs = sorted(f for f in os.listdir(outdir)) if os.path.isdir(outdir) else []
            s['nupkgs'] = [n for n in nupkgs if n.endswith('.nupkg') and not n.endswith('.symbols.nupkg')]
            s['screen'] = 'built' if code == 0 and s['nupkgs'] else f'pack failed (exit {code})' if code else 'no package'
        log.write(f'end {now()} {s["screen"]}\n')
    s['screen_seconds'] = round((datetime.datetime.now() - t0).total_seconds())
    s['screen_error'] = first_error(open(os.path.join(p['out'], 'screen.log'), encoding='utf-8', errors='replace').read()) if s['screen'] != 'built' else ''
    # back to clean-and-restored, so every reprotest build compiles from scratch
    with open(os.path.join(p['out'], 'screen.log'), 'a', encoding='utf-8') as log:
        restore(r, p, env, log)
    save_state(p, s)
    return s


def run(r, lab, mode, axes):
    """reprotest with the given axes applied together; store both builds' out/ for the comparison."""
    p = paths(r, lab)
    s = screen(r, lab)
    if s['screen'] != 'built':
        return s
    name = 'all' if axes == AXES else '+'.join(axes)
    key = f'{mode}:{name}'
    if key not in s.get('runs', {}):
        s = prepare(r, lab)   # the clone may have been dropped after an earlier pass
    if key in s.get('runs', {}):
        return s
    env = build_env(p, r)
    pre = (f'export PATH={p["sdk"]}:{p["lab"]}/tools:$PATH DOTNET_ROOT={p["sdk"]} DOTNET_CLI_HOME={p["clihome"]} '
           f'NUGET_PACKAGES={p["nuget"]}/ DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 NuGetAudit=false'
           + ''.join(f' {k}={str(v).replace("{src}", ".")!r}' for k, v in r.get('env', {}).items()))
    cmd = f'{pre} && rm -rf out && {pack_cmd(r, mode, s["commit_time"])}; rc=$?; dotnet build-server shutdown >/dev/null 2>&1; exit $rc'
    store = os.path.join(p['out'], f'{mode}-{name}-store')
    shutil.rmtree(store, ignore_errors=True)
    log_path = os.path.join(p['out'], f'{mode}-{name}.log')
    with open(log_path, 'w', encoding='utf-8') as log:
        log.write(f'start {now()}\n$ {cmd}\n')
        log.flush()
        rc = subprocess.run([REPROTEST, '--no-diffoscope', '--store-dir', store,
                             f'--vary=-all,{",".join("+" + a for a in axes)}', '-c', cmd, p['src'], 'out'],
                            stdout=log, stderr=subprocess.STDOUT, env=env).returncode
        log.write(f'end {now()} exit {rc}\n')
    verdict = compare_store(store, s['nupkgs'], r['package'])
    verdict['reprotest_exit'] = rc
    if rc not in (0, 1):
        verdict['note'] = first_error(open(log_path, encoding='utf-8', errors='replace').read()) or f'reprotest exit {rc}'
    s.setdefault('runs', {})[key] = verdict
    save_state(p, s)
    # the stores hold two full out/ folders per run; keep the nupkgs only
    for d in os.listdir(store):
        for root, _, files in os.walk(os.path.join(store, d)):
            for f in files:
                if not f.endswith(('.nupkg', '.snupkg')):   # the symbol package too: a PDB checksum difference needs it (Quartz, 1/11)
                    os.remove(os.path.join(root, f))
    return s


def entries(nupkg):
    with zipfile.ZipFile(nupkg) as z:
        return {i.filename: hashlib.sha256(z.read(i)).hexdigest() for i in z.infolist()}


def is_packaging(name):
    return name.startswith(PACKAGING[0]) or name in PACKAGING[1:]


def is_binary(name):
    return name.split('/')[0] in ('lib', 'ref', 'runtimes') and name.endswith(('.dll', '.exe'))


def package_files(folder, package_id):
    """The .nupkg files of PACKAGE_ID under FOLDER, by name: the version may differ between two builds
    when the build puts the clock into it (IdentityModel 8.23.0, 1/11), so the id, not the file name, pairs them.
    When the project packs under another id than the recipe names (Humanizer.Core's project packs `Humanizer`,
    1/11), every package the build produced is taken instead; the verdict's note says so."""
    pat = re.compile(r'^' + re.escape(package_id) + r'\.\d.*\.nupkg$', re.IGNORECASE)
    out, every = [], []
    for root, _, files in os.walk(folder):
        for f in files:
            if f.endswith('.nupkg') and not f.endswith('.symbols.nupkg'):
                every.append(os.path.join(root, f))
                if pat.match(f):
                    out.append(os.path.join(root, f))
    return sorted(out) or sorted(every)


def compare_store(store, nupkgs, package_id):
    """Boundaries 1 to 3 between reprotest's control build and its experiment build."""
    dirs = sorted(os.listdir(store)) if os.path.isdir(store) else []
    sides = [package_files(os.path.join(store, d), package_id) for d in dirs if d in ('control', 'experiment-1')]
    if len(sides) < 2 or not sides[0] or not sides[1]:
        have = sum(1 for x in sides if x)
        return dict(b1='failed', b2='failed', b3='failed', first='',
                    note=f'a build under the variation produced no package ({have} of 2 builds have one)')
    fa, fb = sides[0][0], sides[1][0]
    v = dict(b1='same', b2='same', b3='same', first='', note='')
    if not os.path.basename(fa).lower().startswith(package_id.lower() + '.'):
        v['note'] = f'the project packs {os.path.basename(fa)}, not {package_id}: that package is compared'
    if os.path.basename(fa) != os.path.basename(fb):
        v.update(b1='differs', first=f'file name differs: {os.path.basename(fa)} vs {os.path.basename(fb)}')
    for n in [os.path.basename(fa)]:
        a, b = {n: fa}, {n: fb}
        if hashlib.sha256(open(a[n], 'rb').read()).digest() != hashlib.sha256(open(b[n], 'rb').read()).digest():
            v['b1'] = 'differs'
        ea, eb = entries(a[n]), entries(b[n])
        if v['b1'] == 'differs' and not v['first']:
            v['first'] = 'entry timestamps only' if ea == eb else 'packaging files only'
        for e in sorted(set(ea) | set(eb)):
            if ea.get(e) == eb.get(e):
                continue
            if is_packaging(e):
                continue
            if v['b2'] == 'same':
                v['b2'] = 'differs'
                v['first'] = f'{n}:{e}'
            if is_binary(e):
                v['b3'] = 'differs'
                v['first'] = f'{n}:{e}'
    return v


def recipes_in(d):
    return sorted(os.path.join(d, f) for f in os.listdir(d) if f.endswith('.toml'))


def batch(recipedir, lab, step):
    """STEP: pass-a (screen + all axes at once) | pass-b (per axis, configured for what differed) | screen | asis-all | asis-each | configured-each.
    One recipe at a time; a recipe with its result recorded is skipped; pass-a and pass-b drop the clone after the package."""
    lab = os.path.abspath(lab)
    os.makedirs(lab, exist_ok=True)
    runlog = open(os.path.join(lab, 'run.log'), 'a', encoding='utf-8')
    order = recipes_in(recipedir)
    if step != 'screen':   # quick packages first, so a long step reaches as many as the night allows
        order.sort(key=lambda path: state(paths(load(path), lab)).get('screen_seconds', 0))
    excluded = {}
    ex = os.path.join(recipedir, 'excluded.tsv')
    if os.path.exists(ex):
        for line in open(ex, encoding='utf-8'):
            if line.strip() and not line.startswith('#'):
                pid, reason = line.rstrip('\n').split('\t', 1)
                excluded[pid] = reason
    for path in order:
        r = load(path)
        t0 = now()
        try:
            if r['id'] in excluded:
                p = paths(r, lab)
                s = state(p)
                if 'screen' not in s:
                    s.update(recipe={k: r[k] for k in ('package', 'version', 'repo', 'commit', 'project')},
                             screen='excluded', screen_error=excluded[r['id']], global_json='', nupkgs=[])
                    save_state(p, s)
                line = f'excluded: {excluded[r["id"]]}'
            elif step == 'screen':
                s = screen(r, lab)
                line = s['screen']
            elif step == 'pass-a':   # screen + all axes at once, then the clone goes
                s = run(r, lab, 'asis', AXES)
                drop_src(r, lab)
                line = fmt(s, 'asis:all') if s.get('screen') == 'built' else s.get('screen', '?')
            elif step == 'pass-b':   # per axis as is, configured for what differed, then the clone goes
                s = screen(r, lab)
                if s.get('screen') == 'built':
                    for a in AXES:
                        s = run(r, lab, 'asis', [a])
                    done = []
                    # Configured runs: every axis where the content or a DLL differed, or the build failed; of the axes
                    # where only the whole-file hash differed (entry timestamps), one representative, `time`, since the
                    # timestamp fix does not depend on the axis (decided 1/11 14:50 for the run's cost; the others can be
                    # added later with the same command).
                    for a in AXES:
                        v = s.get('runs', {}).get(f'asis:{a}')
                        if not v:
                            continue
                        content = 'differs' in (v['b2'], v['b3']) or v['b1'] == 'failed'
                        if content or (a == 'time' and v['b1'] == 'differs'):
                            s = run(r, lab, 'configured', [a])
                            done.append(f'{a} {fmt(s, "configured:" + a)}')
                    line = '; '.join(f'{a} {fmt(s, "asis:" + a)}' for a in AXES) + ' || configured: ' + ('; '.join(done) or 'nothing differed')
                else:
                    line = s.get('screen', '?')
                drop_src(r, lab)
            elif step == 'asis-all':
                s = run(r, lab, 'asis', AXES)
                line = fmt(s, 'asis:all')
            elif step == 'asis-each':
                s = screen(r, lab)
                for a in AXES:
                    s = run(r, lab, 'asis', [a])
                line = '; '.join(f'{a} {fmt(s, "asis:" + a)}' for a in AXES)
            elif step == 'configured-each':
                s = screen(r, lab)
                done = []
                for a in AXES:
                    v = s.get('runs', {}).get(f'asis:{a}')
                    if v and ('differs' in (v['b1'], v['b2'], v['b3']) or v['b1'] == 'failed'):
                        s = run(r, lab, 'configured', [a])
                        done.append(f'{a} {fmt(s, "configured:" + a)}')
                line = '; '.join(done) or 'nothing differed as is'
            else:
                sys.exit(f'unknown step {step}')
        except Exception as e:   # one package's failure must not stop the batch
            line = f'ERROR {e}'
        runlog.write(f'{t0} .. {now()} {r["id"]} {step}: {line}\n')
        runlog.flush()
        print(f'{r["id"]} {step}: {line}', flush=True)


def fmt(s, key):
    v = s.get('runs', {}).get(key)
    if not v:
        return s.get('screen', '?')
    return f'b1={v["b1"] or "-"} b2={v["b2"] or "-"} b3={v["b3"] or "-"}' + (f' ({v["first"]})' if v['first'] else '') + (f' [{v["note"]}]' if v.get('note') else '')


def classify(lab, out_tsv):
    cols = ['package', 'version', 'repo', 'commit', 'project', 'global_json', 'screen', 'screen_error',
            'mode', 'axes', 'b1', 'b2', 'b3', 'first_difference', 'note']
    rows = []
    outdir = os.path.join(lab, 'out')
    for pid in sorted(os.listdir(outdir)):
        f = os.path.join(outdir, pid, 'state.json')
        if not os.path.exists(f):
            continue
        s = json.load(open(f))
        rec = s.get('recipe', {})
        base = [rec.get('package', pid), rec.get('version', ''), rec.get('repo', ''), rec.get('commit', ''),
                rec.get('project', ''), s.get('global_json', ''), s.get('screen', ''), s.get('screen_error', '')]
        runs = s.get('runs', {})
        if not runs:
            rows.append(base + ['', '', '', '', '', '', ''])
        for key in sorted(runs):
            mode, axes = key.split(':', 1)
            v = runs[key]
            rows.append(base + [mode, axes, v['b1'], v['b2'], v['b3'], v['first'], v.get('note', '')])
    with open(out_tsv, 'w', encoding='utf-8') as f:
        f.write('\t'.join(cols) + '\n')
        for row in rows:
            f.write('\t'.join(str(c).replace('\t', ' ') for c in row) + '\n')
    print(f'{len(rows)} rows -> {out_tsv}')


def recompare(lab):
    """Recompute every stored run's verdict from its stored packages (after a change to the comparison)."""
    outdir = os.path.join(lab, 'out')
    for pid in sorted(os.listdir(outdir)):
        f = os.path.join(outdir, pid, 'state.json')
        if not os.path.exists(f):
            continue
        s = json.load(open(f))
        for key, old in s.get('runs', {}).items():
            mode, name = key.split(':', 1)
            store = os.path.join(outdir, pid, f'{mode}-{name}-store')
            v = compare_store(store, s.get('nupkgs', []), s['recipe']['package'])
            v['reprotest_exit'] = old.get('reprotest_exit')
            if old.get('note') and not v.get('note') and v['b1'] == 'failed':
                v['note'] = old['note']   # keep the first error line of a failed run; a complete verdict needs no old note
            s['runs'][key] = v
        json.dump(s, open(f, 'w'), indent=1)
        print(pid, '; '.join(f'{k} {fmt(s, k)}' for k in s.get('runs', {})))


def environment(lab):
    sdk = os.path.join(lab, 'sdk')
    def sh(cmd):
        return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()
    lines = [f'recorded {now()}', f'host {sh("uname -a")}', f'glibc {sh("ldd --version | head -1")}',
             f'sdk {sh(f"{sdk}/dotnet --version")} at {sdk}',
             f'nuget {sh(f"{sdk}/dotnet nuget --version | tail -1")}',
             'sdk tarball ' + sh(f'grep sha512 {lab}/install-sdk.log'),
             f'reprotest {sh("reprotest --version 2>&1 | head -1")} at {REPROTEST}',
             f'disorderfs {sh("disorderfs --version 2>&1 | head -1")}',
             f'faketime {sh("faketime -v 2>&1 | grep -i version")}',
             f'pwsh {sh(f"{lab}/tools/pwsh -NoProfile -Command \'$PSVersionTable.PSVersion.ToString()\' 2>/dev/null")} at {lab}/tools (dotnet tool PowerShell; the Azure SDK build gate runs a PowerShell script)',
             'locales ' + ','.join(sh('locale -a').split()),
             f'axes {",".join(AXES)}', '', 'pacman -Q', sh('pacman -Q')]
    open(os.path.join(lab, 'environment.txt'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    print('\n'.join(lines[:10]))


def main():
    cmd = sys.argv[1]
    if cmd == 'batch':
        batch(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == 'classify':
        classify(os.path.abspath(sys.argv[2]), sys.argv[3])
    elif cmd == 'environment':
        environment(os.path.abspath(sys.argv[2]))
    elif cmd == 'recompare':
        recompare(os.path.abspath(sys.argv[2]))
    else:
        r = load(sys.argv[2])
        lab = sys.argv[3]
        p = paths(r, lab)
        s = state(p)
        if cmd == 'prepare':
            s = prepare(r, lab)
        elif cmd == 'screen':
            s = screen(r, lab)
        elif cmd == 'run':
            mode, axes = sys.argv[4], sys.argv[5]
            if axes == 'all':
                s = run(r, lab, mode, AXES)
            elif axes == 'each':
                for a in AXES:
                    s = run(r, lab, mode, [a])
            else:
                s = run(r, lab, mode, axes.split(','))
        print(json.dumps({k: v for k, v in s.items() if k != 'recipe'}, indent=1))


if __name__ == '__main__':
    main()
