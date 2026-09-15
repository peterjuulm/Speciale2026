# Who does what in a .NET build

Background note, not an experiment. Written 8 September 2026 because the
division of labour between MSBuild and Roslyn is easy to confuse, and because
that division decides how a reproducibility number should be read.

Short version: **Roslyn produces exactly one assembly per project. MSBuild
produces none.** MSBuild resolves references, generates source, calls the
compiler once, and then copies files around.

## One project, one call to the compiler

```mermaid
flowchart TB
    CSPROJ["minlib.csproj"]
    CS["Beregning.cs<br/>written by hand"]
    PKG["~/.nuget/packages<br/>downloaded packages"]

    subgraph MSB["dotnet build = MSBuild. The whole process, target by target"]
        direction TB
        T1["1. Evaluate<br/>read csproj + Directory.Build.props,<br/>compute all properties"]
        T2["2. Restore (NuGet task)<br/>resolve the package graph,<br/>write obj/project.assets.json"]
        T3["3. ResolveReferences<br/>pick DLLs from packages and projects<br/>using the assets file"]
        T4["4. GenerateAssemblyInfo<br/>write obj/minlib.AssemblyInfo.cs<br/>with AssemblyVersion, InformationalVersion"]
        T5["5. Source Link / PathMap<br/>find SourceRoot, build the /pathmap argument"]
        T6["6. CoreCompile<br/>one call to csc (Roslyn)<br/>with all .cs files, references and flags"]
        T7["7. GenerateBuildDependencyFile<br/>write bin/minlib.deps.json and<br/>minlib.runtimeconfig.json"]
        T8["8. CopyFilesToOutputDirectory<br/>copy obj/minlib.dll + .pdb to bin/,<br/>copy package DLLs to bin/"]
        T1 --> T2 --> T3 --> T4 --> T5 --> T6 --> T7 --> T8
    end

    CSPROJ --> T1
    PKG --> T2
    CS --> T6
    T6 -->|"writes"| ODLL["obj/Release/net9.0/minlib.dll<br/>THE ASSEMBLY"]
    T6 -->|"writes"| OPDB["obj/Release/net9.0/minlib.pdb<br/>symbols"]
    T8 --> BIN["bin/Release/net9.0/<br/>minlib.dll, minlib.pdb, package DLLs,<br/>deps.json, runtimeconfig.json"]

    classDef roslyn fill:#dbeafe,stroke:#1e40af,color:#0b1a33
    classDef msbuild fill:#e5e7eb,stroke:#374151,color:#111827
    classDef kilde fill:#dcfce7,stroke:#166534,color:#052e16
    class T6,ODLL,OPDB roslyn
    class T1,T2,T3,T4,T5,T7,T8,BIN msbuild
    class CS,CSPROJ,PKG kilde
```

The big box is all of `dotnet build`. Everything in it is MSBuild running its
targets in order. Blue is the single step where compilation happens: MSBuild
calls csc once per project, and csc writes exactly two files back into `obj/`.
All the grey steps are MSBuild's own work: read, resolve, generate, copy. Green
is input.

The steps carry the names they have in the SDK's targets files, so you can look
them up with `dotnet build -v:n` and watch them go by. The order is simplified:
a real build has around a hundred targets, and several of them run between the
ones shown.

Two things are worth holding on to. `bin/.../minlib.dll` is a **copy**. The
original sits in `obj/`, and the two are bit-identical (verified 8/9:
`541bed823d12e42b…` on both paths). That is why the cleanup is `rm -rf bin obj`
and not just `rm -rf bin`: delete only `bin` and MSBuild sees that `obj` is
current, copies back, and never calls csc. A "clean build" would have been a
re-copy.

And `minlib.AssemblyInfo.cs` exists in no repo. MSBuild writes it during the
build and compiles it along with the rest. That is where
`AssemblyInformationalVersion` comes from. The version string in a finished
binary therefore has no source you can point at in git.

## What a release artefact then consists of

```mermaid
flowchart LR
    subgraph her["Built here and now"]
        MINE["your projects' assemblies<br/>one per csproj"]
        MYPDB["their PDBs"]
    end
    subgraph andetsteds["Compiled by another csc, somewhere else"]
        NUGET["managed assemblies<br/>from NuGet packages"]
    end
    subgraph native["Never compiled by any csc"]
        NAT["native libraries<br/>coreclr, clrjit, e_sqlite3, onnxruntime"]
        HOST["apphost<br/>WebAPI.exe / extensionless WebAPI"]
    end
    subgraph skrevet["Written by MSBuild"]
        JSON["deps.json<br/>runtimeconfig.json"]
    end

    MINE --> ZIP[["publish/ → zip or container"]]
    MYPDB --> ZIP
    NUGET --> ZIP
    NAT --> ZIP
    HOST --> ZIP
    JSON --> ZIP

    classDef a fill:#dbeafe,stroke:#1e40af,color:#0b1a33
    classDef b fill:#fef3c7,stroke:#92400e,color:#1f1300
    classDef c fill:#fee2e2,stroke:#991b1b,color:#1f0505
    classDef d fill:#e5e7eb,stroke:#374151,color:#111827
    class MINE,MYPDB a
    class NUGET b
    class NAT,HOST c
    class JSON d
```

