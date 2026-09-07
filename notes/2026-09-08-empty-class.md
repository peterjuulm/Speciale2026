# Eksperiment 1: tom klasse, tre miljøer

Dato: 8. september 2026.

Spørgsmålet: samme kildekode, oversat to gange — kommer de samme bytes ud?

Vi bruger en tom klasse med vilje. Én fil, ingen pakker, intet der kan gå galt
af andre grunde. Er den ikke reproducerbar, er intet større det. Ordlisten
nederst forklarer termerne.

## Tre miljøer

| Mærkat | Maskine | Kører | Resultatmappe |
|---|---|---|---|
| `arch` | Leos laptop, Arch Linux | måling 1, 2, 3 | `~/Dev/Speciale2026/data/2026-09-08-empty-class/leo` |
| `mac` | Peters laptop, macOS | ikke med i første kørsel | `~/Dev/Speciale2026/data/2026-09-08-empty-class/peter` |
| `vm` | delt Ubuntu 24.04, DigitalOcean | måling 1, 2, 3 | `.../data/2026-09-08-empty-class/vm-ubuntu` |

**Første kørsel:** Leo tager `arch`, Peter tager `vm`. `mac` gemmer vi til
senere; kommandoerne står stadig i teksten, så den kan køres uden at protokollen
skal skrives om.

Repoet er klonet på alle tre maskiner, så hver maskine skriver direkte i sin
egen undermappe under `data/2026-09-08-empty-class/`. Ingen filer flyttes
bagefter.

Kommandoerne herunder gælder **Linux (`arch` og `vm`)**. Hvor macOS afviger, står
en `mac`-variant under. Resultatmappen hedder `$UD` i alle kommandoer; den sættes
i trin 1.

## Tre målinger

1. **To builds på samme maskine** — siger om apparatet virker. Alle tre miljøer.
2. **Miljøvariationer med reprotest** — hvilke forskelle kan byggeriet tåle?
   `arch` og `vm`; reprotest er Linux-værktøj og kører ikke på mac. `vm` kan én
   akse mere end `arch`, fordi `disorderfs` findes i apt.
3. **Hashene sammenlignet på tværs** — er resultatet ens i tre miljøer?

`arch` mod `mac` er den interessante sammenligning: to styresystemer, to
CPU-arkitekturer, ukontrolleret variation. `vm` er det kontrollerede miljø og et
tredje datapunkt — den erstatter ikke laptop-sammenligningen. Kører vi alt på
VM'en, måler vi ét miljø tre gange, og spørgsmålet forsvinder.

---

## Trin 0: aftal to ting først

**Samme SDK-version: 9.0.120.** Den matcher WS.Phoenix' CI (`9.0.x`), og Leo har
den allerede. Har vi forskellige oversættere, kan en forskel i måling 3 forklares
på tre måder, og så lærer vi ingenting. Tjek:

```bash
dotnet --list-sdks
```

**Samme sti.** Byggestien bliver skrevet ind i den færdige DLL, så den skal være
identisk. På macOS er `/tmp` et symlink til `/private/tmp`, og bygger Peter i
`/tmp/rb1`, kan der stå `/private/tmp/rb1` inde i hans fil. Derfor bruger vi den
rigtige sti alle tre steder. På `arch` og `vm`, én gang:

```bash
sudo mkdir -p /private/tmp && sudo chmod 1777 /private/tmp
```

## Trin 1: opsætning, én gang per maskine

**`arch`** — reprotest og diffoscope er installeret. `dpkg` findes ikke, og
reprotest dør uden, fordi den spørger om maskinens arkitektur:

```bash
mkdir -p ~/.local/bin; printf '#!/bin/sh\ncase "$1" in --print-architecture) echo amd64 ;; esac\nexit 0\n' > ~/.local/bin/dpkg; chmod +x ~/.local/bin/dpkg
```

**`vm`** — opdatér først, ellers beskriver miljøblokken en maskine der ikke
længere findes:

```bash
sudo apt update && sudo apt upgrade -y && sudo reboot
```

Så hjælpeværktøjerne. `disorderfs` er den vi ikke har på Arch:

```bash
sudo apt install -y diffoscope disorderfs faketime pipx
```

