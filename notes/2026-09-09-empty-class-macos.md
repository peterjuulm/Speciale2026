# Eksperiment 1 på macOS: det tredje miljø

Køres 9. september 2026 på `mac` (Peters laptop, Apple Silicon). Samme
laboratorium og samme tre filer som [7. september](2026-09-07-empty-class.md);
ordlisten står dér. Protokollen herunder er den macOS-specifikke udgave og kan
læses alene.

Data: `data/2026-09-09-empty-class/macos/`.

Spørgsmålet: **kommer `4b3808d1…` ud på et tredje styresystem og en anden
CPU-arkitektur?**

## Hvorfor det er værd at køre nu

[Compiler-identity](2026-09-08-compiler-identity.md) viste at outputtet bestemmes
af SDK'en og ikke af maskinen: Microsofts 9.0.120 på Leos Arch-maskine gav Peters
præcise bytes, mens kerne, distribution, glibc og `LANG` forblev Leos. Men begge
de to hidtidige miljøer er **Linux på x64**. Hypotesen fra 7. september — at det
managede lag bærer på tværs af styresystemer, fordi en klassebiblioteks-DLL kun
indeholder IL — er dermed stadig ikke prøvet mod noget andet end Linux.

`mac` er den prøve. To ting ændrer sig på én gang i forhold til `ubuntu-vm`:

| | `ubuntu-vm` | `mac` |
| --- | --- | --- |
| Styresystem | Ubuntu 24.04 | macOS 14.6 (Darwin 23.6.0) |
| CPU | x86-64 | arm64 (Apple Silicon) |
| RID | `linux-x64` | `osx-arm64` |

To akser ad gangen er normalt en dårlig idé. Her er det forsvarligt, fordi
udfaldet kun har to interessante værdier: rammer hashen, er begge akser udelukket
i samme kørsel. Rammer den ikke, er kørslen ikke konklusionen men startskuddet —
så skal de skilles ad.

## Kontrollen der afgør om målingen overhovedet svarer

`csc.dll` **skal** være `644a4d336dcd11a7…` — samme fil som på `ubuntu-vm` og
samme fil som Microsofts SDK gav på `arch`.

Roslyn-oversætteren i `Roslyn/bincore` er en manageret assembly og bør derfor
være de samme bytes i alle Microsofts SDK'er uanset RID. Bør. Er den det ikke,
har vi målt en tredje oversætter, og så siger kørslen intet om OS og CPU — den
gentager bare fundet fra 8. september i en ny variant. Hashen tages derfor
**før** byggeriet, ikke efter.

## Forventning, skrevet før kørslen

| Hvad | Forventet |
| --- | --- |
| `sources.txt`, tre filer | `2a766d57…` `079f65f3…` `8628a3a4…` |
| `csc.dll` | `644a4d336dcd11a7…` (som `ubuntu-vm`) |
| `minlib.dll`, build 1 | `4b3808d1cc1d642577f60a054905f5f065aab8b9aea1765b407fc583cef70d33` |
| `minlib.dll`, build 2 | som build 1 |

Kommer der andre tal ud, er det et fund og ikke en fejl. Afsnittet **Sådan læses
udfaldet** nederst siger hvad hvert af dem betyder.

## Fire ting hvor macOS afviger fra Linux-protokollen

1. **`shasum -a 256` i stedet for `sha256sum`.** Samme algoritme, samme
   udskriftsformat, andet kommandonavn. Formatet er det samme, så
   `shasum -a 256 -c` kan læse Leos og VM'ens evidensfiler direkte.
2. **Ingen reprotest og ingen diffoscope.** Måling 2 (miljøakserne) kører ikke
   her; det er Linux-værktøj. `mac` bidrager med måling 1 og 3.
3. **`/private/tmp` findes allerede.** Ingen `sudo mkdir`. Til gengæld er det
   macOS' egen `/tmp`, og den ryddes af `periodic`-jobbet for filer der ikke er
   rørt i tre døgn. Laboratoriet kan altså være væk næste uge — kontrollér
   kildehashene igen inden en senere kørsel i stedet for at gå ud fra at mappen
   står som du forlod den.
