"""Print the #Strings heap entries of a .NET DLL at the given hex offsets,
for example the names behind string#a317 in an ildasm -METADATA=RAW dump.

Usage: python3 md-strings.py A.dll a317 a86d ...

Written 24 September 2026 for phoenix-layer2-reprotest.
"""
import struct, sys
a = open(sys.argv[1], 'rb').read()
pe = struct.unpack_from('<I', a, 0x3c)[0]
nsec = struct.unpack_from('<H', a, pe + 6)[0]; optsz = struct.unpack_from('<H', a, pe + 20)[0]; opt = pe + 24
magic = struct.unpack_from('<H', a, opt)[0]; ddir = opt + (96 if magic == 0x10b else 112)
secs = [struct.unpack_from('<IIII', a, opt + optsz + 40 * i + 8) for i in range(nsec)]
def off(rva):
    for vs, va, rs, raw in secs:
        if va <= rva < va + max(vs, rs): return raw + rva - va
cli = off(struct.unpack_from('<I', a, ddir + 14 * 8)[0])
m = off(struct.unpack_from('<I', a, cli + 8)[0])
vlen = struct.unpack_from('<I', a, m + 12)[0]; p = m + 16 + vlen + 2
n = struct.unpack_from('<H', a, p)[0]; p += 2
for i in range(n):
    so, ss = struct.unpack_from('<II', a, p); p += 8
    e = a.index(b'\0', p); name = a[p:e].decode(); p = (e + 4) & ~3
    if name == '#Strings': heap = m + so
for h in sys.argv[2:]:
    s = heap + int(h, 16); e = a.index(b'\0', s)
    print(h, a[s:e].decode())
