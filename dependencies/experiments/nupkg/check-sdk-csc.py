"""Check sdk-csc.json against Microsoft's own record of each SDK's compiler.

Usage: python3 -I check-sdk-csc.py [SDK_CSC_JSON]

For every SDK version in the table, fetches eng/Version.Details.xml at the
SDK's release tag (v<version>) from the repository that built it:
dotnet/installer (up to 8.0.3xx), dotnet/sdk, or the VMR dotnet/dotnet
(src/sdk/eng/Version.Details.xml), and reads the Microsoft.Net.Compilers.
Toolset dependency: its version and the Roslyn commit (Sha). Compares both
with the string our derivation read out of the SDK's csc.dll
("<version>+<commit>"). Prints one line per SDK and a summary; exits 1 on
any mismatch.

Written 27 October 2026, after the claim "Microsoft publishes no mapping
from compiler to SDK" turned out too strong: the mapping exists one SDK at
a time, in the SDK's source tree.
"""
import json, os, re, sys, urllib.error, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCES = [('dotnet/installer', 'eng/Version.Details.xml'), ('dotnet/sdk', 'eng/Version.Details.xml'),
           ('dotnet/dotnet', 'src/sdk/eng/Version.Details.xml')]


def record(version):
    """(repo, toolset version, roslyn sha) from the first repository that has the tag, else None."""
    for repo, path in SOURCES:
        url = f'https://raw.githubusercontent.com/{repo}/v{version}/{path}'
        try:
            with urllib.request.urlopen(url, timeout=60) as r:
                xml = r.read().decode('utf-8', 'replace')
        except urllib.error.HTTPError:
            continue
        m = re.search(r'<Dependency Name="Microsoft\.Net\.Compilers\.Toolset" Version="([^"]+)"[^>]*>(.*?)</Dependency>', xml, re.S)
        if m:
            sha = re.search(r'<Sha>([0-9a-f]+)</Sha>', m.group(2))
            return repo, m.group(1), (sha.group(1) if sha else '')
        return repo, None, None
    return None


def main():
    table = json.load(open(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'sdk-csc.json'), encoding='utf-8'))
    counts = {'match': 0, 'mismatch': 0, 'no tag': 0, 'no record': 0}
    for sdk, ours in table.items():
        rec = record(sdk)
        if rec is None:
            counts['no tag'] += 1; print(f'{sdk:28} no release tag found in {", ".join(r for r, _ in SOURCES)}'); continue
        repo, tv, sha = rec
        if not tv:
            counts['no record'] += 1; print(f'{sdk:28} {repo}: tag found, no Compilers.Toolset dependency in the record'); continue
        theirs = f'{tv}+{sha}'
        if ours == theirs:
            counts['match'] += 1; print(f'{sdk:28} match     {theirs}  ({repo})')
        else:
            counts['mismatch'] += 1; print(f'{sdk:28} MISMATCH  record {theirs}  csc.dll {ours}  ({repo})')
    print('summary:', ', '.join(f'{k} {v}' for k, v in counts.items()))
    sys.exit(1 if counts['mismatch'] else 0)


if __name__ == '__main__':
    main()