4. **To `dotnet` på maskinen.** Systemets ligger i `/usr/local/share/dotnet`
   (SDK 9.0.102, host 9.0.1, verificeret 9/9). Den pinnede 9.0.120 lander i
   `~/.dotnet`, som ikke er på PATH. Samme problem som på VM'en, hvor apt havde
   sin egen — og samme løsning: navngiv den eksplicit i hver kommando.

## Trin 1: SDK'en, side om side

Arch-kørslen 8. september lagde Microsofts SDK ved siden af distributionens i
stedet for at erstatte den. Her gøres det samme, af samme grund: eksperimentet
tilføjer en SDK og fjerner ingen, så maskinen kan bruges til andet bagefter.

```bash
curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --version 9.0.120
```

Scriptet vælger `osx-arm64` af sig selv på Apple Silicon. **Lad det gøre det.**
Det er hele pointen med kørslen; `--architecture x64` ville give en
Rosetta-oversætter og måle noget andet.

Kontrollér at den bliver valgt når man peger på den. `Base Path` skal sige
`/Users/peterjuulmoller/.dotnet/sdk/9.0.120/`, og `Version:` skal sige `9.0.120`:

```bash
cd /private/tmp/rb1 && env PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="$HOME/.dotnet" dotnet --info | grep -E 'Version:|Base Path|RID'
```

Står der `9.0.102` eller `/usr/local/share/dotnet`, slog `PATH` ikke igennem, og
alt herefter måler den forkerte oversætter. Stop og find ud af hvorfor, før du
bygger.

## Trin 2: resultatmappen

zsh:

```bash
export UD=$HOME/Speciale2026/data/2026-09-09-empty-class/macos && mkdir -p "$UD" && echo $UD && ls -d "$UD"
```

Variablen forsvinder ved ny fane. Læg linjen i `~/.zshrc` så længe eksperimentet
kører. Er `$UD` tom, bliver `tee -a "$UD/hashes.txt"` til `tee -a /hashes.txt`
og fejler med `Permission denied`.

## Trin 3: laboratoriet

**Allerede oprettet og verificeret 9. september 2026, før kørslen.** De tre filer
står i `/private/tmp/rb1` med hashene `2a766d57…`, `079f65f3…`, `8628a3a4…`,
kontrolleret mod `arch`' egen evidensfil fra 8. september med `shasum -a 256 -c`.
Kontrollen er gemt i `data/2026-09-09-empty-class/macos/sources.txt`.

Skal laboratoriet genskabes — fordi macOS har ryddet `/private/tmp`, eller fordi
kørslen gentages på en anden maskine — er det de her fire kommandoer:

```bash
mkdir -p /private/tmp/rb1 && cd /private/tmp/rb1 && pwd -P
```

Der skal stå `/private/tmp/rb1`, ikke `/tmp/rb1`. Byggestien skrives ind i den
færdige DLL, så den skal være den samme fysiske streng som på de to andre
maskiner. `pwd -P` følger symlinket til ende.

```bash
printf '<Project Sdk="Microsoft.NET.Sdk">\n  <PropertyGroup>\n    <TargetFramework>net9.0</TargetFramework>\n  </PropertyGroup>\n</Project>\n' > /private/tmp/rb1/minlib.csproj
```

```bash
printf 'namespace Minlib;\n\npublic class Beregning\n{\n    public int Tal() => 42;\n}\n' > /private/tmp/rb1/Beregning.cs
```

```bash
printf '{\n  "sdk": {\n    "version": "9.0.120",\n    "rollForward": "disable"\n  }\n}\n' > /private/tmp/rb1/global.json
```

Og kontrollen, hvor gårsdagens evidensfil er dagens test:

```bash
cd /private/tmp/rb1 && shasum -a 256 -c "$HOME/Speciale2026/data/2026-09-08-empty-class-v2/arch/sources.txt"
```

Tre gange `OK`. Ellers: stop.

## Trin 4: miljøblokken, før målingen

Fra projektmappen, så `global.json` gælder — uden for `/private/tmp/rb1` beskriver
blokken en anden SDK end den der bygger:

