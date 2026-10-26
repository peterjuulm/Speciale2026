"""The match level of a rebuilt DLL against the published one, from two
dllreport.cs reports.

Usage: python3 -I level.py REPORT_NUGETORG REPORT_OURS

Prints one line: the level and the report lines that differ, by label.
Levels (dependencies/notes/2026-10-21-nupkg-pilot-serilog-runners.md):

  1  identical: the same sha256.
  2  identical without signatures: the only differing lines are the file's
     name, size and hash, the PE checksum, the Authenticode entry and the
     strong-name signature.
  3  same code: the IL bodies, the metadata streams #~, #Strings, #US and
     #Blob and the managed resources have the same hashes; the rest (debug
     identity, MVID, timestamp, PDB) may differ.
  4  different code: anything else.

Only the DLL's own sections are read (up to "## PDB" or "## Source Link"):
the PDB is compared by the package comparison, not here.

Written 26 October 2026.
"""
import sys

SIGN = {'file', 'size', 'sha256', 'pe checksum', 'authenticode', 'strong-name signature'}
CODE = {'il bodies', 'metadata stream #~', 'metadata stream #Strings', 'metadata stream #US', 'metadata stream #Blob'}


def dll_lines(path):
    d = {}
    for line in open(path, encoding='utf-8'):
        line = line.rstrip('\n')
        if line.startswith('## PDB') or line.startswith('## Source Link') or line.startswith('## Compiler record'):
            break
        if ': ' in line and not line.startswith('#'):
            k, v = line.split(': ', 1)
            d[k] = v
    return d


def main():
    a, b = dll_lines(sys.argv[1]), dll_lines(sys.argv[2])
    diff = sorted(k for k in set(a) | set(b) if a.get(k) != b.get(k))
    if a.get('sha256') == b.get('sha256'):
        level = 1
    elif set(diff) <= SIGN:
        level = 2
    elif not any(k in diff or k.startswith('resource') for k in CODE) and not any(k.startswith('resource') for k in diff):
        level = 3
    else:
        level = 4
    print(f'level {level}; differing lines: {", ".join(diff) or "none"}')


if __name__ == '__main__':
    main()
