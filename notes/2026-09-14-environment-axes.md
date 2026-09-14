# Eksperiment 2: miljøvariationer

Kørt 14. september 2026 på `arch` (Leos laptop, 14:13-14:15 CEST) og
`ubuntu-vm` (delt droplet, 14:14-14:16 CEST). Protokollen blev skrevet 8.-9.
september og lå to dage før den blev kørt.
Bygger videre på [empty-class](2026-09-07-empty-class.md) — samme laboratorium,
samme tre filer, samme pinnede SDK. Termerne står i ordlisten dér.

Data: `data/2026-09-14-environment-axes/arch/` og `.../ubuntu-vm/`.

Spørgsmålet: **hvilke forskelle i byggemiljøet tåler byggeriet?**

Eksperiment 1 viste at to builds i det samme miljø giver samme bytes. Det siger
intet om hvad der sker når miljøet ændrer sig. reprotest bygger to gange og
ændrer præcis én ting imellem — filrettigheder, sprog, PATH, byggemappe, klokken,
filrækkefølge — og sammenligner resultatet. Én akse per kørsel, så et udfald
altid har præcis én forklaring.

## Forventning, skrevet før kørslen

Alt `successful` undtagen `+build_path`, som falder. DLL'en indeholder en
henvisning til sin PDB-fil, og den henvisning er en absolut sti; bygger man i en
anden mappe, står der en anden streng inde i binæren.

`+fileordering` er ukendt: den kræver `disorderfs` og kan kun køre på
`ubuntu-vm`, så den er aldrig målt.

`+umask` og `+locales` forventes grønne — men bemærk hvorfor. Rettigheder og
filrækkefølge er præcis det zip- og tar-arkiver gemmer, og her produceres ingen
arkiver, kun løse filer. En DLL gemmer hverken rettigheder eller rækkefølge. De
grønne felter er altså betingede af at der ikke er et pakketrin, og det skal
stå i konklusionen.

## Før kørslen

Laboratoriet fra 7/9 skal stå, og byggeoutput fra i går skal væk — ellers
kopierer reprotest det med ind i sin testmappe:

```bash
rm -rf /private/tmp/rb1/bin /private/tmp/rb1/obj
```

Resultatmappen. Klonen ligger i `~/Dev/Speciale2026` på laptops og i
`~/Speciale2026` på VM'en:

```bash
export UD=$HOME/Speciale2026/data/2026-09-14-environment-axes/ubuntu-vm && mkdir -p "$UD"
```

`arch` bruger fish:

```bash
set -gx UD $HOME/Dev/Speciale2026/data/2026-09-14-environment-axes/arch; mkdir -p $UD
```

Miljøblokken optages igen — det er en ny dag og et nyt eksperiment, og på
`ubuntu-vm` er der tilføjet 2 GB swap siden i går:

```bash
cd /private/tmp/rb1 && dotnet --info > "$UD/environment.txt"
```

```bash
uname -srm >> "$UD/environment.txt"; umask >> "$UD/environment.txt"; locale | head -1 >> "$UD/environment.txt"; diffoscope --version >> "$UD/environment.txt" 2>&1; command -v dotnet reprotest diffoscope >> "$UD/environment.txt"
```

Og kontrollen af at det er de rigtige binærer der bliver fundet:

```bash
cd /private/tmp/rb1 && command -v dotnet reprotest diffoscope; dotnet --version; diffoscope --version
```

Forventet på `arch`: `/usr/bin/dotnet`, `9.0.120`, `diffoscope 329`, reprotest fra
`~/.local/bin`. Forventet på `ubuntu-vm`: `/root/.dotnet/dotnet`,
`/root/.local/bin/reprotest`, `/root/.local/bin/diffoscope`, `9.0.120`, `329`.

**På `ubuntu-vm` navngives binærerne med fuld sti i selve kørslen.** apt har sine
egne udgaver i `/usr/bin` — `dotnet` med SDK 10.0.111, reprotest 0.7.26,
diffoscope 259 — og de rigtige findes kun forrest i PATH fordi `~/.bashrc`
sætter dem der. `~/.bashrc` læses ikke af ikke-interaktive shells, og det er dem
reprotest bygger i. Rammer byggekommandoen `/usr/bin/dotnet`, fejler den med
"SDK 9.0.120 not found", og fejlen ser ud som et reprotest-problem.
`+exec_path`-aksen manipulerer desuden PATH med vilje.

## Kørslerne

