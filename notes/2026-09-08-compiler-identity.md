# Eksperiment 3: er oversætteren den samme?

Køres 8. september 2026, kun på `arch`. Bygger videre på
[empty-class](2026-09-07-empty-class.md); termerne står i ordlisten dér.

Data: `data/2026-09-08-compiler-identity/arch/`.

Spørgsmålet: **var det oversætterens bytes der gjorde de to DLL'er forskellige
den 7. september?**

## Baggrunden

Eksperiment 1 gav to forskellige binærer fra samme kilde, samme sti og samme
pinnede SDK-version:

| Miljø | `minlib.dll` | `csc.dll` | SDK'ens oprindelse |
| --- | --- | --- | --- |
| `arch` | `541bed823d12e42b…` | `1b7543aa709363b6…` | Arch-pakken `dotnet-sdk-9.0 9.0.19.sdk120-1`, kildebygget af distributionen |
| `ubuntu-vm` | `4b3808d1cc1d6425…` | `644a4d336dcd11a7…` | Microsofts binære udgivelse via `dotnet-install.sh` |

Begge kalder sig 9.0.120. Oversætterfilerne er forskellige. Det er
hovedmistænkt, men det er ikke bevist: `LANG` og RID afveg også.

## Metoden

Én variabel ændres. Microsofts 9.0.120 hentes ned **ved siden af** Arch-pakken,
og den samme kilde bygges igen på den samme sti på den samme maskine. Alt andet
holdes fast, `LANG=da_DK.UTF-8` inkluderet.

```bash
export UD=$HOME/Dev/Speciale2026/data/2026-09-08-compiler-identity/arch && mkdir -p "$UD"
```

fish: `set -gx UD $HOME/Dev/Speciale2026/data/2026-09-08-compiler-identity/arch`.

```bash
curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --version 9.0.120
```

Den lander i `~/.dotnet` og rører ikke `/usr/share/dotnet`. Kontrollér at den
bliver valgt når man peger på den — `Base Path` skal sige
`/home/leos/.dotnet/sdk/9.0.120/`:

```bash
cd /private/tmp/rb1 && env PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="$HOME/.dotnet" dotnet --info | grep -E 'Version:|Base Path'
```

Optag begge oversættere som filer. Det er kontrollen: er Microsofts `csc.dll` på
Arch identisk med Microsofts `csc.dll` på VM'en, er værktøjet det samme og kun
maskinen forskellig:

```bash
sha256sum /usr/share/dotnet/sdk/9.0.120/Roslyn/bincore/csc.dll "$HOME/.dotnet/sdk/9.0.120/Roslyn/bincore/csc.dll" | tee "$UD/compilers.txt"
```

Byg med Microsofts SDK:

```bash
cd /private/tmp/rb1; rm -rf bin obj; env PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="$HOME/.dotnet" dotnet build -c Release; sha256sum bin/Release/net9.0/minlib.dll | tee -a "$UD/hashes.txt"
```

Og miljøblokken, som altid fra projektmappen:

```bash
cd /private/tmp/rb1 && env PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="$HOME/.dotnet" dotnet --info > "$UD/environment.txt"
```

```bash
uname -srm >> "$UD/environment.txt"; umask >> "$UD/environment.txt"; locale | head -1 >> "$UD/environment.txt"
```

## Resultat

| Hvad | Forventet | Målt |
| --- | --- | --- |
| `csc.dll`, Microsofts SDK på `arch` | `644a4d336dcd11a7…` (samme som VM'en) | |
| `csc.dll`, Arch-pakken | `1b7543aa709363b6…` | |
| `minlib.dll` bygget med Microsofts SDK | `4b3808d1cc1d6425…` (samme som VM'en) | |

## Sådan læses udfaldet

**Hashen bliver `4b3808d1…`.** Sagen er lukket: samme kilde, samme sti, samme
versionsnummer — forskellen var oversætterens bytes. Og fordi `LANG` stadig er
`da_DK.UTF-8` her, mens VM'en havde `C.UTF-8`, viser den samme kørsel at
sprogindstillingen ikke påvirker resultatet. Én build, to svar.

**Hashen bliver noget tredje.** Så er der mere end oversætteren i spil. Næste
kørsel lægger `env LANG=C.UTF-8` oven i, og derefter er RID og
`dotnet`-værtens version tilbage som kandidater.

**Hashen bliver `541bed82…`.** Så byggede vi med Arch-pakken alligevel —
`DOTNET_ROOT` eller PATH slog ikke igennem. Tjek `Base Path` i miljøblokken før
resultatet tolkes.

## Hvorfor det betyder noget ud over eksperimentet

Afhandlingens påstand er at en version er en selvdeklareret streng uden binding
til en binær. Her er den demonstreret på egen maskine, i miniature: to
oversættere, ét versionsnummer, to resultater. Det er også en advarsel om
metoden — et reproducerbart byg kræver at værktøjskæden identificeres ved
indhold, ikke ved navn. `global.json` pinner et versionsnummer, og det er ikke
nok.

## Forbehold

- **Arch-pakken forbliver installeret.** Eksperimentet tilføjer en SDK, fjerner
  ingen. Alle senere kørsler skal derfor sige eksplicit hvilken `dotnet` de
  brugte, og `command -v` hører i miljøblokken.
- **`dotnet`-værten er fælles.** `global.json` pinner SDK'en, ikke værten
  (`Host: 10.0.11` på `arch`). Den starter oversætteren men oversætter ikke selv,
  så den bør ikke nå ind i outputtet — men det er en antagelse, ikke en måling.
- **Én maskine.** Eksperimentet forklarer forskellen; det viser ikke at
  Microsofts SDK giver samme bytes på vilkårlige maskiner.
