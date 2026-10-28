"""Derive repository-build recipes: one per repository and commit, for the packages in a list.

Usage: python3 -I derive-repo.py LIST CENSUS_FILES_CSV FACTS_DIR LAB OUT [--vmr-identity | --v2 | --v3 | --v4 | --v5]

--vmr-identity is version 2 of the method (28 October, written after build 4 of version 1): only the VMR's
inner repositories are derived, and each gets the two identity properties the VMR orchestration passes and
the shipped DLLs show: RepositoryUrl=https://github.com/dotnet/dotnet (the DLL's RepositoryUrl attribute)
and RepoOriginalSourceRevisionId from src/source-manifest.json at the commit (the DLL's
OriginalRepoCommitHash attribute). Version 1 recipes stay as they were.

The repository-build method (dependencies/notes/2026-10-27-nupkg-repository-build-plan.md)
builds a whole repository with its own build script and takes every listed package from
that one build. This script reads, per package: the repository, the commit and the shipped
DLL (from the release-only facts in FACTS_DIR when they exist, else from the nupkg's
.nuspec and the census), and the DLL's AssemblyFileVersionAttribute (from the release-only
report when it exists, else from the nupkg via dllreport). It decodes Arcade's official
build id from the file version (rule R4), finds each package's project in the repository's
mirror (git ls-tree, the release-only rule 7: a .csproj named like the package id, not under
ref/), and groups the packages by repository, commit and inner repository (for the VMR, the
src/<name>/ that holds the project) into OUT/<repo>-<inner>-<commit7>.toml, with facts.txt
and a [[products]] list. Packages the method does not cover (runtime packs, SkiaSharp) are
written to OUT/not-covered.txt with the reason.

LIST lines are "Package Version"; '#' starts a comment. LAB holds the mirrors (LAB/mirrors)
and downloaded nupkgs (LAB/nupkg).
"""
import os, re, subprocess, sys, zipfile, urllib.request, shutil, collections

HERE = os.path.dirname(os.path.abspath(__file__))
REPORT_DOTNET = os.environ.get('DLLREPORT_DOTNET', '/private/tmp/rb1-dotnet10/sdk/dotnet')
INNER_KINDS = {'runtime': 'runtime', 'aspnetcore': 'aspnetcore', 'efcore': 'arcade', 'roslyn': 'roslyn',
               'msbuild': 'arcade', 'symreader': 'arcade', 'reverse-proxy': 'arcade'}
NOT_COVERED = {
    'Microsoft.NETCore.App.Runtime.linux-x64': 'a runtime pack: needs the full product build (clr+libs+host), rule R8',
    'Microsoft.AspNetCore.App.Runtime.linux-x64': 'a runtime pack: needs the full product build, rule R8',
}


def sh(args, **kw):
    return subprocess.run(args, capture_output=True, text=True, **kw)


def mirror_of(url, lab):
    m = os.path.join(lab, 'mirrors', re.sub(r'[^A-Za-z0-9._-]+', '_', url) + '.git')
    if os.path.isdir(m) and not sh(['git', '-C', m, 'for-each-ref', '--count=1']).stdout.strip():
        shutil.rmtree(m, ignore_errors=True)   # a fetch that was interrupted: no refs yet
    if not os.path.isdir(m):
        # a mirror of the branches and tags only: `git clone --mirror` would also take GitHub's refs/pull/*,
        # which for dotnet/runtime is several GB of pull-request history the build never needs
        os.makedirs(os.path.dirname(m), exist_ok=True)
        subprocess.run(['git', 'init', '-q', '--bare', m], check=True)
        subprocess.run(['git', '-C', m, 'remote', 'add', 'origin', url], check=True)
        subprocess.run(['git', '-C', m, 'config', '--replace-all', 'remote.origin.fetch', '+refs/heads/*:refs/heads/*'], check=True)
        subprocess.run(['git', '-C', m, 'config', '--add', 'remote.origin.fetch', '+refs/tags/*:refs/tags/*'], check=True)
        subprocess.run(['git', '-C', m, 'config', 'remote.origin.mirror', 'true'], check=True)
        # a stalled connection aborts after 120 s under 1 KB/s instead of hanging (27/10: one hung for six hours)
        for attempt in range(3):
            if subprocess.run(['git', '-C', m, '-c', 'http.lowSpeedLimit=1000', '-c', 'http.lowSpeedTime=120', 'fetch', '-q', '--prune', 'origin']).returncode == 0:
                break
            print(f'mirror of {url}: fetch failed (attempt {attempt + 1})', flush=True)
        else:
            shutil.rmtree(m, ignore_errors=True)
            raise RuntimeError(f'mirror of {url} failed three times')
    return m