reprotest installeres med pipx og ikke med apt, så `vm` og `arch` kører **samme
version af instrumentet**. To reprotest-versioner er to måleapparater, og så kan
tabellerne ikke lægges ved siden af hinanden:

```bash
pipx install reprotest==0.7.32 && pipx ensurepath
```

0.7.32 er den version `arch` målte med (verificeret 7/9 2026). `pipx install
reprotest` uden version giver den nyeste, og så er de to tabeller ikke fra samme
instrument.

SDK'en i præcis den version `global.json` kræver — apt giver en anden patch:

```bash
curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --version 9.0.120
```

Den lander i `~/.dotnet`, som ikke er på PATH. Læg linjen i din shell-profil, så
den også gælder næste gang:

```bash
export PATH="$HOME/.dotnet:$PATH"
```

Lav en almindelig bruger hver i stedet for at dele `root`, så kørslerne kan
skelnes fra hinanden.

**`mac`** — intet at installere ud over `dotnet` (version 9.0.120) og `git`.

**Alle tre** — sæt resultatmappen som `$UD`, så resten af kommandoerne er ens.
Ret `leo` til `peter` eller `vm-ubuntu` efter hvilken maskine du sidder ved.
I bash og zsh:

```bash
export UD=~/Dev/Speciale2026/data/2026-09-08-empty-class/leo && mkdir -p $UD
```

I fish:

```bash
set -gx UD ~/Dev/Speciale2026/data/2026-09-08-empty-class/leo; mkdir -p $UD
```

Variablen forsvinder når du åbner en ny fane. Sæt den igen, eller læg linjen i
din shell-profil så længe eksperimentet kører.

## Trin 2: projektet, tre filer skrevet i hånden

Vi bruger ikke `dotnet new`. Den skabelon følger SDK-versionen, så to forskellige
SDK'er kan lave forskellig kildekode — og så måler vi skabelonen i stedet for
oversætteren.

Mappen, og en kontrol af at det er den samme *fysiske* sti. `pwd -P` følger
symlinks til ende:

```bash
mkdir -p /private/tmp/rb1 && cd /private/tmp/rb1 && pwd -P
```

Der skal stå `/private/tmp/rb1` i alle tre miljøer. Gør der ikke det: stop.

Projektfilen:

```bash
printf '<Project Sdk="Microsoft.NET.Sdk">\n  <PropertyGroup>\n    <TargetFramework>net9.0</TargetFramework>\n  </PropertyGroup>\n</Project>\n' > /private/tmp/rb1/minlib.csproj
```

Kildekoden:

```bash
printf 'namespace Minlib;\n\npublic class Beregning\n{\n    public int Tal() => 42;\n}\n' > /private/tmp/rb1/Beregning.cs
```

SDK-låsen:

```bash
printf '{\n  "sdk": {\n    "version": "9.0.120",\n    "rollForward": "disable"\n  }\n}\n' > /private/tmp/rb1/global.json
```

Kontrollér at pinnet virker, før du bygger noget. `dotnet --version` slår
`global.json` op fra den mappe du står i:

```bash
cd /private/tmp/rb1 && dotnet --version
```

Der skal stå `9.0.120`. Står du uden for mappen, får du din nyeste SDK i stedet —
på Leos maskine 10.0.111. Det er hele forskellen, og den er nem at overse.

Bekræft at det er den rigtige fil der bliver fundet:

```bash
cd /private/tmp/rb1 && dotnet --info | grep -A 1 'global.json file'
```

Der skal stå `/private/tmp/rb1/global.json`. Står der `Not found`, ligger filen
forkert, og så bygger du med en anden oversætter uden at få det at vide.

Med `rollForward: disable` fejler byggeriet i øvrigt tydeligt hvis 9.0.120 ikke er
installeret — det er meningen. Et byg der lykkes er derfor i sig selv et bevis på
at pinnet blev respekteret.

Kontrollér til sidst at vi har præcis de samme bytes:

```bash
cd /private/tmp/rb1 && sha256sum minlib.csproj Beregning.cs global.json
```

`mac` — samme algoritme, andet kommandonavn:

```bash
cd /private/tmp/rb1 && shasum -a 256 minlib.csproj Beregning.cs global.json
```

Forventet:

| Fil | sha256 |
|---|---|
| `minlib.csproj` | `2a766d57249ab657b48234557ff2c6a76...` |
| `Beregning.cs` | `079f65f3d3a0c041bb61817e68762b5a6...` |
| `global.json` | `8628a3a4483b68445847707e60dd11611...` |

Hashen på `global.json` gælder version 9.0.120. Vælger vi en anden, ændrer den
sig — men de tre tal skal være ens i alle tre miljøer. Det er den egentlige kontrol.

## Trin 3: miljøblokken, før målingen

Byggemiljøet er alt uden om kildekoden der kan påvirke resultatet: SDK-version,
styresystem, sprogindstillinger, filrettigheder, versionen af måleværktøjet. Den
skal skrives ned *før* vi måler. Viser måling 3 en forskel, er det den her blok
der siger hvorfor.

`dotnet --info` skal køres **fra projektmappen**, ikke fra resultatmappen. Uden
for `/private/tmp/rb1` gælder `global.json` ikke, og så beskriver blokken en anden
SDK end den der bygger:

```bash
cd /private/tmp/rb1 && dotnet --info > $UD/environment.txt
```

Maskinen selv:

```bash
uname -srm >> $UD/environment.txt; umask >> $UD/environment.txt; locale | head -1 >> $UD/environment.txt; diffoscope --version >> $UD/environment.txt 2>&1; pipx list >> $UD/environment.txt 2>&1
```

Og oversætteren, som filer og ikke som versionsnummer:

```bash
cd /private/tmp/rb1 && sha256sum "$(dotnet --info | awk '/Base Path/ {print $3}')Roslyn/bincore/csc.dll" >> $UD/environment.txt
```

`umask` og `locale` er to af de akser reprotest varierer i måling 2, så de skal
stå i blokken for at tabellen kan læses bagefter. `pipx list` fanger
reprotest-versionen. Og `csc.dll` er selve C#-oversætteren: hashen af den er det
eneste der faktisk identificerer hvad der byggede — versionsnummeret er en
streng.

## Trin 4: måling 1, to builds på samme maskine

Den kedelige kontrol. Byg, og skriv hashen ned:

```bash
cd /private/tmp/rb1; dotnet build -c Release; sha256sum bin/Release/net9.0/minlib.dll | tee -a $UD/hashes.txt
```

`mac`:

```bash
cd /private/tmp/rb1; dotnet build -c Release; shasum -a 256 bin/Release/net9.0/minlib.dll | tee -a $UD/hashes.txt
```

Og igen, med `rm -rf bin obj` foran, så det er et rent byg og ikke genbrug af
sidste gang:

```bash
cd /private/tmp/rb1; rm -rf bin obj; dotnet build -c Release; sha256sum bin/Release/net9.0/minlib.dll | tee -a $UD/hashes.txt
```

**Forventet:** to ens hashes. Oversætteren vakler ikke af sig selv.

Afviger de: stop. Så er der noget i opsætningen, og måling 2 vil bare vise støj.

### Se byggestien inde i binæren

Værd at gøre i alle tre miljøer. Det viser med egne øjne den mekanisme måling 2
handler om:

```bash
cd /private/tmp/rb1 && env LC_ALL=C grep -ao '/[A-Za-z0-9_/.-]*rb1[A-Za-z0-9_/.-]*' bin/Release/net9.0/minlib.dll | sort -u
```

Der står den absolutte sti skrevet ind i den oversatte fil — en henvisning til
PDB-filen. Det er derfor to mapper giver to forskellige DLL'er, selvom koden er ens.

## Trin 5: måling 2, miljøvariationer (`arch` og `vm`)

reprotest bygger projektet to gange, ændrer præcis én ting mellem de to builds,
og sammenligner resultatet. Er der forskel, kalder den diffoscope, som forklarer
*hvad* der afviger i stedet for bare at sige at bytes ikke matcher.

Ryd først, ellers kopierer reprotest gammelt byggeoutput med ind i sin testmappe:

```bash
rm -rf /private/tmp/rb1/bin /private/tmp/rb1/obj
```

Stil dig i resultatmappen, så logfilerne lander rigtigt. reprotest bygger i sin
egen midlertidige mappe, så byggeriet foregår ikke her:

```bash
cd $UD
```

