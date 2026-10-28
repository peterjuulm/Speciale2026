// Portable PDB dump: pdb id, documents (name, hash), the compilation options and metadata references the compiler
// recorded, the source link json. Run as a console project (net10.0): dotnet run -- A.pdb B.pdb  (writes <pdb>.txt beside each).
// Written 28 October 2026, 08:10, to read the four Windows level-3 rows; Microsoft.Build 17.11.48 ships its PDB in the nupkg.

using System.Reflection.Metadata;
using System.Reflection.Metadata.Ecma335;
using System.Security.Cryptography;
using System.Text;
// Portable PDB dump: stream hashes, the documents (name, hash), the compilation options and the metadata references
// (custom debug information on the module), the source link json, embedded sources count.
foreach (var path in args) {
    var bytes = File.ReadAllBytes(path);
    using var prov = MetadataReaderProvider.FromPortablePdbStream(new MemoryStream(bytes));
    var md = prov.GetMetadataReader();
    var sb = new StringBuilder();
    sb.AppendLine($"# {Path.GetFileName(path)} {bytes.Length} bytes sha256 {Convert.ToHexString(SHA256.HashData(bytes)).ToLower()[..16]}");
    var id = md.DebugMetadataHeader.Id; sb.AppendLine($"pdb id {Convert.ToHexString(id.ToArray()).ToLower()}");
    int docs = 0; var dsb = new StringBuilder();
    foreach (var dh in md.Documents) { var d = md.GetDocument(dh); docs++; dsb.AppendLine($"doc {md.GetString(d.Name)} {md.GetGuid(d.HashAlgorithm).ToString()[..8]} {Convert.ToHexString(md.GetBlobBytes(d.Hash)).ToLower()[..16]}"); }
    sb.AppendLine($"documents {docs}");
    foreach (var h in md.CustomDebugInformation) {
        var c = md.GetCustomDebugInformation(h); var kind = md.GetGuid(c.Kind); var blob = md.GetBlobBytes(c.Value);
        string label = kind == new Guid("B5FEEC05-8CD0-4A83-96DA-466284BB4BD8") ? "compilation-options" : kind == new Guid("7E4D4708-096E-4C5C-AEDA-CB10BA6A740D") ? "metadata-references" : kind == new Guid("CC110556-A091-4D38-9FEC-25AB9A351A6A") ? "source-link" : kind == new Guid("0E8A571B-6926-466E-B4AD-8AB04611F5FE") ? "embedded-source" : kind.ToString();
        if (label == "compilation-options") { var txt = Encoding.UTF8.GetString(blob).Replace('\0', '|'); sb.AppendLine($"compilation-options: {txt}"); }
        else if (label == "source-link") sb.AppendLine($"source-link: {Encoding.UTF8.GetString(blob).Replace("\n", " ")}");
        else if (label == "metadata-references") { sb.AppendLine($"metadata-references: {blob.Length} bytes sha256 {Convert.ToHexString(SHA256.HashData(blob)).ToLower()[..16]}"); File.WriteAllBytes(path + ".refs.bin", blob); }
        else if (label == "embedded-source") { }
        else sb.AppendLine($"cdi {label} parent {MetadataTokens.GetToken(c.Parent):X8} {blob.Length} bytes");
    }
    sb.AppendLine($"embedded-sources {md.CustomDebugInformation.Count(h => md.GetGuid(md.GetCustomDebugInformation(h).Kind) == new Guid("0E8A571B-6926-466E-B4AD-8AB04611F5FE"))}");
    sb.Append(dsb);
    File.WriteAllText(path + ".txt", sb.ToString()); Console.WriteLine(sb.ToString().Split('\n').Take(6).Aggregate((a, b) => a + "\n" + b));
}
