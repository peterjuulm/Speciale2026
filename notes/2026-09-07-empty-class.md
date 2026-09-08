# Eksperiment 1: tom klasse, to miljøer

Kørt 7. september 2026 på `arch` (Leos laptop, EndeavourOS) og `ubuntu-vm`
(delt DigitalOcean-droplet, Ubuntu 24.04.4). Peters mac er ikke kørt.

Data: `data/2026-09-07-empty-class/arch/` og `.../ubuntu-vm/`.

Spørgsmålet: samme kildekode, oversat to gange — kommer de samme bytes ud?

En tom klasse med vilje. Én fil, ingen pakker, intet der kan gå galt af andre
grunde. Er den ikke reproducerbar, er intet større det. Ordlisten nederst
forklarer termerne, og de andre notater henviser hertil.

## Resultat

**To builds på samme maskine: identiske, begge steder.**
**De to maskiner imellem: forskellige.**

| Miljø | `minlib.dll` |
| --- | --- |
| `arch` | `541bed823d12e42b5e9e6087c9c32a9d6fbaa9a116aae61fc00c808231e74113` |
| `ubuntu-vm` | `4b3808d1cc1d642577f60a054905f5f065aab8b9aea1765b407fc583cef70d33` |

Hver hash står to gange i sin `hashes.txt`, fra to rene builds med `rm -rf bin obj`
imellem. Så oversætteren vakler ikke af sig selv i nogen af miljøerne.

## Fortolkning

Kilden og stien er udelukket som forklaring. Begge miljøblokke siger
`global.json file: /private/tmp/rb1/global.json`, så byggemappen var den samme
streng. De tre inputfiler blev kontrolleret mod samme forventede hashes på begge
maskiner (se forbehold: kontrollen blev ikke gemt som fil).

Tilbage står fire forskelle:

| | `arch` | `ubuntu-vm` |
| --- | --- | --- |
| `csc.dll` | `1b7543aa709363b6…` | `644a4d336dcd11a7…` |
| SDK-oprindelse | Arch-pakken `dotnet-sdk-9.0 9.0.19.sdk120-1`, kildebygget af distributionen | Microsofts binære udgivelse via `dotnet-install.sh` |
| RID | `arch-x64` | `linux-x64` |
| `LANG` | `da_DK.UTF-8` | `C.UTF-8` |

Hovedmistænkt er den første: **to forskellige oversættere, begge kaldet 9.0.120.**
At RID'en også afviger bekræfter at Arch' SDK er en anden konstruktion, ikke bare
en anden kopi af den samme.

Det er afhandlingens egen tese, dukket op i måleapparatet: versionsnummeret er en
selvdeklareret streng, ikke en binding til en binær. To maskiner kan begge svare
"9.0.120" og alligevel oversætte med forskellig kode.

Om det faktisk er forklaringen, afgøres i
[compiler-identity](2026-09-08-compiler-identity.md).

## Opsætningen, til gentagelse

Laboratoriet er `/private/tmp/rb1` — samme absolutte sti i alle miljøer, fordi
stien bliver indlejret i den færdige DLL. Ikke `~/...`: hjemmemapperne hedder
ikke det samme. På macOS er `/tmp` et symlink til `/private/tmp`, og derfor er
`/private/tmp` den fysiske sti der findes overalt. På Linux oprettes den:

```bash
sudo mkdir -p /private/tmp && sudo chmod 1777 /private/tmp
```

Resultatmappen hedder `$UD` i alle kommandoer. Stien afhænger af hvor repoet er
klonet, mappenavnet af miljøet:

```bash
export UD=$HOME/Speciale2026/data/2026-09-07-empty-class/ubuntu-vm && mkdir -p "$UD"
```

fish bruger `set -gx UD ...` i stedet; `set -gx` findes ikke i bash. Er `$UD` tom,
bliver `tee -a $UD/hashes.txt` til `tee -a /hashes.txt` og fejler med
`Permission denied`. Tjek altid `echo $UD` først, og husk at variablen forsvinder
ved ny fane eller ny ssh-session.

De tre filer skrives i hånden, ikke med `dotnet new`: skabelonen følger
SDK-versionen, så to SDK'er kan give forskellig kildekode, og så måler man
skabelonen i stedet for oversætteren.