```bash
cd /private/tmp/rb1 && env PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="$HOME/.dotnet" dotnet --info > "$UD/environment.txt"
```

Maskinen selv. `sw_vers` er macOS' svar på distributionsfilen og hører med, fordi
det er den akse kørslen prøver:

```bash
uname -srm >> "$UD/environment.txt"; sw_vers >> "$UD/environment.txt"; umask >> "$UD/environment.txt"; locale | head -1 >> "$UD/environment.txt"; command -v dotnet >> "$UD/environment.txt"; echo "$HOME/.dotnet/dotnet" >> "$UD/environment.txt"
```

Og oversætteren, som filer og ikke som versionsnummer — kontrollen fra afsnittet
ovenfor:

```bash
shasum -a 256 "$HOME/.dotnet/sdk/9.0.120/Roslyn/bincore/csc.dll" | tee -a "$UD/environment.txt"
```

Der skal stå `644a4d336dcd11a7…`. Gør der ikke det, så skriv tallet ned og læs
**Sådan læses udfaldet** før du bygger videre.

## Trin 5: måling 1, to rene builds

```bash
cd /private/tmp/rb1; rm -rf bin obj; env PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="$HOME/.dotnet" dotnet build -c Release; shasum -a 256 bin/Release/net9.0/minlib.dll | tee -a "$UD/hashes.txt"
```

```bash
cd /private/tmp/rb1; rm -rf bin obj; env PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="$HOME/.dotnet" dotnet build -c Release; shasum -a 256 bin/Release/net9.0/minlib.dll | tee -a "$UD/hashes.txt"
```

`rm -rf bin obj` og ikke bare `bin`: `bin/`-DLL'en er en kopi af `obj/`-DLL'en,
så uden `obj` med i oprydningen genbruger man forrige byg og måler ingenting.

Fejler byggeriet med `SDK 9.0.120 not found`, ramte kommandoen
`/usr/local/share/dotnet/dotnet`. Det er `rollForward: disable` der gør sit
arbejde, og fejlen er dermed en god nyhed: pinnet virker. Ret PATH og kør igen.

### Byggestien inde i binæren

```bash
cd /private/tmp/rb1 && env LC_ALL=C grep -ao '/[A-Za-z0-9_/.-]*rb1[A-Za-z0-9_/.-]*' bin/Release/net9.0/minlib.dll | sort -u
```

Der skal stå `/private/tmp/rb1/obj/Release/net9.0/minlib.pdb`. Står der
`/tmp/rb1/…`, blev der bygget gennem symlinket, og så kan hashen ikke ramme.

## Trin 6: gem det

```bash
cd ~/Speciale2026 && git add data notes && git commit -m "Experiment 1: empty class, macOS run" && git pull --rebase && git push
```

## Resultat

Kørt 9. september 2026.

| Hvad | Forventet | Målt på `mac` |
| --- | --- | --- |
| `sources.txt`, tre filer | `2a766d57…` `079f65f3…` `8628a3a4…` | verificeret |
| `csc.dll` | `644a4d336dcd11a7…` | **`1824569732a63f5d…`** — afveg |
| `minlib.dll`, build 1 | `4b3808d1…` | `4b3808d1…` |
| `minlib.dll`, build 2 | som build 1 | `4b3808d1…` |
| Indlejret PDB-sti | `/private/tmp/rb1/obj/…` | `/private/tmp/rb1/obj/Release/net9.0/minlib.pdb` |

SDK'en løste til `Base Path: /Users/peterjuulmoller/.dotnet/sdk/9.0.120/`,
`RID: osx-arm64`, host 9.0.19 — samme host som `ubuntu-vm`. Fuld blok i
`data/2026-09-09-empty-class/macos/environment.txt`.

## Fortolkning

**Begge dele på én gang: kontrollen faldt, og hashen ramte alligevel.**

Det udfald stod ikke i nogen af de tre kolonner ovenfor. Forventningen var at en
afvigende `csc.dll` ville betyde at vi målte en tredje oversætter og derfor ikke
kunne svare på OS-spørgsmålet. Den slutning var forkert, og det er kørslens
egentlige fund.

