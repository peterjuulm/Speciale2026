# Eksperiment 2b: miljøvariationer med PathMap

Kørt 14. september 2026 på `arch` (Leos laptop, Arch-SDK 14:38, Microsoft-SDK
14:43 CEST) og `ubuntu-vm` (delt droplet, 14:38 CEST), umiddelbart efter [environment-axes](2026-09-14-environment-axes.md). Samme
laboratorium `/private/tmp/rb1`, samme tre kildefiler, samme pinnede SDK
9.0.120. Ordlisten står i [empty-class](2026-09-07-empty-class.md).

Data: `data/2026-09-14-environment-axes-pathmap/arch/`, `.../ubuntu-vm/` og
`.../arch-ms-sdk/`. Den ordrette byggekommando står i `kommando.txt` i hver
mappe.

Spørgsmålet: **lukker `PathMap` den ene akse der faldt, og hvad står tilbage
når den er lukket?**

## Baggrund

Eksperiment 2 gav 13 verdikter som forudsagt: alt grønt undtagen
`+build_path`. Men de tolv grønne kørsler gav tolv forskellige DLL-hashes,
fordi reprotest bygger i en ny `/tmp/reprotest.XXXXXX/` per kørsel, og
mappenavnet står i DLL'en via stien til PDB-filen. "Successful" betød kun
"byg 1 og byg 2 i samme mappe er ens".

## Forventning, skrevet før kørslen

1. `+build_path` bliver grøn.
2. Alle kørsler på én maskine giver **samme** hash, fordi det tilfældige
   mappenavn ikke længere skrives ind.
3. De to maskiner giver **forskellige** hashes, selv om begge kører 9.0.120.
   Arch-pakkens `csc.dll` er bygget fra en anden Roslyn-commit end Microsofts,
   jf. [compiler-identity](2026-09-08-compiler-identity.md).
4. Bygges `arch` med Microsofts SDK fra `dotnet-install.sh` (ligger i
   `~/.dotnet` siden 8/9), rammer den VM'ens tal.

Hashen bliver ikke `4b3808d1…` fra eksperiment 1; det byg havde ingen `PathMap`
og indeholder stien `/private/tmp/rb1`.

## Kørslerne

Eneste ændring fra eksperiment 2 er den sidste parameter til `dotnet build`:

```bash
reprotest --vary=-all,+build_path -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release -p:PathMap=$PWD/=/_/' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll'
```

`$PWD` udfyldes af den shell reprotest starter byggeriet i, altså med den
mappe der faktisk bygges i. Compileren skriver så `/_/` hvor den ellers ville
skrive mappen. Første forsøg brugte `$(MSBuildProjectDirectory)`; det virker
ikke fra kommandolinjen, fordi MSBuild ikke udfylder egenskabsudtryk i globale
egenskaber. Parameteren blev ignoreret, og stien stod stadig i DLL'en. `[V]`
Kontrol af at afbildningen slog igennem:

```bash
strings -n 6 bin/Release/net9.0/minlib.dll | grep pdb
# /_/obj/Release/net9.0/minlib.pdb
```

I en csproj svarer parameteren til:

```xml
<PathMap>$(MSBuildProjectDirectory)=/_/</PathMap>
```

Tredje opsætning, `arch-ms-sdk`, sætter desuden
`PATH=/home/leos/.dotnet:$PATH DOTNET_ROOT=/home/leos/.dotnet` foran, så det
er Microsofts 9.0.120 der bygger. `environment.txt` viser
`Base Path: /home/leos/.dotnet/sdk/9.0.120/`.

## Resultat

| Akse | `arch`, Arch-SDK | `arch`, Microsoft-SDK | `ubuntu-vm` |
| --- | --- | --- | --- |
| `rt-1-none` | successful | successful | successful |
| `rt-2-umask` | successful | successful | successful |
| `rt-3-locales` | successful | successful | successful |
| `rt-4-exec_path` | successful | successful | successful |
| `rt-5-build_path` | **successful** | **successful** | **successful** |
| `rt-6-time` | successful | successful | successful |
| `rt-7-fileordering` | n/a | n/a | successful |
| DLL-hash, alle kørsler | `0b8f72d28cfd…` | `535a56fc682f…` | `535a56fc682f…` |

19 kørsler, 19 grønne, og tre hash-kolonner med ét tal i hver. `[V]`
(sidste linje i hver `rt-*.log`)

| Opsætning | `csc.dll` sha256 | Roslyn-commit | Hash |
| --- | --- | --- | --- |
| `arch`, Arch-pakken | `1b7543aa709363b6…` | `d0558bff…` | `0b8f72d28cfd…` |
| `arch`, Microsoft | `644a4d336dcd11a7…` | `fc52718e…` | `535a56fc682f…` |
| `ubuntu-vm`, Microsoft | `644a4d336dcd11a7…` | `fc52718e…` | `535a56fc682f…` |

Alle fire forventninger holdt.

## Fortolkning

**`PathMap` lukker stien, og kun stien.** `+build_path` går fra rød til grøn
med én parameter. Ingen anden akse ændrer sig, hvilket er ventet, for de var
grønne i forvejen.

**Hash-kolonnen kollapser fra tolv tal til ét per maskine.** Det er det
egentlige resultat. reprotests verdikt siger "byg 1 lig byg 2"; den ens hash
på tværs af seks uafhængige kørsler i seks tilfældige mapper siger "ethvert
byg lig ethvert byg". `arch`-hashen er desuden identisk med et byg lavet i
hånden i en fjerde mappe uden for reprotest. `[V]`

**Det der står tilbage mellem maskinerne, er oversætterens identitet.** Med
stien væk er der én forskel tilbage mellem `arch` og `ubuntu-vm`: hvilken
`csc.dll` der bygger. Skiftes Arch-pakkens til Microsofts, er tallene ens på
tværs af Arch Linux og Ubuntu. Det er 8/9-fundet igen, men nu uden sti-støj
og målt gennem alle akser: to compilere med samme versionsnummer giver to
forskellige binærer; to installationer af Microsofts compiler på to
styresystemer giver én.

Sammen med eksperiment 2: **et .NET-classlib-byg er følsomt over for præcis to
ting reprotest kan nå, byggemappen og oversætteren.** Den første lukkes med
`PathMap`. Den anden lukkes ikke af et versionsnummer, men af at hente
oversætteren fra samme kilde.

## Forbehold

- **`PathMap` er ikke gratis.** Fejlsøgere skal nu have fortalt at `/_/` betyder
  kildemappen (Source Link eller manuel afbildning). Ikke undersøgt her.
- **Kun DLL'en måles.** PDB'en indeholder stadig kildestier, afbildet til
  `/_/`, og compilerens identitet. Om to PDB'er er identiske på tværs af
  kørsler er ikke målt.
- **`+fileordering` med én kildefil** siger stadig lidt; se eksperiment 2.
- **Ikke testet:** Peters Mac. Forudsigelsen er `535a56fc682f…` med hans
  `dotnet-install.sh`-SDK og samme `PathMap`, selv om hans `csc.dll` er en anden
  fil (`1824569732a63f5d…`, osx-arm64), fordi den erklærede Roslyn-commit er
  den samme. `[I]`
- **Ikke testet:** `DebugType=none` som alternativ lukning, og om
  compiler-kanalen så også forsvinder fra DLL'en.
- `pedump` er stadig to forskellige programmer på de to maskiner; irrelevant
  her, da ingen kørsel faldt.
