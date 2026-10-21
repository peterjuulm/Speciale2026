#:property AllowUnsafeBlocks=true

// dllreport.cs: a plain-text report of one .NET DLL and its portable PDB, made
// to be diffed against the report of another build of the same DLL.
//
// Usage (needs the .NET 10 SDK for file-based apps):
//   dotnet run dllreport.cs -- DLL [PDB]
// The PDB is read from the DLL when it is embedded, else from the PDB argument,
// else from a file next to the DLL with the name in the CodeView entry. Without
// a PDB the report stops after the DLL part.
//
// Every section hashes its own bytes, so a diff shows where two builds part:
// the PE headers, the signatures, the metadata streams, the IL bodies, the
// resources, the debug entries, and in the PDB the compiler record, the
// references, the source documents and the PDB's own streams.
//
// Written 21 October 2026 for the nupkg pilot (dependencies/notes/2026-10-21-nupkg-pilot-serilog-runners.md).

using System.Collections.Immutable;
using System.IO.Compression;
using System.Reflection.Metadata;
using System.Reflection.Metadata.Ecma335;
using System.Reflection.PortableExecutable;
using System.Security.Cryptography;
using System.Text;

static string Hex(ReadOnlySpan<byte> b) => Convert.ToHexStringLower(b);
static string Sha(ReadOnlySpan<byte> b) => Hex(SHA256.HashData(b));

var dllPath = args[0];
var bytes = File.ReadAllBytes(dllPath);
var o = Console.Out;
o.WriteLine($"file: {Path.GetFileName(dllPath)}");
o.WriteLine($"size: {bytes.Length}");
o.WriteLine($"sha256: {Sha(bytes)}");

using var pe = new PEReader(ImmutableArray.Create(bytes));
var h = pe.PEHeaders;
var opt = h.PEHeader!;
var cor = h.CorHeader!;

int Offset(DirectoryEntry d) => h.TryGetDirectoryOffset(d, out var off) ? off : -1;

o.WriteLine("\n## PE headers");
o.WriteLine($"machine: {h.CoffHeader.Machine}");
o.WriteLine($"timestamp: 0x{h.CoffHeader.TimeDateStamp:x8}");
o.WriteLine($"characteristics: {h.CoffHeader.Characteristics}");
o.WriteLine($"linker version: {opt.MajorLinkerVersion}.{opt.MinorLinkerVersion}");
o.WriteLine($"subsystem: {opt.Subsystem}");
o.WriteLine($"dll characteristics: {opt.DllCharacteristics}");
o.WriteLine($"pe checksum: 0x{opt.CheckSum:x8}");
foreach (var s in h.SectionHeaders)
    o.WriteLine($"section {s.Name}: virtual size {s.VirtualSize}, raw size {s.SizeOfRawData}");

o.WriteLine("\n## Signatures");
var cert = opt.CertificateTableDirectory;
o.WriteLine(cert.Size == 0 ? "authenticode: none"
    : $"authenticode: {cert.Size} bytes, sha256 {Sha(bytes.AsSpan(cert.RelativeVirtualAddress, cert.Size))}");
o.WriteLine($"cor flags: {cor.Flags}");
var sn = cor.StrongNameSignatureDirectory;
if (sn.Size == 0) o.WriteLine("strong-name signature: none");
else
{
    var sig = bytes.AsSpan(Offset(sn), sn.Size);
    var zero = sig.IndexOfAnyExcept((byte)0) < 0;
    o.WriteLine($"strong-name signature: {sn.Size} bytes, sha256 {Sha(sig)}{(zero ? " (all zeros: not signed)" : "")}");
}

o.WriteLine("\n## Metadata");
var md = pe.GetMetadataReader();
o.WriteLine($"metadata version: {md.MetadataVersion}");
var mdBlock = pe.GetMetadata().GetContent().AsSpan();
o.WriteLine($"metadata: {mdBlock.Length} bytes, sha256 {Sha(mdBlock)}");
foreach (var (name, off, size) in Streams(mdBlock))
    o.WriteLine($"metadata stream {name}: {size} bytes, sha256 {Sha(mdBlock.Slice(off, size))}");
