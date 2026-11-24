"""Negative and positive controls for stripsign.cs: flip one byte of a DLL in a chosen region.

Usage: python3 -I control.py IN.dll OUT.dll REGION
REGION: rsrc (first byte of the .rsrc section's raw data, the Win32 version resource),
        text-mid (the middle byte of the .text section's raw data),
        snsig (first byte of the strong-name signature).
Prints the file offset flipped.
"""
import struct, sys

src, dst, region = sys.argv[1:4]
b = bytearray(open(src, 'rb').read())
pe = struct.unpack_from('<I', b, 0x3C)[0]
nsec = struct.unpack_from('<H', b, pe + 6)[0]
optsize = struct.unpack_from('<H', b, pe + 20)[0]
opt = pe + 24
magic = struct.unpack_from('<H', b, opt)[0]
dirs = opt + (96 if magic == 0x10B else 112)
secs = []
for i in range(nsec):
    s = opt + optsize + 40 * i
    name = b[s:s + 8].rstrip(b'\0').decode()
    vsize, va, rawsize, rawptr = struct.unpack_from('<IIII', b, s + 8)
    secs.append((name, va, vsize, rawptr, rawsize))


def rva2off(rva):
    for name, va, vsize, rawptr, rawsize in secs:
        if va <= rva < va + max(vsize, rawsize):
            return rva - va + rawptr
    raise ValueError(rva)


if region == 'rsrc':
    off = next(rawptr for name, va, vsize, rawptr, rawsize in secs if name == '.rsrc')
elif region == 'text-mid':
    off = next(rawptr + rawsize // 2 for name, va, vsize, rawptr, rawsize in secs if name == '.text')
elif region == 'snsig':
    cli_rva = struct.unpack_from('<I', b, dirs + 14 * 8)[0]
    cli = rva2off(cli_rva)
    sn_rva, sn_size = struct.unpack_from('<II', b, cli + 32)
    if not sn_size:
        sys.exit('no strong-name signature')
    off = rva2off(sn_rva)
else:
    sys.exit(f'unknown region {region}')
b[off] ^= 0xFF
open(dst, 'wb').write(b)
print(f'{region}: flipped byte at 0x{off:X}')