`--vary=-all` betyder "variér ingenting". `--vary=-all,+umask` betyder "variér
kun umask". Én akse ad gangen, så et udfald altid har præcis én forklaring.

Omdirigér altid til fil. Piper du outputtet, ser det ud som om reprotest hænger i
mange minutter, fordi den efterlader en barneproces der holder forbindelsen åben
efter at den selv er stoppet.

Ingen variation:

```bash
reprotest --vary=-all -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-1-none.log 2>&1
```

Filrettigheder:

```bash
reprotest --vary=-all,+umask -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-2-umask.log 2>&1
```

Sprog og tegnsæt:

```bash
reprotest --vary=-all,+locales -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-3-locales.log 2>&1
```

Hvor værktøjerne findes (PATH):

```bash
reprotest --vary=-all,+exec_path -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-4-exec_path.log 2>&1
```

Byggestien:

```bash
reprotest --vary=-all,+build_path -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-5-build_path.log 2>&1
```

Klokken:

```bash
reprotest --vary=-all,+time -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-6-time.log 2>&1
```

**Kun `vm`** — filrækkefølge på disken. Aksen kræver `disorderfs`, som ikke
findes på Arch. Det er den akse der hidtil har stået som "ikke testet":

```bash
reprotest --vary=-all,+fileordering -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-7-fileordering.log 2>&1
```

Regn med 60-90 sekunder per kørsel, længere på VM'en hvis den kun har én vCPU.
Hele tabellen på én linje:

```bash
grep -H -E 'Reproduction (successful|failed)' rt-*.log
```

**Forventet:** `successful` på alle akser undtagen `+build_path`.

Grunden er hele specialet i miniature: DLL'en indeholder en henvisning til sin
PDB-fil, og den henvisning er en absolut sti. Bygger du i en anden mappe, står
der en anden sti inde i DLL'en, og så er den ikke bit-identisk, selvom koden er ens.

Diffoscopes forklaring:

```bash
grep -B 3 -A 12 'pdb' rt-5-build_path.log
```

Fejler en akse vi ikke ventede, er logfilen svaret. Det er derfor de skal med i
repoet.

## Trin 6: måling 3, tre miljøer sammenlignet

Ingen nye kommandoer. Vi sammenligner `hashes.txt` og `environment.txt` fra de
tre maskiner.

Hypotesen er at styresystemet ikke betyder noget: en DLL fra et klassebibliotek
indeholder IL — den mellemkode .NET oversætter til, som er uafhængig af
processortype. Med samme oversætter og samme sti *bør* resultatet være
bit-identisk på tværs af Linux og macOS, også når den ene maskine er x64 og den
anden arm64. Om det holder, ved vi ikke. Det er derfor det er værd at måle.

- **Ens hashes:** det managede lag bærer på tværs af styresystemer. Et resultat
  der kan citeres, og grundlaget for at gå videre til det rigtige artefakt.
- **Forskellige hashes:** sammenlign miljøblokkene linje for linje og find den
  der afviger. Så er næste kørsel den samme opskrift med den ene forskel lukket
  — én variabel ad gangen, intet andet.

**Målt på `arch` 7. september 2026:**

| Hvad | sha256 |
|---|---|
| `minlib.dll`, to rene builds | `541bed823d12e42b5e9e6087c9c32a9d6fbaa9a116aae61fc00c808231e74113` (ens begge gange) |
| `csc.dll` fra SDK 9.0.120 | `1b7543aa709363b6f05273134f8c501b392ebb7480689008a1cc880ae8c38212` |

SDK'en var Arch-pakken `dotnet-sdk-9.0 9.0.19.sdk120-1`, reprotest 0.7.32,
diffoscope 329, `LANG=da_DK.UTF-8`, `umask 0022`, kernel 7.1.8-arch1-3.
Fuld blok i `data/2026-09-08-empty-class/leo/environment.txt`.

`arch` mod `vm` er første kørsels egentlige sammenligning: to Linux-maskiner,
samme arkitektur, samme SDK-versionsnummer. Og her er der en god chance for at
hashene afviger, af en grund der er værd at forstå.

**Samme versionsnummer er ikke samme oversætter.** Arch bygger .NET fra kilde;
Leos SDK kommer fra pakken `dotnet-sdk-9.0 9.0.19.sdk120-1` og ligger i
`/usr/share/dotnet`. Peters kommer fra Microsofts `dotnet-install.sh` og er
Microsofts egen binære udgivelse. Begge kalder sig 9.0.120.