```bash
printf '<Project Sdk="Microsoft.NET.Sdk">\n  <PropertyGroup>\n    <TargetFramework>net9.0</TargetFramework>\n  </PropertyGroup>\n</Project>\n' > /private/tmp/rb1/minlib.csproj
```

```bash
printf 'namespace Minlib;\n\npublic class Beregning\n{\n    public int Tal() => 42;\n}\n' > /private/tmp/rb1/Beregning.cs
```

```bash
printf '{\n  "sdk": {\n    "version": "9.0.120",\n    "rollForward": "disable"\n  }\n}\n' > /private/tmp/rb1/global.json
```

`global.json` vælger hvilket værktøj der bygger; `.csproj` beskriver hvad der
bygges. De to akser er uafhængige — SDK 10 kan udmærket bygge `net9.0` — så uden
pinnet ville maskinerne kunne bruge hver sin oversætter uden at noget i projektet
afslørede det. `rollForward: disable` lukker den stille glidning: mangler
9.0.120, fejler byggeriet tydeligt.

Kontrollér kilden, og **gem kontrollen**:

```bash
cd /private/tmp/rb1 && sha256sum minlib.csproj Beregning.cs global.json | tee "$UD/sources.txt"
```

| Fil | sha256 |
| --- | --- |
| `minlib.csproj` | `2a766d57249ab657b48234557ff2c6a7610239797c4e23a26020a77c2d03183e` |
| `Beregning.cs` | `079f65f3d3a0c041bb61817e68762b5a6f9206014714632be79608fab5185fda` |
| `global.json` | `8628a3a4483b68445847707e60dd11611bafff8b23f26ee4df6b21e1922bd021` |

Hashen på `global.json` gælder version 9.0.120; vælges en anden, ændrer den sig.
`shasum -a 256` på macOS.

Kontrollér at pinnet virker, **fra projektmappen** — `dotnet --version` slår
`global.json` op fra den mappe man står i, så uden for laboratoriet får man sin
nyeste SDK:

```bash
cd /private/tmp/rb1 && dotnet --version
```

```bash
cd /private/tmp/rb1 && dotnet --info | grep -A 1 'global.json file'
```

Der skal stå `9.0.120` og `/private/tmp/rb1/global.json`. Står der `Not found`,
bygger man med en anden oversætter uden at få det at vide.

## Miljøblokken

Byggemiljøet er alt uden om kildekoden der kan påvirke resultatet: SDK-version,
styresystem, sprogindstillinger, filrettigheder, versionen af måleværktøjet. Den
optages **før** målingen. Afviger resultatet, er det blokken der forklarer hvorfor
— og det var præcis den der gjorde det her.

`dotnet --info` skal køres fra projektmappen, ellers beskriver den en anden SDK
end den der bygger:

```bash
cd /private/tmp/rb1 && dotnet --info > "$UD/environment.txt"
```

```bash
uname -srm >> "$UD/environment.txt"; umask >> "$UD/environment.txt"; locale | head -1 >> "$UD/environment.txt"; diffoscope --version >> "$UD/environment.txt" 2>&1; pipx list >> "$UD/environment.txt" 2>&1
```

Hvilke binærer der faktisk bliver fundet — ikke hvilke der er installeret:

```bash
command -v dotnet reprotest diffoscope >> "$UD/environment.txt"
```

Og oversætteren som fil, ikke som versionsnummer:

```bash
cd /private/tmp/rb1 && sha256sum "$(dotnet --info | sed -n 's/^ *Base Path: *//p')Roslyn/bincore/csc.dll" | tee -a "$UD/environment.txt"
```

`csc.dll` er selve C#-oversætteren. Hashen af den er det eneste der faktisk
identificerer hvad der byggede — og den er grunden til at det her eksperiment
kunne forklares i stedet for bare at fejle.

## Målingen

To rene builds, samme mappe:

```bash
cd /private/tmp/rb1; dotnet build -c Release; sha256sum bin/Release/net9.0/minlib.dll | tee -a "$UD/hashes.txt"
```