That split is the whole reason this note exists. A number like "X of Y files
bit-identical on repetition" says almost nothing if most of Y are copied bytes:
they are identical by construction, because nobody compiled them again. Only the
blue group is something our build produces, and it is small, a handful of
assemblies in an output of hundreds of files.

So an honest baseline reports three numbers, not one: built here, copied in, and
generated metadata.

## How to see what a file is

The extension is only a convention. `file` looks at the PE header and finds the
CLI header, which is what makes a PE file managed:

```bash
file bin/Release/net9.0/minlib.dll
```

    PE32 executable for MS Windows (DLL), Intel i386 Mono/.Net assembly, 3 sections

A PDB answers "Microsoft Roslyn C# debugging symbols", a native library "ELF
64-bit LSB shared object". Note that "Intel i386" appears on an
architecture-neutral assembly: managed PEs are marked 32-bit-preferred in the
header, and that should not be read as a 32-bit build.

The `.dll` files in an output that are *not* assemblies are found with:

```bash
find . -name '*.dll' -exec file {} + | grep -v 'Mono/.Net assembly'
```

And an overview of the whole directory:

```bash
find . -type f -print0 | xargs -0 file | sed 's/.*: //' | cut -c1-45 | sort | uniq -c | sort -rn
```

## Caveats

- The diagrams describe an SDK project built with `dotnet build` or
  `dotnet publish`. Single-file publish, AOT and trimming move the boundaries.
- csc can emit more than what is shown: `/target:module` gives a `.netmodule`
  with IL and metadata but no assembly manifest, the pure "not an assembly".
  CoreCLR cannot load it, so it does not show up in practice.
- The number of native files depends on which packages the project pulls in.

## What is inside an assembly

Measured on `bin/Release/net9.0/minlib.dll` from the lab, 8 September 2026. The
file is 4096 bytes in total, an empty class with one method.

```mermaid
flowchart TB
    subgraph FIL["minlib.dll, 4096 bytes, PE32"]
        subgraph W["The Windows inheritance: the PE structure"]
            DOS["DOS stub and PE header"]
            DD["Data directories<br>no. 14 points at the CLI header"]
            DBG["Debug directory, no. 6, 84 bytes<br>embedded path: /private/tmp/rb1/obj/Release/net9.0/minlib.pdb<br>plus PDB id and checksum"]
            RSRC[".rsrc, 776 bytes<br>Win32 VERSIONINFO, built from the assembly attributes"]
            RELOC[".reloc, 12 bytes"]
        end
        subgraph M["The managed part: .text, 1588 bytes"]
            COR["CLI header, COR20, 72 bytes"]
            subgraph MD["Metadata tables"]
                ASM["Assembly: name, version, culture, public key<br>self-declared, with no binding to bytes"]
                MOD["Module: MVID<br>hash of the content in deterministic mode"]
                TD["TypeDef, MethodDef, FieldDef"]
                AR["AssemblyRef, TypeRef, MemberRef"]
                HP["Heaps: Strings, Blob, GUID, UserString"]
            end
            IL["IL method bodies<br/>Beregning.Tal returns 42"]
        end
    end

    classDef flytter fill:#fee2e2,stroke:#991b1b,color:#1f0505
    classDef stabil fill:#dbeafe,stroke:#1e40af,color:#0b1a33
    classDef win fill:#e5e7eb,stroke:#374151,color:#111827
    class DBG,MOD flytter
    class IL,TD,AR,HP,ASM,COR stabil
    class DOS,DD,RSRC,RELOC win
```

Red is what moved in our measurements. Blue is what stood still.

It is worth seeing how little of the file is code. `.text` is 1588 bytes and
holds the CLI header, all the metadata tables and the IL. `.rsrc` is 776 bytes
of Windows resource, a VERSIONINFO block generated from the same assembly
attributes MSBuild wrote in `AssemblyInfo.cs`. The version number therefore
appears twice in the file: as metadata in the Assembly table, and as a Windows
resource. Neither is bound to the content.

Two things in the diagram explain everything we have measured.

**Debug directory, 84 bytes.** It holds an absolute path to the PDB file, and
note that the DLL in `bin/` points at a PDB in `obj/`. That is the string
`+build_path` changes, and therefore the axis we expect to fail. The same place
holds the PDB id and checksum, which follow along when the PDB changes.

**MVID in the Module table.** In deterministic mode it is a hash of the compiled
content. It is therefore derived: if anything changes, the MVID changes with it.
That is why one cause, a path, produced 189 differing byte positions on 19
August. One source, many traces.

The rest, IL, types, references, heaps, is content that changes only if the
source or the compiler does.