**1. Styresystem og CPU er udelukket.** Tre miljøer, to styresystemer, to
CPU-arkitekturer, ét tal. `minlib.dll` blev `4b3808d1…` på macOS 14.6 arm64 —
byte for byte det samme som på Ubuntu x86-64. Hypotesen fra 7. september holder:
det managede lag bærer på tværs. Det er det stærkeste resultat i projektet
indtil nu.

**2. Oversætterens bytes bestemmer ikke outputtet — dens erklærede identitet
gør.** Der findes nu tre `csc.dll` bag strengen `9.0.120`:

| | `csc.dll` | SDK Commit | MSBuild | Roslyn | `minlib.dll` |
| --- | --- | --- | --- | --- | --- |
| Arch-pakken | `1b7543aa…` | `d0558bff3d` | `+d0558bff3` | `+d0558bff…` (`dotnet/dotnet`) | `541bed82…` |
| Microsoft linux-x64 | `644a4d33…` | `3f97250e38` | `+07da1b9a8` | `+fc52718e…` (`dotnet/roslyn`) | `4b3808d1…` |
| Microsoft osx-arm64 | `1824569732a63f5d…` | `3f97250e38` | `+07da1b9a8` | `+fc52718e…` (`dotnet/roslyn`) | `4b3808d1…` |

De to nederste er **forskellige filer med identisk erklæret identitet** — hver
eneste streng er den samme, SDK-commit, MSBuild-commit, Roslyn-version,
commit-hash og host (`9.0.19` / `8381bdb01f`) — og de gav samme output. Den
øverste har andre strenge og gav et andet output. Det er identitetsstrengene der
følger med ud i artefaktet, ikke filens hash.

Det er den kontrafaktiske sag 8. september ikke kunne levere.

Compiler-identity gjorde det rigtige indgreb: Microsofts 9.0.120 hentet ned ved
siden af Arch-pakken, samme pin, samme sti, samme maskine. Den kørsel afgjorde at
**SDK'en** bestemmer outputtet og ikke maskinen. Men den kunne ikke afgøre
*hvilken egenskab ved SDK'en* der gør det, og grunden står i dens egen
`compilers.txt`: Microsofts `csc.dll` på `arch` var `644a4d33…` — **byte-identisk**
med VM'ens. Bytes og strenge fulgtes ad og passede begge. To forklaringer —
"oversætterens bytes bestemmer" og "oversætterens erklærede identitet bestemmer"
— forudsiger derfor begge `4b3808d1…` for den kørsel. Den bekræfter dem begge og
adskiller dem ikke.

`osx-arm64` er det første tilfælde hvor de to forklaringer forudsiger noget
forskelligt: samme strenge, andre bytes. Byte-forklaringen forudsiger en ny hash,
identitetsforklaringen forudsiger `4b3808d1…`. Der kom `4b3808d1…`.

Forventningsafsnittet i dette notat fulgte i øvrigt byte-forklaringen — kørslen
var gated på at `csc.dll` skulle være `644a4d33…`, og et afvig var på forhånd
skrevet ned som "så måler vi en tredje oversætter og kan ikke svare på
OS-spørgsmålet". Det var forkert, og det står deroppe som det blev skrevet.

Mekanismen bag byteforskellen er sandsynligvis ReadyToRun: `csc.dll` på `mac`
indeholder en `RTR`-signatur, altså AOT-oversat native kode, og den er
arkitekturspecifik. Samme IL og samme metadata, forskelligt native lag. Det
forklarer hvorfor filerne kan afvige uden at outputtet gør.

### Hvad det retter i konklusionen fra 8. september

[Compiler-identity](2026-09-08-compiler-identity.md) og
[dagens fund](2026-09-08-dagens-fund.md) konkluderede at "bit-identitet er
strengere end kode-identitet", og at .NET's deterministiske byg binder
artefaktets identitet til **oversætterens identitet** forstået som dens bytes.
Formuleringen skal strammes:

- **Kravet er ikke bit-identisk oversætterbinær.** Det er demonstreret her: en
  anden binær ramte samme artefakt. Kravet er samme Roslyn-version **og** samme
  commit-hash, som er de strenge der skrives ind i PDB'en.