def tree(mirror, commit):
    r = sh(['git', '-C', mirror, 'ls-tree', '-r', '--name-only', commit])
    if r.returncode:   # the commit may be missing from the mirror: fetch it
        subprocess.run(['git', '-C', mirror, 'fetch', '-q', 'origin', commit], check=False)
        r = sh(['git', '-C', mirror, 'ls-tree', '-r', '--name-only', commit])
    return r.stdout.split('\n') if r.returncode == 0 else None


def decode_build_id(filever, pkgver, vmr, year_hint):
    """Arcade's scheme (Versioning.md): FILE_PATCH = (PATCH mod 100)*100 + yy; FILE_REVISION = (50*mm+dd)*100 + r,
    with r up to 199 (CalculateAssemblyAndFileVersions.cs). The VMR adds 100 to the revision before it reaches the
    inner repository (repo-projects/Directory.Build.props), so for a VMR product the same FILE_REVISION reads as
    day d, revision r (a plain official build) or day d-1, revision r+100 (the VMR). Both give the same file version;
    the VMR reading is passed, because the inner build is run without the VMR's +100. Where FILE_PATCH does not fit
    the scheme the year is lost (msbuild sets its own patch), and year_hint (the nuget.org publish year) is used."""
    parts = filever.split('.')
    if len(parts) != 4 or not all(p.isdigit() for p in parts):
        return None, f'file version {filever} is not four numbers'
    fp, fr = int(parts[2]), int(parts[3])
    r = fr % 100
    md = fr // 100
    mm, dd = md // 50, md % 50
    if not (1 <= mm <= 12 and 1 <= dd <= 32):
        return None, f'file version {filever}: revision part {fr} does not decode to a date'
    m = re.match(r'^(\d+)\.(\d+)\.(\d+)', pkgver)
    patch = int(m.group(3)) if m else None
    fits = patch is not None and fp // 100 == patch % 100
    yy = fp % 100 if fits else (year_hint % 100 if year_hint else None)
    if yy is None:
        return None, f'file version {filever}: FILE_PATCH {fp} does not fit the Arcade scheme for patch {patch}, and no publish year is known'
    how = (f'FILE_PATCH {fp} = (patch {patch} mod 100)*100 + yy {yy}' if fits
           else f'FILE_PATCH {fp} does not fit the Arcade scheme for patch {patch} (the repository sets its own); year {yy} from the nuget.org publish date')
    if vmr:
        if dd < 2:
            return None, f'file version {filever}: day {dd} cannot carry the VMR\'s +100 revision'
        bid = f'20{yy:02d}{mm:02d}{dd - 1:02d}.{r + 100}'
        return bid, f'inferred: {how}; FILE_REVISION {fr} = (50*{mm}+{dd - 1})*100 + {r + 100}, the VMR\'s +100 revision (the plain reading 20{yy:02d}{mm:02d}{dd:02d}.{r} gives the same file version)'
    if dd > 31:
        return None, f'file version {filever}: day {dd} is not a date'
    return f'20{yy:02d}{mm:02d}{dd:02d}.{r}', f'inferred: {how}; FILE_REVISION {fr} = (50*{mm}+{dd})*100 + {r}'


