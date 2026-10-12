"""Compare two zip archives entry by entry, field by field.

Prints whether the archives are identical as bytes, whether they hold the same
entry names in the same order, and for each field of the central directory
and the local headers how many entries differ: the stored time (DOS date and
time), the external attributes (the Unix mode), the extra fields (Info-ZIP's
UT time stamps and ux owner), the CRC, sizes and compression. Then the first
few differing entries per field.

Usage: python3 compare-zip.py A.zip B.zip

Written 12 October 2026 for phoenix-zip.
"""
import hashlib
import struct
import sys
import zipfile


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def local_extra(f, info):
    # The local header repeats name and extra; Info-ZIP puts atime there too.
    f.seek(info.header_offset)
    head = f.read(30)
    name_len, extra_len = struct.unpack('<HH', head[26:30])
    f.seek(info.header_offset + 30 + name_len)
    return f.read(extra_len)


def fields(path):
    out = {}
    with zipfile.ZipFile(path) as z, open(path, 'rb') as f:
        for i in z.infolist():
            out[i.filename] = {
                'date_time': i.date_time,
                'external_attr': oct(i.external_attr >> 16),
                'central_extra': i.extra.hex(),
                'local_extra': local_extra(f, i).hex(),
                'crc': i.CRC,
                'compress_size': i.compress_size,
                'file_size': i.file_size,
                'compress_type': i.compress_type,
                'create_system': i.create_system,
                'internal_attr': i.internal_attr,
                'flag_bits': i.flag_bits,
            }
        names = [i.filename for i in z.infolist()]
    return names, out


def main():
    a, b = sys.argv[1:3]
    print(f'{a}: {sha(a)[:16]}')
    print(f'{b}: {sha(b)[:16]}')
    na, fa = fields(a)
    nb, fb = fields(b)
    print(f'entries: {len(na)} and {len(nb)}; same set: {set(na) == set(nb)}; same order: {na == nb}')
    if set(na) == set(nb) and na != nb:
        moved = sum(1 for x, y in zip(na, nb) if x != y)
        print(f'  {moved} positions hold another name')
    common = [n for n in na if n in fb]
    for key in fa[na[0]].keys():
        diff = [n for n in common if fa[n][key] != fb[n][key]]
        print(f'{key}: {len(diff)} of {len(common)} differ')
        for n in diff[:3]:
            print(f'    {n}: {fa[n][key]} | {fb[n][key]}')


if __name__ == '__main__':
    main()