Stil dig i resultatmappen, så logfilerne lander rigtigt. reprotest bygger i sin
egen midlertidige mappe, så byggeriet foregår ikke her:

```bash
cd "$UD"
```

Omdirigér altid til fil. Piper man outputtet, ser det ud som om reprotest hænger
i mange minutter: den efterlader en barneproces der holder forbindelsen åben
efter at den selv er stoppet. Regn med 60-90 sekunder per kørsel, længere på
VM'en.

`arch`:

```bash
reprotest --vary=-all -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-1-none.log 2>&1
```

`ubuntu-vm` — samme kørsel, fulde stier:

```bash
/root/.local/bin/reprotest --vary=-all -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 /root/.dotnet/dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-1-none.log 2>&1
```

De øvrige akser, `arch`:

```bash
reprotest --vary=-all,+umask -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-2-umask.log 2>&1
```

```bash
reprotest --vary=-all,+locales -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-3-locales.log 2>&1
```

```bash
reprotest --vary=-all,+exec_path -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-4-exec_path.log 2>&1
```

```bash
reprotest --vary=-all,+build_path -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-5-build_path.log 2>&1
```

```bash
reprotest --vary=-all,+time -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-6-time.log 2>&1
```

Og `ubuntu-vm`, hvor `+fileordering` kommer til:

```bash
/root/.local/bin/reprotest --vary=-all,+umask -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 /root/.dotnet/dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-2-umask.log 2>&1
```

```bash
/root/.local/bin/reprotest --vary=-all,+locales -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 /root/.dotnet/dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-3-locales.log 2>&1
```

```bash
/root/.local/bin/reprotest --vary=-all,+exec_path -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 /root/.dotnet/dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-4-exec_path.log 2>&1
```

```bash
/root/.local/bin/reprotest --vary=-all,+build_path -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 /root/.dotnet/dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-5-build_path.log 2>&1
```

```bash
/root/.local/bin/reprotest --vary=-all,+time -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 /root/.dotnet/dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-6-time.log 2>&1
```

```bash
/root/.local/bin/reprotest --vary=-all,+fileordering -c 'env DOTNET_CLI_HOME=/tmp/dch DOTNET_NOLOGO=1 /root/.dotnet/dotnet build -c Release' /private/tmp/rb1 'bin/Release/net9.0/minlib.dll' > rt-7-fileordering.log 2>&1
```

`+fileordering` kan kun køre der, fordi den kræver `disorderfs`.

Hele tabellen på én linje:

```bash
grep -H -E 'Reproduction (successful|failed)' rt-*.log
```

Diffoscopes forklaring på den der falder:

```bash
grep -B 3 -A 12 'pdb' rt-5-build_path.log
```

## Resultat

| Akse | Varierer | Forventet | `arch` | `ubuntu-vm` |
| --- | --- | --- | --- | --- |
| `rt-1-none` | ingenting | successful | successful | successful |
| `rt-2-umask` | filrettigheder | successful | successful | successful |
| `rt-3-locales` | sprog, tegnsæt | successful | successful | successful |
| `rt-4-exec_path` | PATH | successful | successful | successful |
| `rt-5-build_path` | byggemappen | failed | **failed** | **failed** |
| `rt-6-time` | klokken | successful | successful | successful |
| `rt-7-fileordering` | filrækkefølge | ukendt | n/a | successful |

Tretten kørsler, tretten udfald som forudsagt. `[V]` — verdikterne står som
`Reproduction successful`/`failed` i `rt-*.log` under `data/`. Varighed 5-12
sekunder per kørsel på `arch`, 10-19 på `ubuntu-vm`; ikke de 60-90 sekunder
25/8-notatet regnede med, fordi projektet ingen pakker skal hente.

Fejler en akse vi ikke ventede, er logfilen svaret. Fejler
`rt-7-fileordering` med en mount-fejl frem for en byggefejl, er det FUSE og
ikke et fund.

## Fortolkning

