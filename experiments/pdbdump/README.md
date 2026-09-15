# pdbdump

Dumps a portable PDB's document table (path, hash algorithm, content hash) and
its CustomDebugInformation (Source Link, CompilationOptions, EmbeddedSource and
others). With a second argument it writes out the embedded source files for
`*.cshtml.g.cs`.

    dotnet build -c Release -o out
    dotnet out/pdbdump.dll Foo.pdb            # tables to stdout
    dotnet out/pdbdump.dll Foo.pdb outdir/    # + embedded Razor source to outdir/

Written 15/9 2026 to find the last differing byte in WebAPI.pdb.
System.Reflection.Metadata only, no packages.
