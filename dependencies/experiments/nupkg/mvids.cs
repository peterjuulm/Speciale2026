// mvids.cs: print "file mvid" for every .dll under the given directories, to
// match a compiler record's references (by MVID) with public reference packs.
// Usage: dotnet run mvids.cs -- DIR...
// Written 21 October 2026 for the nupkg pilot.
using System.Reflection.Metadata;
using System.Reflection.PortableExecutable;

foreach (var dir in args)
    foreach (var f in Directory.EnumerateFiles(dir, "*.dll", SearchOption.AllDirectories).Order(StringComparer.Ordinal))
    {
        try
        {
            using var pe = new PEReader(File.OpenRead(f));
            if (!pe.HasMetadata) continue;
            var md = pe.GetMetadataReader();
            Console.WriteLine($"{Path.GetFileName(f)} {md.GetGuid(md.GetModuleDefinition().Mvid)} {f}");
        }
        catch (BadImageFormatException) { }
    }
