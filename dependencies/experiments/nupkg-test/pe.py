"""Helpers for the nupkg test: what needs the publisher's key, out of a DLL.

Usage:
  python3 -I pe.py pdb DLL OUT.pdb     write the DLL's embedded portable PDB
  python3 -I pe.py strip DLL OUT.dll   write the DLL without what needs a key
  python3 -I pe.py options DLL         print the compiler record (key = value)

strip removes the Authenticode certificate table (the data directory entry
and the certificate bytes at the end of the file), zeroes the PE checksum,
and zeroes the strong-name signature. Decision 6 of the dependency plan.
Everything else is left as it is.

Written 21 October 2026 for the nupkg pilot.
"""
import struct, sys, zlib


def headers(data):
    pe, = struct.unpack_from('<I', data, 0x3c)
    assert data[pe:pe + 4] == b'PE\0\0', 'not a PE file'
    nsec, = struct.unpack_from('<H', data, pe + 6)
    optsize, = struct.unpack_from('<H', data, pe + 20)
    opt = pe + 24
    magic, = struct.unpack_from('<H', data, opt)
    dd = opt + (96 if magic == 0x10b else 112)
    secs = []
    for i in range(nsec):
        s = opt + optsize + 40 * i
        vsize, va, rawsize, rawptr = struct.unpack_from('<IIII', data, s + 8)
        secs.append((va, max(vsize, rawsize), rawptr))
    def off(rva):
        for va, size, raw in secs:
            if va <= rva < va + size: return rva - va + raw
        return None
    return opt, dd, off


def embedded_pdb(data):
    _, dd, off = headers(data)
    dbg_rva, dbg_size = struct.unpack_from('<II', data, dd + 8 * 6)
    o = off(dbg_rva)
    for i in range(dbg_size // 28):
        _, _, _, _, typ, size, _, ptr = struct.unpack_from('<IIHHIIII', data, o + 28 * i)
        if typ == 17 and data[ptr:ptr + 4] == b'MPDB':
            return zlib.decompress(data[ptr + 8:ptr + size], -15)
    sys.exit('no embedded PDB')


def strip(data):
    data = bytearray(data)
    opt, dd, off = headers(data)
    struct.pack_into('<I', data, opt + 64, 0)                  # PE checksum
    cert_off, cert_size = struct.unpack_from('<II', data, dd + 8 * 4)
    if cert_size:
        assert cert_off + cert_size == len(data), 'certificate table is not at the end'
        del data[cert_off:]
        struct.pack_into('<II', data, dd + 8 * 4, 0, 0)
    clr_rva, clr_size = struct.unpack_from('<II', data, dd + 8 * 14)
    if clr_size:
        o = off(clr_rva)
        sig_rva, sig_size = struct.unpack_from('<II', data, o + 32)
        if sig_size:
            s = off(sig_rva)
            data[s:s + sig_size] = bytes(sig_size)
    return bytes(data)


def options(pdb):
    # The CompilationOptions blob: key\0value\0 pairs, starting at "version".
    i = pdb.find(b'compiler-version\0')
    start = pdb.rfind(b'version\0', 0, i)
    parts = pdb[start:].split(b'\0')
    out = []
    for k, v in zip(parts[0::2], parts[1::2]):
        if not k or not all(c in b'abcdefghijklmnopqrstuvwxyz-' for c in k): break
        out.append((k.decode(), v.decode('utf-8', 'replace')))
    return out


cmd, dll = sys.argv[1:3]
data = open(dll, 'rb').read()
if cmd == 'pdb':
    open(sys.argv[3], 'wb').write(embedded_pdb(data))
elif cmd == 'strip':
    open(sys.argv[3], 'wb').write(strip(data))
elif cmd == 'options':
    for k, v in options(embedded_pdb(data)):
        print(f'{k} = {v}')
else:
    sys.exit(__doc__)
