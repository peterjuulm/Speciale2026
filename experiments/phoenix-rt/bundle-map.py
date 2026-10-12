"""Map byte offsets in a .NET single-file bundle to its embedded files.

Usage: bundle-map.py BUNDLE OFFSETS_FILE [--extract NAME OUT]
Reads the bundle header (format 6) after the apphost's bundle signature.
Written 13 October 2026 for the migration bundle probe.
"""
import mmap, struct, sys
SIG = bytes([0x8b,0x12,0x02,0xb9,0x6a,0x61,0x20,0x38,0x72,0x7b,0x93,0x02,0x14,0xd7,0xa0,0x32,
             0x13,0xf5,0xb9,0xe6,0xef,0xae,0x33,0x18,0xee,0x3b,0x2d,0xce,0x24,0xb3,0x6a,0xae])
def entries(path):
    f = open(path, 'rb'); m = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
    i = m.find(SIG, 0, 50_000_000)
    hdr = struct.unpack('<q', m[i-8:i])[0]
    def read7(pos):
        n = shift = 0
        while True:
            b = m[pos]; pos += 1; n |= (b & 0x7f) << shift; shift += 7
            if b < 0x80: return n, pos
    def rstr(pos):
        n, pos = read7(pos); return m[pos:pos+n].decode('utf-8'), pos + n
    p = hdr
    major, minor, count = struct.unpack('<iii', m[p:p+12]); p += 12
    bid, p = rstr(p)
    if major >= 2: p += 8 * 4 + 8
    out = []
    for _ in range(count):
        off, size = struct.unpack('<qq', m[p:p+16]); p += 16
        csize = struct.unpack('<q', m[p:p+8])[0] if major >= 6 else 0
        if major >= 6: p += 8
        typ = m[p]; p += 1
        name, p = rstr(p)
        out.append((off, size, csize, typ, name))
    return m, hdr, bid, out
m, hdr, bid, ents = entries(sys.argv[1])
if '--extract' in sys.argv:
    k = sys.argv.index('--extract'); name, dest = sys.argv[k+1], sys.argv[k+2]
    for off, size, csize, typ, n in ents:
        if n == name:
            open(dest, 'wb').write(m[off:off + (csize or size)]); print('extracted', name, csize or size, 'compressed' if csize else ''); break
    sys.exit()
print('header at', hdr, 'bundle id', bid, 'files', len(ents))
hits = {}
for o in (int(x) for x in open(sys.argv[2])):
    where = 'bundle header' if o >= hdr else 'apphost'
    for off, size, csize, typ, name in ents:
        if off <= o < off + (csize or size):
            where = name; break
    hits.setdefault(where, []).append(o)
for k, v in hits.items(): print(len(v), k, 'first', v[0])