**`+build_path` falder af præcis den grund forventningen gav, og kun den.**
Kontrolbygget står i `…/const_build_path`, eksperimentet i
`…/build-experiment-1`: to tegn længere. Diffoscope viser via pedump at
`.text` vokser fra `0x648` til `0x64c` — fire bytes, fordi stien ligger i
debug directory (CodeView-posten peger på PDB'ens absolutte sti) og strengen
rundes op til fire-byte-grænse. Alt efter strengen skubbes fire bytes:
entry point `0x2642` → `0x2646`, import table `0x25f0` → `0x25f2`.
`TimeDateStamp` skifter også, som den skal når den er en indholdshash og ikke
et ur. Ingen andre forskelle. Samme fire bytes på begge maskiner. `[V]`
(`rt-5-build_path.log`, begge mapper)

**Bifund: "successful" gælder kun inden for kørslen.** reprotest laver en ny
`/tmp/reprotest.XXXXXX/` per kørsel, og kontrol og eksperiment bygger begge i
`const_build_path` under den. Det seks tilfældige tegn i mappenavnet er nok:
de seks grønne kørsler på `arch` gav seks forskellige DLL-hashes, de syv på
`ubuntu-vm` syv forskellige, og ingen af dem er `541bed82…`/`4b3808d1…` fra
eksperiment 1, som blev bygget i `/private/tmp/rb1`. `[V]` (sidste linje i
hver `rt-*.log`). Verdikten "reproducerbar" fra reprotest betyder altså
"identisk med et kontrolbyg i samme mappe" — og eksperimentet viser selv
hvorfor det ikke rækker. Uden `PathMap` eller `DebugType=none` er hashen bundet
til byggemappen, og stiens *længde* er nok til at ændre binæren.

**De fem grønne akser er grønne på egne betingelser.** `+umask` og
`+fileordering` er grønne fordi der ikke er et arkivtrin (se forventningen);
`+time` er grøn fordi `TimeDateStamp` ikke er et tidsstempel — det er samme
mekanisme som forklarede 8/9's 70 bytes. `+locales` og `+exec_path` siger at
hverken sprogindstilling eller PATH-rækkefølge lækker ind i en IL-only DLL.
Det er det managede lag der bærer, ikke værktøjskæden som helhed.

**`+fileordering` er reelt målt.** En ekstra kørsel med `--verbosity 2`
(`rt-7-fileordering-verbose.log`) viser at disorderfs blev monteret med
`--shuffle-dirents=yes` og loggede "shuffling directory entries" og
"reversing directory entries". `[V]` Men projektet har én kildefil, så der er
kun `obj/`-indholdet og projektmappen at bytte rundt på. Med flere `.cs`-filer
er det MSBuilds glob-sortering der afgør udfaldet; det er ikke testet.

Samlet: **byggeriet tåler alt det reprotest kan variere, undtagen sin egen
placering.** Det er en snæver kanal (én streng i debug directory) og den er
lukbar med `PathMap` eller uden PDB — og det er næste eksperiment, ikke dette.

## Forbehold

- **reprotest simulerer variation på én maskine.** Den svarer på "er byggeriet
  følsomt over for de akser vi kender", ikke "er den identisk når alt det vi
  ikke tænkte på også ændrer sig". Det andet spørgsmål er eksperiment 1's, og det
  faldt.
- **De to Linux-miljøer kører samme reprotest-version (0.7.32, pipx), men
  forskellig diffoscope** hvis PATH på VM'en peger på apt-udgaven. Verdikten er
  robust — to forskellige filer fanges af begge — men forklaringen bliver
  ringere med 259 end med 329.
- **Ingen arkiver.** Se forventningen ovenfor: de grønne felter for `+umask` og
  `+fileordering` betyder ikke at kilderne ikke findes, kun at intet skriver dem
  ned.
- **`+time`-aksen kan køre her** fordi projektet ikke har afhængigheder. Med
  pakker vælter det forskudte ur TLS-håndtrykket mod NuGet, og aksen bliver
  utestbar uden en offline-cache.
- **pedump er to forskellige programmer.** På `arch` er det Ruby-gem'en
  `pedump` (sektionstabel, imphash), på `ubuntu-vm` Monos `pedump` (COFF/PE
  Header-format). Diffoscope 329 på begge, men forklaringens layout er
  forskellig. Verdikten og de fire bytes er de samme.
- **Protokol fra 8.-9. september, kørsel 14. september.** Laboratoriet og
  de tre kildefiler er uændrede siden 7/9 (samme `sources.txt`-hashes).
  Notat og datamappe er navngivet efter kørselsdagen; tidligere henvisninger
  til `2026-09-08-…` og `2026-09-09-environment-axes` er rettet til.
- **`+fileordering` med én kildefil** siger lidt om reel følsomhed; se
  fortolkningen.
- **Ikke testet:** `user_group`, `domain_host`, `num_cpus`, `aslr`, `kernel`,
  `timezone`. `PathMap` mod `+build_path` er kørt samme dag:
  [environment-axes-pathmap](2026-09-14-environment-axes-pathmap.md).
  `DebugType=none` er stadig ikke testet.
