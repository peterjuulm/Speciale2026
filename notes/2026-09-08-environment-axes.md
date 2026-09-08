# Eksperiment 2: miljøvariationer

Køres 8. september 2026 på `arch` (Leos laptop) og `ubuntu-vm` (delt droplet).
Bygger videre på [empty-class](2026-09-07-empty-class.md) — samme laboratorium,
samme tre filer, samme pinnede SDK. Termerne står i ordlisten dér.

Data: `data/2026-09-08-environment-axes/arch/` og `.../ubuntu-vm/`.

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
export UD=$HOME/Speciale2026/data/2026-09-08-environment-axes/ubuntu-vm && mkdir -p "$UD"
```

`arch` bruger fish:

```bash
set -gx UD $HOME/Dev/Speciale2026/data/2026-09-08-environment-axes/arch; mkdir -p $UD
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

De øvrige er ordret den samme kommando med to ting skiftet:

    --vary=-all,+umask          > rt-2-umask.log
    --vary=-all,+locales        > rt-3-locales.log
    --vary=-all,+exec_path      > rt-4-exec_path.log
    --vary=-all,+build_path     > rt-5-build_path.log
    --vary=-all,+time           > rt-6-time.log
    --vary=-all,+fileordering   > rt-7-fileordering.log   (kun ubuntu-vm)

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
| `rt-1-none` | ingenting | successful | | |
| `rt-2-umask` | filrettigheder | successful | | |
| `rt-3-locales` | sprog, tegnsæt | successful | | |
| `rt-4-exec_path` | PATH | successful | | |
| `rt-5-build_path` | byggemappen | failed | | |
| `rt-6-time` | klokken | successful | | |
| `rt-7-fileordering` | filrækkefølge | ukendt | n/a | |

Fejler en akse vi ikke ventede, er logfilen svaret. Fejler
`rt-7-fileordering` med en mount-fejl frem for en byggefejl, er det FUSE og
ikke et fund.

## Fortolkning

Udfyldes efter kørslen.

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
- **Ikke testet:** `user_group`, `domain_host`, `num_cpus`, `aslr`, `kernel`,
  `timezone`.
