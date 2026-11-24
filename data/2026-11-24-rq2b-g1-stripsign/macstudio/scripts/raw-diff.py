# Run from the lab as: python3 -I raw-diff.py  (the inline script of step 7, saved verbatim)
import struct, glob, os
print("package\tA bytes\tnuget.org bytes\tdiffering byte offsets within A's length (before stripping)\tnuget.org tail beyond A")
for d in sorted(glob.glob('dll/*')):
    p = os.path.basename(d)
    if 'rerun' in p: continue
    a = open(f'{d}/A.dll','rb').read(); n = open(f'{d}/nugetorg.dll','rb').read()
    pe = struct.unpack_from('<I', a, 0x3C)[0]; opt = pe + 24
    plus = struct.unpack_from('<H', a, opt)[0] == 0x20B
    ck = opt + 64; cert = opt + (112 if plus else 96) + 32
    diffs = [i for i in range(min(len(a), len(n))) if a[i] != n[i]]
    # group into runs
    runs = []
    for i in diffs:
        if runs and i == runs[-1][1] + 1: runs[-1][1] = i
        else: runs.append([i, i])
    def lab(r):
        s, e = r
        if ck <= s and e < ck + 4: return f'0x{s:X}-0x{e:X} (PE checksum)'
        if cert <= s and e < cert + 8: return f'0x{s:X}-0x{e:X} (certificate table entry)'
        return f'0x{s:X}-0x{e:X} (OTHER)'
    cs, csz = struct.unpack_from('<II', n, cert)
    print(f"{p}\t{len(a)}\t{len(n)}\t{'; '.join(lab(r) for r in runs)}\tAuthenticode at 0x{cs:X}, {csz} bytes, ends at {cs+csz} (file {len(n)})")
