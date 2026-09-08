# Eksperiment 3: er oversætteren den samme?

Køres 8. september 2026, kun på `arch`. Bygger videre på
[empty-class](2026-09-07-empty-class.md); termerne står i ordlisten dér.

Data: `data/2026-09-08-compiler-identity/arch/`.

Spørgsmålet: **var det oversætterens bytes der gjorde de to DLL'er forskellige
den 7. september?**

## Baggrunden

Eksperiment 1 gav to forskellige binærer fra samme kilde, samme sti og samme
pinnede SDK-version:


|                    | `arch`                                      | `ubuntu-vm`                                         |
| -------------------- | --------------------------------------------- | ----------------------------------------------------- |
| `minlib.dll`       | `541bed823d12e42b…`                        | `4b3808d1cc1d6425…`                                |
| `csc.dll`          | `1b7543aa709363b6…`                        | `644a4d336dcd11a7…`                                |
| SDK Version        | 9.0.120                                     | 9.0.120                                             |
| SDK Commit         | `d0558bff3d`                                | `3f97250e38`                                        |
| MSBuild            | `17.12.57+d0558bff3`                        | `17.12.57+07da1b9a8`                                |
| Host Version       | 10.0.11                                     | 9.0.19                                              |
| RID                | `arch-x64`                                  | `linux-x64`                                         |
| `LANG`             | `da_DK.UTF-8`                               | `C.UTF-8`                                           |
| SDK'ens oprindelse | Arch-pakken`dotnet-sdk-9.0 9.0.19.sdk120-1` | Microsofts binære udgivelse via`dotnet-install.sh` |

Begge kalder sig 9.0.120, men `dotnet --info` afslører at de er bygget fra
**forskellige kilderevisioner**. På `arch` er MSBuilds commit-suffiks identisk med
SDK'ens commit; på `ubuntu-vm` er de forskellige. Det er signaturen på et samlet
kildebyg mod komponenter bygget hver for sig.

Formuleringen skal derfor ikke være "samme kilde, forskellig binær" — det er
forkert. Den skal være: **versionsnummeret 9.0.120 identificerer hverken
kilderevisionen eller binæren.** Det dækker mindst to commits og to
oversætterbinærer.

Og commit-feltet løser det ikke. Det er stadig en streng stemplet ind under
byggeriet, som intet kontrollerer mod bytes. Commit er proveniens, hash er
identitet.

## Hvorfor kun `arch`

Designet er et 2x2, hvor tre felter allerede er afgjort:


|                   | Arch' SDK              | Microsofts SDK         |
| ------------------- | ------------------------ | ------------------------ |
| **Arch-maskinen** | `541bed82…` målt 7/9 | **? — denne test**    |
| **Ubuntu-VM'en**  | ikke gennemførlig     | `4b3808d1…` målt 7/9 |

Peter skal ikke gøre noget: han har allerede Microsofts SDK, og en geninstallation
ville ikke ændre en byte.

Spejlvendingen — Arch' SDK på Ubuntu — er reelt spærret. Arch kører glibc 2.44,
VM'en 2.39 (målt 8/9), og SDK'ens native dele er på Arch linket mod den nyere.
Man kunne udpakke pacman-pakken og forsøge, men så måler man en transplantation
og ikke en distribution. Den er heller ikke nødvendig: er outputtet bestemt af
oversætteren og ikke af maskinen, er én retning nok til at vise det.

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