```bash
cd /private/tmp/rb1; rm -rf bin obj; dotnet build -c Release; sha256sum bin/Release/net9.0/minlib.dll | tee -a "$UD/hashes.txt"
```

Afviger de to inden for samme maskine, er der noget i opsætningen, og alt
derefter er støj.

Byggestien kan læses direkte ud af DLL'en. Det virker uden noget værktøj, og det
viser mekanismen med egne øjne:

```bash
cd /private/tmp/rb1 && env LC_ALL=C grep -ao '/[A-Za-z0-9_/.-]*rb1[A-Za-z0-9_/.-]*' bin/Release/net9.0/minlib.dll | sort -u
```

Der står den absolutte sti til PDB-filen, indlejret i den oversatte kode.

## Forbehold

- **Kildekontrollen blev ikke gemt.** Kommandoen printede kun til skærmen, så vi
  har ikke skriftligt bevis for at de tre inputfiler var identiske på de to
  maskiner. `| tee "$UD/sources.txt"` er tilføjet ovenfor, og filerne står urørt
  i begge laboratorier, så beviset kan hentes bagefter.
- **`command -v` blev ikke optaget.** På VM'en ligger to udgaver af alle
  værktøjer, så `pipx list` alene siger ikke hvad der kørte.
- **Miljøvariationerne er ikke målt her.** De ligger i
  [environment-axes](2026-09-08-environment-axes.md).
- **Kun `dotnet build`.** Ingen pakning, ingen publish, ingen container — og
  derfor intet arkiv. Zip- og tar-metadata (tidsstempler, ejerskab,
  filrækkefølge) kan ikke optræde i et resultat der består af løse filer.
- **Kun x64 Linux.** macOS og arm64 er urørt.
- **Ingen afhængigheder.** Projektet har ingen `PackageReference`, så restore og
  transitive pakker er ikke i spil.

## Ordliste

- **bit-identisk** — to filer er ens ned til hver enkelt byte, ikke bare "samme
  indhold".
- **hash, sha256** — et fingeraftryk af bytes. Samme bytes giver altid samme
  fingeraftryk; én byte forskel giver et helt andet. Derfor sammenligner vi
  hashes i stedet for filer.
- **DLL** — den oversatte kode, det egentlige resultat af byggeriet.
- **IL** — Intermediate Language. Den mellemkode .NET oversætter kildekoden til.
  Uafhængig af processortype; oversættelsen til maskinkode sker først ved kørsel.
- **PDB** — fejlsøgningsfilen, der oversætter fra maskinkode tilbage til linjer i
  kildekoden. DLL'en indeholder en henvisning til den, og henvisningen er en
  absolut sti.
- **MVID** — modul-id'et i DLL'en. I deterministisk tilstand udregnes det som en
  hash af indholdet i stedet for at trækkes tilfældigt. Det er den beslutning der
  gør to builds sammenlignelige.
- **byggemiljø** — alt uden om kildekoden der kan påvirke resultatet:
  SDK-version, styresystem, sprogindstillinger, filrettigheder, klokken,
  byggestien.
- **variation, akse** — den ene ting reprotest ændrer mellem sine to builds.
- **reprotest** — værktøj der bygger to gange med én kontrolleret forskel og
  sammenligner resultatet. Skrevet til Debian; kører kun på Linux.
- **diffoscope** — værktøj der pakker to filer ud og forklarer hvad der adskiller
  dem, i læsbar form. reprotest kalder den ved forskel.
- **disorderfs** — filsystem der med vilje leverer filer i tilfældig rækkefølge.
  Det er dét reprotest bruger til `+fileordering`. Findes i apt, ikke på Arch.
- **umask** — masken der bestemmer hvilke rettigheder nye filer får.
- **locale** — sprog- og tegnsætsindstillingen, f.eks. `da_DK.UTF-8`.
- **RID** — runtime identifier, den platformstreng SDK'en identificerer sig med
  (`linux-x64`, `arch-x64`).
- **rollForward: disable** — linjen i `global.json` der forbyder `dotnet` at
  bruge en anden SDK-version end den angivne.
- **PathMap** — indstillingen der kan erstatte den absolutte byggesti med en fast
  streng. Ikke brugt her; først skal problemet ses.