Afviger DLL'erne, er `csc.dll`-hashen fra miljøblokken det første sted at se: er
den forskellig, har vi målt to forskellige oversættere, ikke to forskellige
miljøer. Det er i øvrigt præcis det gab specialet handler om — en version er en
selvdeklareret streng, ikke en binding til en binær — dukket op i vores eget
måleapparat.

## Trin 7: gem det, fra hver maskine

Hver maskine committer sin egen mappe. Tre maskiner på samme branch betyder at
`git pull --rebase` skal køres før push, hver gang:

```bash
cd ~/Dev/Speciale2026 && git add data notes && git commit -m "Experiment 1: empty class, arch run" && git pull --rebase && git push
```

Ret beskeden til `mac run` eller `vm run` efter hvilken maskine du sidder ved.

På VM'en: sæt `user.name` og `user.email` for din egen bruger, ellers står der
`root@ubuntu-...` i historikken på et offentligt repo, og så kan man ikke se hvem
der kørte hvad:

```bash
git config --global user.name "Dit Navn" && git config --global user.email "din@mail.dk"
```

---

## Resultatskema

Udfyldes mens vi kører. Det er de her tal notatet skal indeholde.

| Måling | Varierer | Forventet | `arch` | `mac` | `vm` |
|---|---|---|---|---|---|
| 1 — to builds | ingenting | samme hash | samme | | |
| 2 — rt-1-none | ingenting | successful | | n/a | |
| 2 — rt-2-umask | filrettigheder | successful | | n/a | |
| 2 — rt-3-locales | sprog, tegnsæt | successful | | n/a | |
| 2 — rt-4-exec_path | PATH | successful | | n/a | |
| 2 — rt-5-build_path | byggemappen | failed | | n/a | |
| 2 — rt-6-time | klokken | successful | | n/a | |
| 2 — rt-7-fileordering | filrækkefølge | ukendt | n/a | n/a | |
| 3 — DLL-hash | OS, CPU, distro | ukendt | `541bed82…` | | |

## Hvad vi ikke måler

- **Pakkelaget.** Kun `dotnet build`, ikke `dotnet pack`. Pakning har sine egne
  kilder til støj, og de hører i et senere eksperiment.
- **Peters miljøvariationer på hans egen maskine.** reprotest kører ikke på mac.
  Hans bidrag er måling 1 og 3; VM'en dækker variationerne.
- **Containeren.** VM'en er et miljø vi har klikket os frem til, ikke et der er
  beskrevet som data. Et fastlåst image er næste skridt, ikke det her.
- **Rigtig software.** En tom klasse har ingen afhængigheder, ingen frontend og
  ingen native biblioteker. Det er baselinen, ikke resultatet.

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
- **byggemiljø** — alt uden om kildekoden der kan påvirke resultatet:
  SDK-version, styresystem, sprogindstillinger, filrettigheder, klokken, byggestien.
- **variation, akse** — den ene ting reprotest ændrer mellem sine to builds.
- **reprotest** — værktøj der bygger to gange med én kontrolleret forskel og
  sammenligner resultatet. Skrevet til Debian; kører kun på Linux.
- **diffoscope** — værktøj der pakker to filer ud og forklarer hvad der adskiller
  dem, i læsbar form. reprotest kalder den automatisk ved forskel.
- **disorderfs** — filsystem der med vilje leverer filer i tilfældig rækkefølge.
  Det er dét reprotest bruger til `+fileordering`. Findes i apt, ikke på Arch.
- **umask** — masken der bestemmer hvilke rettigheder nye filer får.
- **locale** — sprog- og tegnsætsindstillingen, f.eks. `da_DK.UTF-8`.
- **rollForward: disable** — linjen i `global.json` der forbyder `dotnet` at
  bruge en anden SDK-version end den angivne. Mangler versionen, fejler
  byggeriet tydeligt i stedet for stilfærdigt at bruge en anden oversætter.
- **PathMap** — indstillingen der senere kan erstatte den absolutte byggesti med
  en fast streng. Vi bruger den ikke her; først skal vi se problemet.