| Hvad                                   | Forventet                              | Målt |
| ---------------------------------------- | ---------------------------------------- | ------- |
| SDK Commit, Microsofts SDK på`arch`   | `3f97250e38` (samme som VM'en)         |       |
| `csc.dll`, Microsofts SDK på `arch`   | `644a4d336dcd11a7…` (samme som VM'en) |       |
| `csc.dll`, Arch-pakken                 | `1b7543aa709363b6…`                   |       |
| `minlib.dll` bygget med Microsofts SDK | `4b3808d1cc1d6425…` (samme som VM'en) |       |

De to første rækker er kontrollen: rammer Microsofts SDK på Arch samme commit
**og** samme `csc.dll`-hash som på VM'en, er værktøjet bevisligt det samme, og
kun maskinen er forskellig.

## Hvad forskellen mellem de to oversættere består i

Undersøgt 8. september efter kørslen, med `pedump` (via diffoscope) og
`ilspycmd`.

**Oversætterne er den samme kode.** Dekompileret er begge `csc.dll` 1672 linjer,
og kun 12 linjer afviger — hver enkelt metadata:

| | Arch | Microsoft |
| --- | --- | --- |
| `TargetFramework` | `.NETCoreApp,Version=v9.0` | `.NETCoreApp,Version=v8.0` |
| `CommitHash` | `d0558bff3d817c76a12aa68…` | `fc52718eccdb37693a40a51…` |
| `AssemblyInformationalVersion` | `4.12.0-3.25609.5+d0558…` | `4.12.0-3.25609.5+fc527…` |
| `RepositoryUrl` | `github.com/dotnet/dotnet` | `github.com/dotnet/roslyn` |

Samme Roslyn-version, `4.12.0-3.25609.5`. Arch bygger fra det samlede kildetræ
(`dotnet/dotnet`), Microsoft fra `dotnet/roslyn`, og de to binærer kører på hver
sit framework. De sidste to afvigende linjer er et genereret typenavn hvis hash
følger af de andre.

Begge indlejrede PDB-stier begynder med `/_/` — altså **både Microsoft og Arch
bruger `PathMap` på deres egne udgivelser.** Det fix WS.Phoenix mangler, bruger
værktøjsleverandørerne på sig selv.

**Og de udsender identisk kode.** Samme kilde bygget på samme sti med hver af de
to oversættere gav `e793b11f1e74ab42…` mod `4ede5f519b3e2eef…` — men
dekompileret er de to resultater **0 linjer forskellige**.

Forskellen er 70 bytes ud af 4096, og de ligger i fem klumper:

| Byte (1-indekseret) | Størrelse | Felt |
| --- | --- | --- |
| 137-140 | 4 | PE-headerens `TimeDateStamp` (verificeret ved offset) |
| 1597-1612 | 16 | modulets MVID i GUID-heapen |
| 1821-1824 | 4 | tidsstempel i debug directory |
| 1905-1920 | 16 | PDB-id (CodeView-GUID) |
| 2065-2096 | 32 | PDB-checksum, SHA-256-størrelse |

De fire nederste er sluttet ud fra placering og størrelse, ikke verificeret mod
formatspecifikationen. Ingen byte af IL, metadata-tabeller eller strengheaps
afviger.

`TimeDateStamp` er i øvrigt værd at se: pedump læser felterne som
`"2048-04-05 10:47:46"` og `"2054-09-09 08:29:46"`. Absurde fremtidsdatoer, fordi
Roslyn i deterministisk tilstand skriver en indholdshash i tidsstempelfeltet i
stedet for klokken. Feltet der klassisk ødelægger reproducerbarhed, er omdannet
til et identitetsfelt.

### Hvad det betyder

**Bit-identitet er strengere end kode-identitet.** To uafhængigt byggede
oversættere af samme version udsendte beviseligt samme kode, og artefakterne var
alligevel forskellige — fordi .NET's deterministiske byg med vilje binder
artefaktets identitet til oversætterens identitet.

Konsekvensen er hård: en distribution der bygger oversætteren fra kilde, kan
**aldrig** ramme leverandørens artefakter, uanset at koden er den samme. Vil man
verificere en release bit for bit, skal man bruge leverandørens egen
oversætterbinær. At pinne "9.0.120" er ikke nok, og at pinne kilderevisionen er
heller ikke nok.

Mekanismen — at Roslyns deterministiske hash inddrager oversætterens egen
identitet — er sluttet ud af observationen og skal efterprøves mod Roslyns kilde
før den citeres.

## Sådan læses udfaldet

**Hashen bliver `4b3808d1…`.** Sagen er lukket: samme kilde, samme sti, samme
oversætterbinær — og så samme output. Den kørsel afgør tre ting på én gang, fordi
`arch` beholder sine egne værdier for resten: `LANG` er stadig `da_DK.UTF-8` mod
VM'ens `C.UTF-8`, RID'en er stadig `arch-x64`, og `dotnet`-værten er stadig
10.0.11 mod VM'ens 9.0.19. Rammer hashen alligevel, er alle tre udelukket som
årsag. Én build, fire svar.

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
