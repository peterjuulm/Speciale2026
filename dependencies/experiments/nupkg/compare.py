"""Compare the files in two or more .nupkg files, entry by entry.

Usage: python3 -I compare.py SHIPPED REFERENCE.nupkg OTHER.nupkg...

SHIPPED is the path inside the package of the DLL that ships in Phoenix, for
example lib/net9.0/Serilog.dll. Each entry is listed with its SHA-256 per
package; "same" when every package has the same bytes. Packaging files that
are random or added by nuget.org (the .psmdcp core-properties file, its
_rels, [Content_Types].xml, .signature.p7s) are listed but marked, since the
test compares DLLs and PDBs only (decision 6). The last line is the verdict
for SHIPPED. Exit code 0 when SHIPPED is identical in all packages.

Written 21 October 2026 for the nupkg pilot.
"""
import hashlib, sys, zipfile

shipped, paths = sys.argv[1], sys.argv[2:]
zips = [zipfile.ZipFile(p) for p in paths]
def norm(n): return 'package/services/metadata/core-properties/*.psmdcp' if n.endswith('.psmdcp') else n
entries = [{norm(i.filename): hashlib.sha256(z.read(i)).hexdigest() for i in z.infolist() if not i.filename.endswith('/')} for z in zips]
packaging = ('.psmdcp', '_rels/.rels', '[Content_Types].xml', '.signature.p7s')

for i, p in enumerate(paths): print(f'package {i}: {p}')
for name in sorted(set().union(*entries)):
    hs = [e.get(name, '-') for e in entries]
    state = 'same' if len(set(hs)) == 1 else 'only in some' if '-' in hs else 'DIFFERS'
    mark = ' (packaging)' if name.endswith(packaging) else ' (SHIPS)' if name == shipped else ''
    print(f'{state:12} {name}{mark}: ' + ' '.join(h[:16] for h in hs))
hs = [e.get(shipped) for e in entries]
ok = None not in hs and len(set(hs)) == 1
print(f'verdict: {shipped} is {"IDENTICAL" if ok else "DIFFERENT"} in all {len(paths)} packages')
sys.exit(0 if ok else 1)