o.WriteLine($"mvid: {md.GetGuid(md.GetModuleDefinition().Mvid)}");

using (var il = IncrementalHash.CreateHash(HashAlgorithmName.SHA256))
{
    int n = 0;
    foreach (var mh in md.MethodDefinitions)
    {
        var rva = md.GetMethodDefinition(mh).RelativeVirtualAddress;
        if (rva == 0) continue;
        var body = pe.GetMethodBody(rva);
        il.AppendData(body.GetILBytes() ?? []);
        il.AppendData(BitConverter.GetBytes(body.MaxStack));
        n++;
    }
    o.WriteLine($"il bodies: {n} methods, sha256 {Hex(il.GetHashAndReset())}");
}
var res = cor.ResourcesDirectory;
o.WriteLine(res.Size == 0 ? "managed resources: none"
    : $"managed resources: {res.Size} bytes, sha256 {Sha(bytes.AsSpan(Offset(res), res.Size))}");

o.WriteLine("\n## Assembly");
var asm = md.GetAssemblyDefinition();
o.WriteLine($"name: {md.GetString(asm.Name)}, version {asm.Version}, culture '{md.GetString(asm.Culture)}', flags {asm.Flags}");
var pk = md.GetBlobBytes(asm.PublicKey);
o.WriteLine($"public key: {(pk.Length == 0 ? "none" : Sha(pk))}");
foreach (var a in md.GetCustomAttributes(EntityHandle.AssemblyDefinition).Select(x => Attr(md, x)).Order(StringComparer.Ordinal))
    o.WriteLine($"attribute: {a}");
foreach (var r in md.AssemblyReferences.Select(x => md.GetAssemblyReference(x))
             .Select(r => $"{md.GetString(r.Name)} {r.Version} {Hex(md.GetBlobBytes(r.PublicKeyOrToken))}").Order(StringComparer.Ordinal))
    o.WriteLine($"assembly reference: {r}");

o.WriteLine("\n## Debug directory");
MetadataReaderProvider? pdbProvider = null;
string pdbFrom = "";
foreach (var e in pe.ReadDebugDirectory())
{
    var line = $"{e.Type}: version {e.MajorVersion}.{e.MinorVersion}, stamp 0x{e.Stamp:x8}, size {e.DataSize}";
    switch (e.Type)
    {
        case DebugDirectoryEntryType.CodeView:
            var cv = pe.ReadCodeViewDebugDirectoryData(e);
            line += $", guid {cv.Guid}, age {cv.Age}, path {cv.Path}";
            if (pdbProvider == null)
            {
                var path = args.Length > 1 ? args[1] : Path.Combine(Path.GetDirectoryName(Path.GetFullPath(dllPath))!, Path.GetFileName(cv.Path.Replace('\\', '/')));
                if (File.Exists(path)) { pdbProvider = MetadataReaderProvider.FromPortablePdbImage(ImmutableArray.Create(File.ReadAllBytes(path))); pdbFrom = Path.GetFileName(path); }
            }
            break;
        case DebugDirectoryEntryType.PdbChecksum:
            var pc = pe.ReadPdbChecksumDebugDirectoryData(e);
            line += $", {pc.AlgorithmName} {Hex(pc.Checksum.AsSpan())}";
            break;
        case DebugDirectoryEntryType.EmbeddedPortablePdb:
            pdbProvider?.Dispose();
            pdbProvider = MetadataReaderProvider.FromPortablePdbImage(EmbeddedPdb(bytes, e));
            pdbFrom = "embedded";
            break;
    }
    o.WriteLine(line);
}

if (pdbProvider == null) { o.WriteLine("\n## PDB\nnot found"); return; }
var pdb = pdbProvider.GetMetadataReader();
var pdbBlock = PdbImage(pdbProvider);
o.WriteLine($"\n## PDB ({pdbFrom})");
o.WriteLine($"size: {pdbBlock.Length}, sha256 {Sha(pdbBlock)}");
foreach (var (name, off, size) in Streams(pdbBlock))
    o.WriteLine($"pdb stream {name}: {size} bytes, sha256 {Sha(pdbBlock.AsSpan(off, size))}");
