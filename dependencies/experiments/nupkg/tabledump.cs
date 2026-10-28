// Per-table comparison of two DLLs' #~ streams (which tables differ, the first differing row) and the
// placement of the managed resources, the strong-name signature slot and the static data fields in
// the image. Run as a console project (net10.0): dotnet run -- SHIPPED.dll OURS.dll
// Written 28 October 2026 to read the runtime rows that differed in "managed resources" and "#~".

using System.Reflection.Metadata;
using System.Reflection.Metadata.Ecma335;
using System.Reflection.PortableExecutable;
using System.Security.Cryptography;
// Per-table comparison of the #~ stream of two DLLs: which tables differ, and for the first differing table the first differing row.
static Dictionary<TableIndex, (int rows, int size, byte[] bytes)> tables(string path) {
    using var pe = new PEReader(File.OpenRead(path)); var md = pe.GetMetadataReader();
    var block = pe.GetMetadata(); var d = new Dictionary<TableIndex, (int, int, byte[])>();
    foreach (TableIndex t in Enum.GetValues(typeof(TableIndex))) {
        int rows = md.GetTableRowCount(t); if (rows == 0) continue;
        int size = md.GetTableRowSize(t); int off = md.GetTableMetadataOffset(t);
        var r = block.GetReader(off, rows * size); d[t] = (rows, size, r.ReadBytes(rows * size));
    }
    return d;
}
var a = tables(args[0]); var b = tables(args[1]);
foreach (var t in a.Keys.Union(b.Keys).OrderBy(x => (int)x)) {
    if (!a.ContainsKey(t) || !b.ContainsKey(t)) { Console.WriteLine($"  {t}: only in {(a.ContainsKey(t) ? "shipped" : "ours")}"); continue; }
    var (ra, sa, ba) = a[t]; var (rb, sb, bb) = b[t];
    if (ra != rb || sa != sb) { Console.WriteLine($"  {t}: rows {ra}/{rb}, row size {sa}/{sb}"); continue; }
    if (ba.AsSpan().SequenceEqual(bb)) continue;
    int i = 0; while (ba[i] == bb[i]) i++;
    Console.WriteLine($"  {t}: {ra} rows of {sa} bytes differ; first difference in row {i / sa + 1}, column byte {i % sa}: shipped {Convert.ToHexString(ba.AsSpan(i / sa * sa, sa))} ours {Convert.ToHexString(bb.AsSpan(i / sa * sa, sa))}; differing rows {Enumerable.Range(0, ra).Count(r => !ba.AsSpan(r * sa, sa).SequenceEqual(bb.AsSpan(r * sa, sa)))}");
}
foreach (var p in new[] { args[0], args[1] }) {
    using var pe = new PEReader(File.OpenRead(p)); var md = pe.GetMetadataReader(); var ch = pe.PEHeaders.CorHeader;
    var rvas = md.FieldDefinitions.Select(h => md.GetFieldDefinition(h)).Select(f => f.GetRelativeVirtualAddress()).Where(r => r != 0).ToList();
    Console.WriteLine($"  {Path.GetFileName(p)}: resources at RVA 0x{ch.ResourcesDirectory.RelativeVirtualAddress:X} size {ch.ResourcesDirectory.Size} (end 0x{ch.ResourcesDirectory.RelativeVirtualAddress + ch.ResourcesDirectory.Size:X}); strong-name sig at 0x{ch.StrongNameSignatureDirectory.RelativeVirtualAddress:X} size {ch.StrongNameSignatureDirectory.Size}; static data fields at {string.Join(",", rvas.Select(r => "0x" + r.ToString("X")).Take(3))}");
}