- **Konsekvensen for en distribution står ved magt, men af en anden grund.** Arch
  kan ikke ramme Microsofts artefakter — ikke fordi de byggede en anden binær,
  men fordi de byggede fra et andet kildetræ og derfor stempler en anden
  commit-streng ind. Byggede de fra `dotnet/roslyn` på samme commit, tyder
  resultatet her på at de kunne ramme, uanset at binæren ville afvige.
- **Forbeholdet fra 8/9 om mekanismen er dermed indfriet på ét punkt og skærpet
  på et andet.** Det var korrekt at Roslyns deterministiske hash inddrager
  oversætterens identitet. Det var forkert at læse "identitet" som "bytes".

Det er stadig en observation og ikke en aflæsning af Roslyns kilde. Men den
hviler nu på tre oversættere og tre kørsler i stedet for to, og den ene af de tre
er netop det kontrafaktiske tilfælde der skiller de to forklaringer ad.

### Forbehold

- **R2R er sluttet, ikke verificeret mod Linux-filen.** `RTR`-signaturen er målt i
  `mac`-udgaven; at Linux-udgaven har den samme med x64-kode i stedet, er
  antaget. Det afgøres ved at hashe IL-delen af begge filer, ikke hele filen.
- **Kun én commit prøvet.** At samme commit giver samme output, er vist for
  `fc52718e…` på to platforme. Om det generaliserer, er ikke prøvet.
- **Host og RID fulgtes ad med SDK'en igen.** `Host: 9.0.19` er tilfældigvis den
  samme som `ubuntu-vm`, så host-versionen er stadig ikke uafhængigt udelukket —
  den er bare ikke længere mistænkt, da alt andet varierede omkring den.
- Samme afgrænsninger som 7. september: kun `dotnet build`, ingen pakning, ingen
  arkiver, ingen afhængigheder, én tom klasse.

## Sådan læses udfaldet

**`csc.dll` rammer, og `minlib.dll` bliver `4b3808d1…`.** Det stærkeste resultat
i projektet indtil nu: tre miljøer, to styresystemer, to CPU-arkitekturer, ét
tal. Så er hypotesen fra 7. september bekræftet — det managede lag bærer på
tværs, når oversætterbinæren er den samme — og formuleringen bliver skarp:
artefaktets identitet følger oversætteren, ikke maskinen. Det er også det
argument der skal bære videre til det rigtige artefakt, for det er præcis den
egenskab en leverandør-uafhængig verifikation ville hvile på.

**`csc.dll` rammer, men `minlib.dll` bliver noget tredje.** Så er OS eller CPU i
spil alligevel, og kørslen har to akser i sig. Næste skridt er at skille dem ad,
og det billigste sted er CPU'en: installér `--architecture x64` ved siden af og
byg igen på samme sti. Rammer *den* `4b3808d1…`, var det arkitekturen; gør den
ikke, er det styresystemet. Sammenlign i begge tilfælde miljøblokkene linje for
linje — `Host Version` er en kendt kandidat, fordi den aldrig er blevet
uafhængigt udelukket (se forbeholdene i
[compiler-identity](2026-09-08-compiler-identity.md)).

**`csc.dll` rammer ikke.** Så er kørslen ikke en OS-test. Microsoft udgiver i så
fald forskellige oversætterbytes per RID under samme versionsnummer, og *det* er
i sig selv et fund — en tredje binær bag strengen `9.0.120`, oven i de to vi
allerede har. Skriv hashen ned, kør byggeriet alligevel, og hold de to resultater
adskilt: den ene siger noget om SDK-udgivelse, den anden intet om OS.

## Hvad vi ikke måler her

- **Miljøakserne.** reprotest kører ikke på macOS. `mac` bidrager med måling 1 og
  3; akserne ligger i [environment-axes](2026-09-09-environment-axes.md).
- **Systemets egen 9.0.102.** Den bliver stående og bliver ikke målt. Havde vi
  bygget med den, ville vi måle en fjerde oversætter.
- Samme afgrænsninger som 7. september: kun `dotnet build`, ingen pakning, ingen
  arkiver, ingen afhængigheder, én tom klasse.