o.WriteLine($"pdb id: {Hex(pdb.DebugMetadataHeader!.Id.AsSpan())}");

var compilationOptions = new Guid("B5FEEC05-8CD0-4A83-96DA-466284BB4BD8");
var metadataReferences = new Guid("7E4D4708-096E-4C5C-AEDA-CB10BA6A740D");
var sourceLink = new Guid("CC110556-A091-4D38-9FEC-25AB9A351A6A");
var embeddedSource = new Guid("0E8A571B-6926-466E-B4AD-8AB04611F5FE");

foreach (var ch in pdb.GetCustomDebugInformation(EntityHandle.ModuleDefinition))
{
    var cdi = pdb.GetCustomDebugInformation(ch);
    var kind = pdb.GetGuid(cdi.Kind);
    var blob = pdb.GetBlobBytes(cdi.Value);
    if (kind == compilationOptions)
    {
        o.WriteLine("\n## Compiler record");
        var parts = Encoding.UTF8.GetString(blob).Split('\0');
        for (int i = 0; i + 1 < parts.Length; i += 2) o.WriteLine($"{parts[i]}: {parts[i + 1]}");
    }
    else if (kind == metadataReferences)
    {
        o.WriteLine("\n## Metadata references");
        var refs = new List<string>();
        int p = 0;
        while (p < blob.Length)
        {
            string Z() { int e = Array.IndexOf(blob, (byte)0, p); var s = Encoding.UTF8.GetString(blob, p, e - p); p = e + 1; return s; }
            var file = Z(); var aliases = Z();
            var kindByte = blob[p]; p += 1;
            var stamp = BitConverter.ToUInt32(blob, p); p += 4;
            var size = BitConverter.ToUInt32(blob, p); p += 4;
            var mvid = new Guid(blob.AsSpan(p, 16)); p += 16;
            refs.Add($"{file} aliases '{aliases}' kind 0x{kindByte:x2} stamp 0x{stamp:x8} size {size} mvid {mvid}");
        }
        foreach (var r in refs.Order(StringComparer.Ordinal)) o.WriteLine($"reference: {r}");
    }
    else if (kind == sourceLink)
        o.WriteLine($"\n## Source Link\n{Encoding.UTF8.GetString(blob).Replace("\r", "").Replace("\n", "")}");
}

o.WriteLine("\n## Documents");
var sha1 = new Guid("FF1816EC-AA5E-4D10-87F7-6F4963833460");
var sha256 = new Guid("8829D00F-11B8-4213-878B-770E8597AC16");
var docs = new List<string>();
foreach (var dh in pdb.Documents)
{
    var d = pdb.GetDocument(dh);
    var alg = pdb.GetGuid(d.HashAlgorithm);
    var algName = alg == sha256 ? "sha256" : alg == sha1 ? "sha1" : alg.ToString();
    var embedded = "";
    foreach (var ch in pdb.GetCustomDebugInformation(dh))
    {
        var cdi = pdb.GetCustomDebugInformation(ch);
        if (pdb.GetGuid(cdi.Kind) != embeddedSource) continue;
        var text = EmbeddedText(pdb.GetBlobBytes(cdi.Value));
        int crlf = 0, lf = 0;
        for (int i = 0; i < text.Length; i++) if (text[i] == (byte)'\n') { if (i > 0 && text[i - 1] == (byte)'\r') crlf++; else lf++; }
        embedded = $" embedded (crlf {crlf}, lf {lf})";
    }
    docs.Add($"document: {pdb.GetString(d.Name)} {algName} {Hex(pdb.GetBlobBytes(d.Hash))}{embedded}");
}
foreach (var d in docs.Order(StringComparer.Ordinal)) o.WriteLine(d);
return;

