// Whole-file comparison of two DLLs with the signatures removed (level 2 checked on the whole file, not on report
// lines): the PE checksum, the Certificate Table entry and the Authenticode block it points at, and the strong-name
// signature bytes are zeroed or cut, trailing zero padding dropped, and the rest hashed.
// Run as a console project (net10.0): dotnet run -- SHIPPED.dll OURS.dll
// Written 28 October 2026, 08:00, after a second opinion noted that level 2 rested on report fields.

using System.Reflection.PortableExecutable;
using System.Security.Cryptography;
// Whole-file comparison with the signatures removed: for each DLL, zero the PE checksum, zero the Certificate Table
// directory entry and cut the Authenticode block it points at (always the file's tail), zero the strong-name
// signature bytes, drop trailing zero padding; then hash. Usage: ss SHIPPED.dll OURS.dll  -> prints both hashes and "equal"/"differ".
static byte[] norm(string path) {
    var b = File.ReadAllBytes(path);
    using var pe = new PEReader(new MemoryStream(b));
    var h = pe.PEHeaders; int opt = h.PEHeaderStartOffset;             // start of the optional header
    bool plus = h.PEHeader.Magic == PEMagic.PE32Plus;
    Array.Clear(b, opt + 64, 4);                                         // CheckSum
    var cert = h.PEHeader.CertificateTableDirectory;                     // RVA field = file offset for this entry
    int certEntry = opt + (plus ? 112 : 96) + 4 * 8;                     // data directory 4: directories start at 96 (PE32) or 112 (PE32+)
    Array.Clear(b, certEntry, 8);
    int len = b.Length;
    if (cert.Size > 0) { if (cert.RelativeVirtualAddress + cert.Size != b.Length) throw new Exception($"{path}: certificate block not at the tail"); len = cert.RelativeVirtualAddress; }
    var sn = h.CorHeader.StrongNameSignatureDirectory;
    if (sn.Size > 0) { int si = h.GetContainingSectionIndex(sn.RelativeVirtualAddress); var s = h.SectionHeaders[si]; Array.Clear(b, sn.RelativeVirtualAddress - s.VirtualAddress + s.PointerToRawData, sn.Size); }
    while (len > 0 && b[len - 1] == 0) len--;                            // alignment padding before a signature block
    return b.AsSpan(0, len).ToArray();
}
var a = norm(args[0]); var c = norm(args[1]);
string ha = Convert.ToHexString(SHA256.HashData(a)).ToLower(), hc = Convert.ToHexString(SHA256.HashData(c)).ToLower();
int first = -1; for (int i = 0; i < Math.Min(a.Length, c.Length); i++) if (a[i] != c[i]) { first = i; break; }
Console.WriteLine($"{(ha == hc ? "equal " : "differ")} shipped {a.Length} bytes {ha[..16]}  ours {c.Length} bytes {hc[..16]}" + (ha == hc ? "" : $"  first difference at 0x{(first < 0 ? Math.Min(a.Length, c.Length) : first):X}"));