def publish_year(pkg, ver):
    """The year nuget.org lists the version as published, for a file version that lost its year."""
    try:
        import json
        with urllib.request.urlopen(f'https://api.nuget.org/v3/registration5-gz-semver2/{pkg.lower()}/{ver.lower()}.json', timeout=60) as r:
            data = r.read()
        try:
            import gzip; data = gzip.decompress(data)
        except Exception:
            pass
        j = json.loads(data)
        return int(j.get('published', '')[:4])
    except Exception:
        return None


def sdk_major(mirror, commit, root):
    """The major version of the SDK in global.json at the commit, for the environment rule on old SDKs."""
    r = sh(['git', '-C', mirror, 'show', f'{commit}:{root}global.json'])
    m = re.search(r'"version"\s*:\s*"(\d+)\.', r.stdout) if r.returncode == 0 else None
    return int(m.group(1)) if m else None


def report_attr(nupkg, ships, lab, name):
    """Run dllreport on the shipped DLL inside the nupkg; return the report text."""
    d = os.path.join(lab, 'nupkg', 'dll'); os.makedirs(d, exist_ok=True)
    dll = os.path.join(d, name + '.dll')
    open(dll, 'wb').write(zipfile.ZipFile(nupkg).read(ships))
    r = sh([REPORT_DOTNET, 'run', os.path.join(HERE, 'dllreport.cs'), '--', dll])
    return r.stdout


def win_entry(url, commit, lab, flags):
    """The repository's Windows entry script at the commit (build.cmd or Build.cmd) with the flags it does not add itself.

    Arcade's standard build.cmd calls eng/common/build.ps1 with -restore -build already (msbuild: -build -restore;
    Roslyn's Build.cmd adds -build only), and PowerShell refuses a switch given twice (28/10 07:20, reverse-proxy on
    windows-2022: "parameter 'restore' is specified more than once")."""
    mirror = mirror_of(url, lab)
    name = next((f for f in sh(['git', '-C', mirror, 'ls-tree', '--name-only', commit]).stdout.split('\n') if f.lower() == 'build.cmd'), 'build.cmd')
    text = sh(['git', '-C', mirror, 'show', f'{commit}:{name}']).stdout.lower()
    return name + ''.join(f' {f}' for f in flags if f'{f} ' not in text and f'{f}"' not in text and not text.rstrip().endswith(f))


NODE_BY_SDK = {8: '18.20.8', 9: '22.23.4'}   # R3d: the Node LTS line each aspnetcore tree's npm tooling accepts (8.0: <=19; 9.0: engines >=20.9)


