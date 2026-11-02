import struct, sys, hashlib
def rd(b, o, n): return b[o:o+n]
def u16(b,o): return struct.unpack_from('<H',b,o)[0]
def u32(b,o): return struct.unpack_from('<I',b,o)[0]
def parse(p):
    b=open(p,'rb').read(); pe=u32(b,0x3c); fh=pe+4; opt=fh+20
    nsec=u16(b,fh+2); optsz=u16(b,fh+16); magic=u16(b,opt)
    dd=opt+(112 if magic==0x20b else 96)
    secs=[]; so=opt+optsz
    for i in range(nsec):
        s=so+40*i; secs.append((u32(b,s+12),u32(b,s+16),u32(b,s+20)))
    def rva2off(r):
        for va,sz,raw in secs:
            if va<=r<va+sz: return r-va+raw
    print(p, 'size',len(b),'TimeDateStamp %08x'%u32(b,fh+4),'CheckSum %08x'%u32(b,opt+64))
    drva,dsz=u32(b,dd+6*8),u32(b,dd+6*8+4); do=rva2off(drva)
    for i in range(dsz//28):
        e=do+28*i; typ=u32(b,e+12); size=u32(b,e+16); off=u32(b,e+24); data=b[off:off+size]
        if typ==2:
            guid=data[4:20].hex(); age=u32(data,20); path=data[24:].split(b'\0')[0].decode()
            print('  CodeView guid',guid,'age',age,'path',path)
        elif typ==16: print('  Reproducible')
        elif typ==19: print('  PdbChecksum', data.split(b'\0')[0].decode(), data[len(data.split(b'\0')[0])+1:].hex())
        elif typ==17: print('  EmbeddedPdb size',size)
        else: print('  debug type',typ,'size',size,'off',off)
    cli_rva=u32(b,dd+14*8); co=rva2off(cli_rva)
    snr,sns=u32(b,co+32),u32(b,co+36); print('  StrongNameSig rva %x size %d fileoff %s'%(snr,sns,rva2off(snr) if snr else None))
    mdr=u32(b,co+8); mo=rva2off(mdr); print('  Metadata fileoff',mo,'size',u32(b,co+12))
for p in sys.argv[1:]: parse(p)
