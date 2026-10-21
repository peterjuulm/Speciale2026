"""Install one .NET SDK, alone, into an empty directory.

Usage: python3 -I install-sdk.py VERSION DIR
       python3 -I install-sdk.py --runtime VERSION DIR

Takes the archive for this machine (linux-x64, or win-x64 on Windows) and its
SHA-512 from Microsoft's release metadata for the SDK's channel, checks the
hash, and unpacks it into DIR, which must be empty or missing. With nothing
else in DIR, the compiler runs on the runtime that came with this SDK and no
other (W58: csc rolls forward to the newest runtime it finds, and the PDB
records which one).

With --runtime, it adds the shared runtime VERSION (its shared/ folder only)
to an SDK already in DIR, for tests that target an older .NET, as a CI image
with several runtimes would run them. The compiler still runs on the SDK's
own runtime.

Written 21 October 2026 for the nupkg pilot; Windows added the same day for
the builds on GitHub's Windows runners.
"""
import hashlib, json, os, subprocess, sys, tempfile, urllib.request, zipfile

runtime = sys.argv[1] == '--runtime'
version, target = sys.argv[2:4] if runtime else sys.argv[1:3]
channel = '.'.join(version.split('.')[:2])
meta_url = f'https://builds.dotnet.microsoft.com/dotnet/release-metadata/{channel}/releases.json'
meta = json.load(urllib.request.urlopen(meta_url, timeout=60))
if runtime:
    sdk = next(r['runtime'] for r in meta['releases'] if (r.get('runtime') or {}).get('version') == version)
    kind = 'dotnet-runtime'
else:
    sdk = next(s for r in meta['releases'] for s in r.get('sdks', []) if s['version'] == version)
    kind = 'dotnet-sdk'
name = f'{kind}-win-x64.zip' if os.name == 'nt' else f'{kind}-linux-x64.tar.gz'
f = next(x for x in sdk['files'] if x['name'] == name)

if runtime and not os.path.isdir(os.path.join(target, 'shared')):
    sys.exit(f'{target} has no SDK to add a runtime to')
if not runtime and os.path.exists(target) and os.listdir(target):
    sys.exit(f'{target} is not empty')
os.makedirs(target, exist_ok=True)
with tempfile.TemporaryDirectory() as tmp:
    archive = os.path.join(tmp, name)
    h = hashlib.sha512()
    with urllib.request.urlopen(f['url'], timeout=600) as r, open(archive, 'wb') as out:
        while chunk := r.read(1 << 20):
            h.update(chunk); out.write(chunk)
    if h.hexdigest() != f['hash'].lower():
        sys.exit(f'SHA-512 mismatch for {f["url"]}')
    if name.endswith('.zip'):
        with zipfile.ZipFile(archive) as z:
            z.extractall(target, [m for m in z.namelist() if m.startswith('shared/')] if runtime else None)
    else:
        subprocess.run(['tar', '-xzf', archive, '-C', target] + (['--wildcards', '*shared/*'] if runtime else []), check=True)

print(f'{kind} {version}: {f["url"]}')
print(f'sha512 {f["hash"].lower()} (matches {meta_url})')
print(f'runtime in the release metadata: {sdk.get("runtime-version")}')