def main():
    lst, census, facts_dir, lab, out = sys.argv[1:6]
    v5 = '--v5' in sys.argv[6:]
    v4 = '--v4' in sys.argv[6:]
    v3 = v4 or v5 or '--v3' in sys.argv[6:]
    v2 = v3 or '--v2' in sys.argv[6:]
    vmr_identity = v2 or '--vmr-identity' in sys.argv[6:]
    os.makedirs(out, exist_ok=True)
    cen = {}
    for l in open(census, encoding='utf-8'):
        p = l.rstrip('\n').split(',')
        if len(p) > 2 and p[0] != 'package':
            cen[(p[0], p[1])] = p[2]
    groups = collections.OrderedDict()
    notes = []
    for line in open(lst, encoding='utf-8'):
        line = line.split('#')[0].strip()
        if not line:
            continue
        pkg, ver = line.split()[:2]
        key = f'{pkg}-{ver}'
        if pkg in NOT_COVERED:
            notes.append(f'{key}: not covered: {NOT_COVERED[pkg]}'); continue
        facts = os.path.join(facts_dir, key, 'facts.txt')
        t = open(facts, encoding='utf-8').read() if os.path.exists(facts) else ''
        ships = (re.search(r'^shipped file: (\S+)', t, re.M) or [None, cen.get((pkg, ver))])[1]
        commit = (re.search(r'^commit: ([0-9a-f]{40})', t, re.M) or [None, None])[1]
        url = (re.search(r'^clone url: (\S+)', t, re.M) or [None, None])[1]
        project = (re.search(r'^project: (\S+\.csproj)', t, re.M) or [None, None])[1]
        filever = (re.search(r'^file version: (\S+)', t, re.M) or [None, None])[1]
        src = []
        # the nupkg: needed when the facts lack the commit, the URL or the file version
        lid, lver = pkg.lower(), ver.lower()
        np = os.path.join(lab, 'nupkg', f'{lid}.{lver}.nupkg')
        if not (commit and url and filever):
            if not os.path.exists(np):
                os.makedirs(os.path.dirname(np), exist_ok=True)
                with urllib.request.urlopen(f'https://api.nuget.org/v3-flatcontainer/{lid}/{lver}/{lid}.{lver}.nupkg', timeout=300) as r, open(np, 'wb') as f:
                    shutil.copyfileobj(r, f)
            z = zipfile.ZipFile(np)
            nuspec = next(n for n in z.namelist() if n.endswith('.nuspec') and '/' not in n)
            x = z.read(nuspec).decode('utf-8', 'replace')
            m = re.search(r'<repository[^>]*\burl="([^"]+)"[^>]*\bcommit="([0-9a-f]{40})"', x) or re.search(r'<repository[^>]*\bcommit="([0-9a-f]{40})"[^>]*\burl="([^"]+)"', x)
            if m and not (commit and url):
                a, b = m.group(1), m.group(2)
                url, commit = (a, b) if b and re.fullmatch(r'[0-9a-f]{40}', b) else (b, a)
                url = re.sub(r'\.git$', '', url); src.append('nuspec')
            if not ships:
                ships = next((n for n in z.namelist() if n.lower().startswith('lib/') and n.lower().endswith(f'/{lid}.dll')), None)
            if not filever and ships:
                rep = report_attr(np, ships, lab, key)
                fm = re.search(r'^attribute: AssemblyFileVersionAttribute\(([^)]+)\)$', rep, re.M)
                filever = fm.group(1) if fm else None; src.append('dllreport on the nupkg')
        if not (commit and url and ships):
            notes.append(f'{key}: not derived: missing ' + ', '.join(n for n, v in (('commit', commit), ('url', url), ('shipped file', ships)) if not v)); continue
        if not filever:
            notes.append(f'{key}: not derived: no AssemblyFileVersionAttribute in {ships}'); continue
        mirror = mirror_of(url, lab)
        files = tree(mirror, commit)
        if files is None:
            notes.append(f'{key}: not derived: commit {commit[:9]} not reachable in {url}'); continue
        if not project:
            cands = [f for f in files if f.lower().endswith(f'/{lid}.csproj') and '/ref/' not in f.lower() and '/referencepackages/' not in f.lower() and '/shims/' not in f.lower()]   # runtime's src/libraries/shims/stubs are facades, not the library
            if not cands:
                notes.append(f'{key}: not derived: no {pkg}.csproj in the tree (rule 7)'); continue
            project = sorted(cands, key=len)[0]
        inner = ''
        if url.rstrip('/').endswith('/dotnet/dotnet'):
            inner = '/'.join(project.split('/')[:2])   # src/<name>
        kind_name = inner.split('/')[-1] if inner else url.rstrip('/').split('/')[-1]
        kind = INNER_KINDS.get(kind_name)
        if not kind:
            notes.append(f'{key}: not covered: {url} ({kind_name}) has no repository-build command in rule R3'); continue
        vmr = url.rstrip('/').endswith('/dotnet/dotnet')
        bid, how = decode_build_id(filever, ver, vmr, None)
        if not bid and 'does not fit' in how:
            bid, how = decode_build_id(filever, ver, vmr, publish_year(pkg, ver))
        if not bid:
            notes.append(f'{key}: not derived: {how}'); continue
        g = groups.setdefault((url, commit, inner), {'kind': kind, 'products': [], 'files': files})
        g['products'].append({'package': pkg, 'version': ver, 'ships': ships, 'project': project,
                              'file_version': filever, 'build_id': bid, 'how': how, 'source': ', '.join(src) or 'release-only facts'})
    for (url, commit, inner), g in groups.items():
        name = f'{url.rstrip("/").split("/")[-1]}-{(inner.split("/")[-1] + "-") if inner else ""}{commit[:7]}'
        root = inner + '/' if inner else ''
        ids = collections.Counter(p['build_id'] for p in g['products'])
        facts = [f'{name}: repository build derivation', f'repository: {url}', f'commit: {commit}',
                 f'inner repository: {inner or "none (the repository itself)"}', f'kind: {g["kind"]}']
        for p in g['products']:
            facts.append(f'product {p["package"]} {p["version"]}: ships {p["ships"]}; project {p["project"]}; file version {p["file_version"]} -> {p["build_id"]} [{p["how"]}; from {p["source"]}]')
        if len(ids) > 1:
            notes.append(f'{name}: not derived: its products decode to different build ids {dict(ids)}; one build cannot have two')
            d = os.path.join(out, name); os.makedirs(d, exist_ok=True)
            open(os.path.join(d, 'facts.txt'), 'w', encoding='utf-8').write('\n'.join(facts + [notes[-1]]) + '\n')
            continue
        bid = next(iter(ids))
        facts.append(f'official build id: {bid}  [rule R4]')
        props = f'/p:OfficialBuildId={bid}'
        # R4b: the shipped versions carry no prerelease label, so the build is told it is the release; the
        # Arcade repositories gate DotNetFinalVersionKind=release on StabilizePackageVersion (eng/Versions.props)
        stable = all(not re.search(r'-', p['version']) for p in g['products'])
        if stable:
            if v5 and g['kind'] == 'roslyn':
                # version 5 (28/10 07:50): Roslyn's official pipeline passes -officialBuildId only (azure-pipelines-official.yml at
                # the commit); the shipped assembly keeps the prerelease informational version (5.0.0-2.25567.12+sha, Windows run of
                # version 3) and the package is stabilised by repacking, so the two properties are not the official build's input here
                facts.append('version 5: no StabilizePackageVersion/DotNetFinalVersionKind for Roslyn (the official build passes OfficialBuildId only; the package is repacked to its release version)  [read]')
            else:
                props += ' /p:StabilizePackageVersion=true /p:DotNetFinalVersionKind=release'
            facts.append('release branding: StabilizePackageVersion=true, DotNetFinalVersionKind=release  [read: the shipped versions have no prerelease label; rule R4b]')
        else:
            facts.append('release branding: none passed (a shipped version has a prerelease label)')
        if inner:
            # the VMR forces the SDK's compiler on every inner repository (repo-projects/Directory.Build.targets);
            # the PDB compiler records of the shipped DLLs name the SDK's csc, not Microsoft.Net.Compilers.Toolset's
            props += ' /p:UsingToolMicrosoftNetCompilers=false'
            facts.append('compiler: UsingToolMicrosoftNetCompilers=false  [read: the VMR passes it to every inner build; the PDBs record the SDK\'s csc]')
        if v2:
            # version 2, R5b: an official build (OfficialBuildId set) acquires IBC optimization data from a
            # Microsoft-internal drop through eng/common/internal (msbuild: UsingToolIbcOptimization=true; 27/10 22:29,
            # 401 on the devdiv feed). The documented suppression is EnableNgenOptimization=false. The shipped DLL
            # may carry merged optimization data; that is then what a level 4 with equal IL says.
            props += ' /p:EnableNgenOptimization=false'
            facts.append('version 2, R5b: EnableNgenOptimization=false (the optimization-data step needs a Microsoft-internal drop; its tools restore from a 401 feed)  [rule]')
        if vmr_identity and not v2 and not inner:
            notes.append(f'{name}: not in version 2 (not a VMR inner repository)'); continue
        if vmr_identity and inner:
            import json
            man = json.loads(sh(['git', '-C', mirror_of(url, lab), 'show', f'{commit}:src/source-manifest.json']).stdout)
            orig = next((r['commitSha'] for r in man['repositories'] if r['path'] == inner.split('/')[-1]), None)
            if not orig:
                notes.append(f'{name}: not derived: {inner} not in src/source-manifest.json'); continue
            props += f' /p:RepositoryUrl={url} /p:RepoOriginalSourceRevisionId={orig}'
            facts.append(f'version 2, VMR identity: RepositoryUrl={url} (the DLL\'s RepositoryUrl attribute), RepoOriginalSourceRevisionId={orig} (src/source-manifest.json at the commit; the DLL\'s OriginalRepoCommitHash attribute where the repository emits it)  [read]')
        cd = f'cd {inner} && ' if inner else ''
        if g['kind'] == 'aspnetcore':
            # the shared-framework project is a .csproj up to .NET 9 and a .sfxproj in .NET 10 (docs/BuildErrors.md still says .csproj)
            app = next((f for f in g['files'] if f in (f'{root}src/Framework/App.Runtime/src/Microsoft.AspNetCore.App.Runtime.csproj', f'{root}src/Framework/App.Runtime/src/Microsoft.AspNetCore.App.Runtime.sfxproj')), None)
            # '|| exit 1', not '&&': with '&&' the packs ran after a failed first step (27/10 21:52, aspnetcore-af22eff)
            # Arcade's eng/common/tools.sh exits 0 after "Build failed" in --ci mode (MSBuild-Core: "Exiting with an exit
            # code causes the azure pipelines task to log yet another noise error") and marks the failure with
            # ##vso[task.complete result=Failed;] instead (27/10 23:13, aspnetcore-2aa4015: three failures, exit 0), so
            # each step's output is read for that marker: s() runs a step and fails on it
            wrap = 'L=$(mktemp); s() { "$@" > "$L" 2>&1; c=$?; cat "$L"; grep -q "task.complete result=Failed" "$L" && return 1; return $c; }; '
            first = f's ./eng/build.sh --ci -nobl -c Release --projects "$PWD/{app[len(root):]}" {props} || exit 1; ' if app else ''
            facts.append('shared framework first: ' + (f'yes, {app} (docs/BuildErrors.md)' if first else 'no: App.Runtime project not found under src/Framework/App.Runtime/src'))
            # one --pack call per project: a ';'-joined list loses its quotes in the shell and MSBuild splits it
            packs = ' '.join('"$PWD/' + p['project'][len(root):] + '"' for p in g['products'])
            build = f'{cd}{wrap}{first}ok=0; for p in {packs}; do s ./eng/build.sh --ci -nobl -c Release --pack --projects "$p" {props} || ok=1; done; exit $ok'
            # the same steps for a Windows runner (28/10 07:30): eng/build.cmd, the official entry point, runs
            # eng/build.ps1 under Windows PowerShell; s() reads each step's output for Arcade's failure marker as above
            wrap_w = ("function s { $t = New-TemporaryFile; $a = @($args[1..($args.Count - 1)]); & $args[0] @a 2>&1 | Tee-Object -FilePath $t | Out-Host; "
                      "$c = $LASTEXITCODE; if (Select-String -Quiet -Path $t -Pattern 'task.complete result=Failed') { $c = 1 }; return $c }; ")
            first_w = f'if (s ./eng/build.cmd -ci -nobl -c Release -projects "$PWD/{app[len(root):]}" {props}) {{ exit 1 }}; ' if app else ''
            packs_w = ', '.join('"$PWD/' + p['project'][len(root):] + '"' for p in g['products'])
            win = f'{wrap_w}{first_w}$ok = 0; foreach ($p in @({packs_w})) {{ if (s ./eng/build.cmd -ci -nobl -c Release -pack -projects $p {props}) {{ $ok = 1 }} }}; exit $ok'
        elif g['kind'] == 'runtime' and v3 and not inner:
            # version 3, R3c: the standalone dotnet/runtime commits without the native shims (libs.native), which do
            # not compile with this machine's clang 23 at 9.0.0 (27/10 22:40, eleven C-to-C++ compatibility
            # diagnostics raised as errors) and which the shipped managed packages do not contain; libs.pretest
            # (test assets) is left out too. The subset names are read from eng/Subsets.props at the commit:
            # Libs.Sfx/Libs.Oob exist from .NET 7, .NET 5 and 6 have Libs.Ref/Libs.Src/Libs.Packages instead.
            # The README's /p:BuildNative=false is not consumed by any project file at 9.0.0 (git grep "(BuildNative)").
            subsets_props = sh(['git', '-C', mirror_of(url, lab), 'show', f'{commit}:eng/Subsets.props']).stdout
            # .NET 5 maps libs.packages to libraries-packages.proj (pkgproj); .NET 6 keeps the name without a mapping
            # (packing moved into the source projects); neither has a tools subset, and an unknown subset fails
            # eng/SubsetValidation.targets (second opinion 27/10 23:10, checked in the files)
            if 'SubsetName Include="Libs.Sfx"' in subsets_props:
                subset = 'libs.sfx+libs.oob'
            elif "'+libs.packages+'" in subsets_props:
                subset = 'libs.ref+libs.src+libs.packages'
            else:
                subset = 'libs.ref+libs.src'
            tools = 'tools+' if 'SubsetName Include="Tools' in subsets_props else ''
            # -allconfigurations: eng/packaging.targets generates the out-of-band packages only with BuildAllConfigurations
            # (.NET 6 to 9; 27/10 22:49, build 10 packed nothing), and the official build packs them in its
            # "Libraries_AllConfigurations" leg, "-s tools+libs -allConfigurations" on windows_x64 (eng/pipelines/runtime-official.yml)
            build = f'{cd}./build.sh {tools}{subset} -allconfigurations -c Release -ci -nobl -pack {props}'
            win = f'./build.cmd -subset {tools}{subset} -allconfigurations -c Release -ci -nobl -pack {props}; exit $LASTEXITCODE'
            facts.append(f'version 3, R3c: subset {tools}{subset} -allconfigurations (eng/Subsets.props at the commit names these; libs.native and libs.pretest left out; the official leg Libraries_AllConfigurations builds tools+libs -allConfigurations on windows_x64)  [read]')
        elif g['kind'] == 'runtime':
            build = f'{cd}./build.sh libs -c Release -ci -nobl -pack {props}'
            win = f'./build.cmd -subset libs -c Release -ci -nobl -pack {props}; exit $LASTEXITCODE'
        elif g['kind'] == 'roslyn':
            # Roslyn's eng/build.sh has no -nobl, and Arcade's tools.sh refuses a CI build without a binary log
            # unless opted out, so the log is written (-bl); it does not change what is built (27/10 22:28)
            build = f'{cd}./build.sh --restore --build --pack --ci -bl -c Release {props}'
            win = f'./{win_entry(url, commit, lab, ("-restore", "-pack"))} -ci -bl -c Release {props}; exit $LASTEXITCODE'
        else:
            build = f'{cd}./build.sh --restore --build --pack --ci -nobl -c Release {props}'
            win = f'./{win_entry(url, commit, lab, ("-restore", "-build", "-pack"))} -ci -nobl -c Release {props}; exit $LASTEXITCODE'
        facts.append(f'command: {build}  [rule R3]')
        if inner:   # the VMR is built on Linux only here: its Windows build needs Visual Studio's native toolchain and hours
            win = ''
            facts.append('no Windows command: a VMR inner build is not run on a Windows runner (no build_windows)')
        else:
            facts.append(f'command on a Windows runner (pwsh): {win}  [rule R3]')
        gj = f'{root}global.json'
        facts.append(f'sdk: from {gj}, installed by the repository\'s own eng/common/tools.sh into {root}.dotnet  [rule R2]')
        toml = [f'# Derived by derive-repo.py (repository-build method), see facts.txt beside it.',
                f'name = "{name}"', f'repo = "{url}"', f'commit = "{commit}"', f'inner = "{inner}"', f'kind = "{g["kind"]}"',
                f'official_build_id = "{bid}"', 'shell = "bash"', f"build = '''{build}'''",
                *([f"build_windows = '''{win}'''"] if win else []),
                f'packages = "{root}artifacts/packages/Release/Shipping"', 'os = "windows"',
                # R6: autocrlf=true stood for a Windows checkout; version 4, R6b: sources as committed (LF) with the
                # attributes the tree carries, because the shipped Identity.UI's Razor tag-helper ids (character
                # offsets into .cshtml) are those of LF files (28/10 00:25) - the official checkout does not convert
                ('git_config = ["core.autocrlf=false", "core.eol=lf"]' if v4 else 'git_config = ["core.autocrlf=true"]'),
                'strip_internal_feeds = true']
        major = sdk_major(mirror_of(url, lab), commit, root)
        facts.append(f'sdk major from global.json: {major if major else "unreadable"}')
        if v4:
            facts.append('version 4, R6b: core.autocrlf=false, core.eol=lf (sources as committed; .gitattributes of the tree still apply)  [rule]')
        if v3 and g['kind'] == 'aspnetcore' and not inner and major in NODE_BY_SDK:
            # version 3, R3d: the standalone aspnetcore build runs its npm projects (eng/Build.props adds NodeJsProjects
            # whenever node is on PATH; Components.Server references Web.JS.npmproj, so they cannot be left out) and the
            # tree's pinned tooling refuses this machine's Node 26 (27/10 23:16, 8.0: eslint-plugin-jsdoc wants ^14..^19).
            # The build gets the Node LTS line of the tree's era from nodejs.org, first on PATH; nothing compared contains JS.
            node = os.path.join(lab, 'node', f'node-v{NODE_BY_SDK[major]}-linux-x64', 'bin')
            toml.append(f'path_prepend = ["{node}"]')
            toml.append(f'node = "{NODE_BY_SDK[major]}"')   # the same line for a Windows runner, installed by the workflow
            facts.append(f'version 3, R3d: Node {NODE_BY_SDK[major]} (nodejs.org, sha256 checked) first on PATH for the npm projects of the .NET {major} tree  [rule]')
        # version 4, R2b: invariant globalization only below .NET 6. The .NET 7 SDK starts on this machine's ICU 78
        # (tested 28/10 02:25, 7.0.100-rc.1.22431.11), and in invariant mode the SDK's resource-locale check (NETSDK1188)
        # fails every build under --ci warnAsError (version 3, runtime-d099f07: 1384 errors). .NET 5 is untested.
        if major and major < (6 if v4 else 8):
            toml.append('[env]'); toml.append('DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1"')
            facts.append(f'env: DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 (SDK {major}.x: assumed not to start on Arch\'s ICU 78; version 4 limits this to .NET 5)')
        elif major and major < 8 and v4:
            facts.append(f'version 4, R2b: no invariant globalization for the .NET {major} SDK (it starts on ICU 78; invariant mode turns NETSDK1188 into a build error)  [rule]')
        for p in g['products']:
            toml += ['', '[[products]]', f'package = "{p["package"]}"', f'version = "{p["version"]}"', f'ships = "{p["ships"]}"', f'project = "{p["project"]}"', f'file_version = "{p["file_version"]}"']
        d = os.path.join(out, name); os.makedirs(d, exist_ok=True)
        open(os.path.join(d, 'recipe.toml'), 'w', encoding='utf-8').write('\n'.join(toml) + '\n')
        open(os.path.join(d, 'facts.txt'), 'w', encoding='utf-8').write('\n'.join(facts) + '\n')
        print(f'{name}: {len(g["products"])} products, build id {bid}')
    open(os.path.join(out, 'not-covered.txt'), 'w', encoding='utf-8').write('\n'.join(notes) + '\n')
    for n in notes:
        print(n)


if __name__ == '__main__':
    main()
