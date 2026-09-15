using System.Reflection.Metadata.Ecma335;
using System.Collections.Immutable;
using System.Reflection.Metadata;
using System.Text;
var bytes = File.ReadAllBytes(args[0]);
var provider = MetadataReaderProvider.FromPortablePdbImage(ImmutableArray.Create(bytes));
var r = provider.GetMetadataReader();
string Hex(byte[] b) => Convert.ToHexString(b).ToLowerInvariant();
string Guidname(Guid g) => g.ToString() switch {
  "0e8a571b-6926-466e-b4ad-8ab04611f5fe" => "EmbeddedSource",
  "cc110556-a091-4d38-9fec-25ab9a351a6a" => "SourceLink",
  "b5feec05-8cd0-4a83-96da-466284bb4bd8" => "CompilationOptions",
  "7e4d4708-096e-4c5c-aeda-cb10ba6a740d" => "CompilationMetadataReferences",
  "54fd2ac5-e925-401a-9c2a-f94f171072f8" => "EncLocalSlotMap",
  "58b2eab6-209f-4e4e-a22c-b2d0f910c782" => "StateMachineHoistedLocalScopes",
  "755f52a8-91c5-45be-b4b8-209571e552bd" => "TupleElementNames",
  "83c563c4-b4f3-47d5-b824-ba5441477ea8" => "DefaultNamespace",
  "6da9a61e-f8c7-4874-be62-68bc5630df71" => "DynamicLocalVariables",
  "9d40ace1-c703-4d0e-bf41-7243060a8fb5" => "PrimaryConstructorInformationBlob",
  "8b78cd68-2edd-4fa5-a3b7-00a71005f8d1" => "TypeDefinitionDocuments",
  var s => s };
Console.WriteLine($"== Documents ({r.Documents.Count})");
foreach (var h in r.Documents) {
  var d = r.GetDocument(h);
  Console.WriteLine($"{r.GetString(d.Name)}  alg={Guidname(r.GetGuid(d.HashAlgorithm))[..8]}  hash={Hex(r.GetBlobBytes(d.Hash))[..16]}");
}
Console.WriteLine($"== CustomDebugInformation ({r.CustomDebugInformation.Count})");
foreach (var h in r.CustomDebugInformation) {
  var c = r.GetCustomDebugInformation(h);
  var kind = Guidname(r.GetGuid(c.Kind));
  var v = r.GetBlobBytes(c.Value);
  string shown = kind is "SourceLink" or "CompilationOptions" or "DefaultNamespace" ? Encoding.UTF8.GetString(v).Replace("\0", " | ") : $"{v.Length} bytes {Hex(v)[..Math.Min(32, v.Length*2)]}";
  if (kind is "EmbeddedSource") shown = $"{v.Length} bytes";
  Console.WriteLine($"{kind} parent={c.Parent.Kind}:{MetadataTokens.GetRowNumber(c.Parent)}  {shown}");
}
if (args.Length > 1) {
  foreach (var h in r.CustomDebugInformation) {
    var c = r.GetCustomDebugInformation(h);
    if (Guidname(r.GetGuid(c.Kind)) != "EmbeddedSource" || c.Parent.Kind != HandleKind.Document) continue;
    var docName = r.GetString(r.GetDocument((DocumentHandle)c.Parent).Name);
    if (!docName.Contains("cshtml.g.cs")) continue;
    var v = r.GetBlobBytes(c.Value);
    int fmt = BitConverter.ToInt32(v, 0);
    byte[] content;
    if (fmt == 0) content = v[4..];
    else { using var ds = new System.IO.Compression.DeflateStream(new MemoryStream(v, 4, v.Length - 4), System.IO.Compression.CompressionMode.Decompress); var ms = new MemoryStream(); ds.CopyTo(ms); content = ms.ToArray(); }
    File.WriteAllBytes(Path.Combine(args[1], Path.GetFileName(docName)), content);
  }
}
