"""Map the differing bytes of two same-size .NET DLLs onto PE and metadata
regions (#~, #Strings, #Blob, #GUID, debug directory, ...).

Usage: python3 pe-diff-regions.py A.dll B.dll

Written 24 September 2026 for phoenix-layer2-reprotest.
"""
import struct, sys, collections
a = open(sys.argv[1], 'rb').read(); b = open(sys.argv[2], 'rb').read()
assert len(a) == len(b)
pe = struct.unpack_from('<I', a, 0x3c)[0]
nsec = struct.unpack_from('<H', a, pe + 6)[0]
optsz = struct.unpack_from('<H', a, pe + 20)[0]
opt = pe + 24
magic = struct.unpack_from('<H', a, opt)[0]
ddir = opt + (96 if magic == 0x10b else 112)
secs = []
for i in range(nsec):
    o = opt + optsz + 40 * i
    name = a[o:o+8].rstrip(b'\0').decode()
    vsize, va, rsize, raw = struct.unpack_from('<IIII', a, o + 8)
    secs.append((name, va, vsize, raw, rsize))
def off(rva):
    for n, va, vs, raw, rs in secs:
        if va <= rva < va + max(vs, rs): return raw + rva - va
regions = []
def reg(name, rva, size):
    if size: regions.append((off(rva), off(rva) + size, name))
cli_rva, cli_size = struct.unpack_from('<II', a, ddir + 14 * 8)
dbg_rva, dbg_size = struct.unpack_from('<II', a, ddir + 6 * 8)
reg('debug directory', dbg_rva, dbg_size)
c = off(cli_rva)
md_rva, md_size, flags, entry, res_rva, res_size, sn_rva, sn_size = struct.unpack_from('<IIIIIIII', a, c + 8)
reg('CLI resources', res_rva, res_size)
reg('strong name sig', sn_rva, sn_size)
m = off(md_rva)
vlen = struct.unpack_from('<I', a, m + 12)[0]
p = m + 16 + vlen + 2
nstreams = struct.unpack_from('<H', a, p)[0]; p += 2
for i in range(nstreams):
    so, ss = struct.unpack_from('<II', a, p); p += 8
    e = a.index(b'\0', p); sname = a[p:e].decode(); p = (e + 4) & ~3
    regions.append((m + so, m + so + ss, 'metadata ' + sname))
# debug directory entries' data
d = off(dbg_rva)
for i in range(dbg_size // 28):
    typ, size, rva_, raw = struct.unpack_from('<IIII', a, d + 28 * i + 12)
    regions.append((raw, raw + size, f'debug data type {typ}'))
regions.append((pe + 8, pe + 12, 'PE TimeDateStamp'))
regions.append((opt + 64 if magic == 0x10b else opt + 64, opt + 68, 'PE checksum'))
diffs = [i for i in range(len(a)) if a[i] != b[i]]
count = collections.Counter()
for i in diffs:
    names = [n for s, e, n in regions if s <= i < e]
    if not names:
        names = [f'section {n}' for n, va, vs, raw, rs in secs if raw <= i < raw + rs] or ['headers/other']
    count[' / '.join(names)] += 1
for k, v in count.most_common(): print(f'{v:5}  {k}')
print(f'{len(diffs)} differing bytes')