// The stream headers of a metadata root (ECMA-335 II.24.2.1): name, offset, size.
static IEnumerable<(string, int, int)> Streams(ReadOnlySpan<byte> root)
{
    var list = new List<(string, int, int)>();
    int vlen = BitConverter.ToInt32(root.Slice(12, 4));
    int p = 16 + vlen + 2;
    int n = BitConverter.ToUInt16(root.Slice(p, 2)); p += 2;
    for (int i = 0; i < n; i++)
    {
        int off = BitConverter.ToInt32(root.Slice(p, 4)), size = BitConverter.ToInt32(root.Slice(p + 4, 4)); p += 8;
        int end = root.Slice(p).IndexOf((byte)0);
        var name = Encoding.ASCII.GetString(root.Slice(p, end));
        p = (p + end + 4) & ~3;
        list.Add((name, off, size));
    }
    return list.OrderBy(x => x.Item1, StringComparer.Ordinal);
}

// An embedded portable PDB is "MPDB", the uncompressed size, then a deflate stream.
static ImmutableArray<byte> EmbeddedPdb(byte[] dll, DebugDirectoryEntry e)
{
    var data = dll.AsSpan(e.DataPointer, e.DataSize);
    int size = BitConverter.ToInt32(data.Slice(4, 4));
    using var z = new DeflateStream(new MemoryStream(data.Slice(8).ToArray()), CompressionMode.Decompress);
    var buf = new byte[size];
    z.ReadExactly(buf);
    return ImmutableArray.Create(buf);
}

// Embedded source: an int32, 0 for raw text or the size before deflate, then the text.
static byte[] EmbeddedText(byte[] blob)
{
    int size = BitConverter.ToInt32(blob, 0);
    if (size == 0) return blob[4..];
    using var z = new DeflateStream(new MemoryStream(blob, 4, blob.Length - 4), CompressionMode.Decompress);
    var buf = new byte[size];
    z.ReadExactly(buf);
    return buf;
}

static byte[] PdbImage(MetadataReaderProvider p)
{
    var r = p.GetMetadataReader();
    unsafe { return new ReadOnlySpan<byte>(r.MetadataPointer, r.MetadataLength).ToArray(); }
}

static string Attr(MetadataReader md, CustomAttributeHandle h)
{
    var a = md.GetCustomAttribute(h);
    string type = a.Constructor.Kind switch
    {
        HandleKind.MemberReference => TypeName(md, md.GetMemberReference((MemberReferenceHandle)a.Constructor).Parent),
        HandleKind.MethodDefinition => md.GetString(md.GetTypeDefinition(md.GetMethodDefinition((MethodDefinitionHandle)a.Constructor).GetDeclaringType()).Name),
        _ => "?"
    };
    try
    {
        var v = a.DecodeValue(new TypeProvider());
        var args = v.FixedArguments.Select(x => $"{x.Value}").Concat(v.NamedArguments.Select(x => $"{x.Name}={x.Value}"));
        return $"{type}({string.Join(", ", args)})";
    }
    catch { return $"{type}(blob {Sha(md.GetBlobBytes(a.Value))})"; }
}

static string TypeName(MetadataReader md, EntityHandle h) => h.Kind switch
{
    HandleKind.TypeReference => md.GetString(md.GetTypeReference((TypeReferenceHandle)h).Name),
    HandleKind.TypeDefinition => md.GetString(md.GetTypeDefinition((TypeDefinitionHandle)h).Name),
    _ => "?"
};

sealed class TypeProvider : ICustomAttributeTypeProvider<string>
{
    public string GetPrimitiveType(PrimitiveTypeCode t) => t.ToString();
    public string GetSystemType() => "Type";
    public string GetSZArrayType(string e) => e + "[]";
    public string GetTypeFromDefinition(MetadataReader r, TypeDefinitionHandle h, byte k) => r.GetString(r.GetTypeDefinition(h).Name);
    public string GetTypeFromReference(MetadataReader r, TypeReferenceHandle h, byte k) => r.GetString(r.GetTypeReference(h).Name);
    public string GetTypeFromSerializedName(string n) => n;
    public PrimitiveTypeCode GetUnderlyingEnumType(string t) => PrimitiveTypeCode.Int32;
    public bool IsSystemType(string t) => t == "Type";
}
