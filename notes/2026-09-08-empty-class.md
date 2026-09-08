# Eksperiment 1, gentaget

Køres 8. september 2026 på `arch` og `ubuntu-vm`. Samme protokol som
[7. september](2026-09-07-empty-class.md) — samme laboratorium, samme tre
filer, samme pinnede SDK. Fremgangsmåden står dér og gentages ikke her.

Data: `data/2026-09-08-empty-class/arch/` og `.../ubuntu-vm/`.

Spørgsmålet: **kommer gårsdagens tal ud igen?**

Det er ikke en gentagelse for gentagelsens skyld. Det er den første prøve på om
protokollen virker som protokol — om en beskrivelse er nok til at ramme det samme
tal en anden dag. Og miljøet har flyttet sig en smule siden i går: `ubuntu-vm`
har fået 2 GB swap, og begge maskiner har været genstartet eller lukket ned
undervejs.

## Forventning, skrevet før kørslen

| Miljø | `minlib.dll` |
| --- | --- |
| `arch` | `541bed823d12e42b5e9e6087c9c32a9d6fbaa9a116aae61fc00c808231e74113` |
| `ubuntu-vm` | `4b3808d1cc1d642577f60a054905f5f065aab8b9aea1765b407fc583cef70d33` |

Kildehashene skal være `2a766d57…`, `079f65f3…`, `8628a3a4…` begge steder, og
`csc.dll` skal være `1b7543aa…` på `arch` og `644a4d33…` på `ubuntu-vm`.

Kommer der andre tal ud, er det et fund og ikke en fejl: så har noget i miljøet
ændret sig som vi ikke har beskrevet, og miljøblokkene fra i dag mod i går siger
hvad.

## Kørslen

Resultatmappen først. `arch` (fish):

```bash
set -gx UD $HOME/Dev/Speciale2026/data/2026-09-08-empty-class/arch; mkdir -p $UD
```

`ubuntu-vm` (bash):

```bash
export UD=$HOME/Speciale2026/data/2026-09-08-empty-class/ubuntu-vm && mkdir -p "$UD"
```

Kilden er den samme som i går og skal ikke skrives igen — men kontrollen gemmes
denne gang:

```bash
cd /private/tmp/rb1 && sha256sum minlib.csproj Beregning.cs global.json | tee "$UD/sources.txt"
```

Pinnet, fra projektmappen:

```bash
cd /private/tmp/rb1 && dotnet --version
```

Miljøblokken:

```bash
cd /private/tmp/rb1 && dotnet --info > "$UD/environment.txt"
```

```bash
uname -srm >> "$UD/environment.txt"; umask >> "$UD/environment.txt"; locale | head -1 >> "$UD/environment.txt"; diffoscope --version >> "$UD/environment.txt" 2>&1; command -v dotnet reprotest diffoscope >> "$UD/environment.txt"
```

```bash
cd /private/tmp/rb1 && sha256sum "$(dotnet --info | sed -n 's/^ *Base Path: *//p')Roslyn/bincore/csc.dll" | tee -a "$UD/environment.txt"
```

To rene builds:

```bash
cd /private/tmp/rb1; rm -rf bin obj; dotnet build -c Release; sha256sum bin/Release/net9.0/minlib.dll | tee -a "$UD/hashes.txt"
```

```bash
cd /private/tmp/rb1; rm -rf bin obj; dotnet build -c Release; sha256sum bin/Release/net9.0/minlib.dll | tee -a "$UD/hashes.txt"
```

På `ubuntu-vm` navngives `dotnet` med fuld sti — `/root/.dotnet/dotnet` — i alle
kommandoerne ovenfor. apt har sin egen `dotnet` med SDK 10.0.111 i `/usr/bin`,
og den fejler mod pinnet.

## Resultat

| Hvad | Forventet | `arch` | `ubuntu-vm` |
| --- | --- | --- | --- |
| `sources.txt`, tre filer | `2a766d57…` `079f65f3…` `8628a3a4…` | verificeret | |
| `csc.dll` | `1b7543aa…` / `644a4d33…` | `1b7543aa…` | |
| `minlib.dll`, build 1 | som i går | `541bed82…` | |
| `minlib.dll`, build 2 | som build 1 | `541bed82…` | |

## Fortolkning

**`arch`: protokollen holder over tid.** Kørt 8. september 14:14, et døgn efter
den første kørsel. Samme tre kildehashes, samme `csc.dll`, og samme DLL-hash to
gange — `541bed823d12e42b5e9e6087c9c32a9d6fbaa9a116aae61fc00c808231e74113`,
identisk med 7. september.

Miljøblokken fra i dag er linje for linje identisk med gårsdagens, bortset fra at
`pipx list` er erstattet af `command -v`. SDK-version, commit `d0558bff3d`,
kerne, `umask`, `locale` og diffoscope-version er uændrede. Der er altså ikke
drevet noget i miljøet mellem de to kørsler, og det er derfor det samme tal kom ud.

Det er den svageste form for reproducerbarhed — samme maskine, senere tidspunkt —
og den skulle holde før noget andet betyder noget. Den holder.

`ubuntu-vm` mangler.

## Forbehold

- **Samme laboratorium som i går.** Kildefilerne er ikke skrevet om, kun
  verificeret. Det er en styrke for sammenligningen og en svaghed for
  protokollen: at `printf`-linjerne stadig giver de samme bytes, bliver ikke
  prøvet her.
- **Samme maskiner.** Gentagelsen prøver protokollen over tid, ikke over flere
  miljøer.
- Samme afgrænsninger som 7. september: kun `dotnet build`, ingen pakning, ingen
  arkiver, ingen afhængigheder, kun x64 Linux.
