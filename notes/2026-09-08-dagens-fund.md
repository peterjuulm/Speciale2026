# Dagens fund, 8. september 2026

Oversigtsnotat. Tallene og fremgangsmåden står i eksperimentnotaterne;
her står hvad der kom ud, hvad vi lærte, og hvad der blev rettet.

Kørt i dag på `arch` (Leos maskine). `ubuntu-vm` er ikke kørt i dag.

- [empty-class, gentaget](2026-09-08-empty-class.md)
- [compiler-identity](2026-09-08-compiler-identity.md)
- [environment-axes](2026-09-08-environment-axes.md) — ikke kørt endnu

## Resultater

| Kørsel | Resultat |
| --- | --- |
| Eksperiment 1 gentaget, `arch` | `541bed82…` to gange — samme som 7/9 |
| Eksperiment 3, Microsofts SDK på `arch` | `4b3808d1…` — Peters hash, byte for byte |

Gentagelsen viser at protokollen er tilstrækkelig som beskrivelse til at ramme
samme tal et døgn senere. Miljøblokken fra i dag er linje for linje identisk med
gårsdagens; der er ikke drevet noget.

Eksperiment 3 forklarer hvorfor de to maskiner gav forskellige binærer 7/9. Med
Microsofts oversætter på Leos maskine kommer Peters præcise bytes ud, mens
kernen (7.1.8-arch1-3), distributionen (endeavouros), glibc (2.44) og
`LANG=da_DK.UTF-8` forblev Leos. **Outputtet bestemmes af SDK'en, ikke af
maskinen.**

## Hovedfundet

`9.0.120` dækker **to kilderevisioner og to oversætterbinærer**. Versionsnummeret
identificerer hverken.

De to oversættere er den samme kode: dekompileret er begge `csc.dll` 1672 linjer
med 12 afvigende linjer, alle metadata (commit, målframework, repo-URL,
informational version). Samme Roslyn-version `4.12.0-3.25609.5`.

Og de udsender identisk kode. Samme kilde bygget på samme sti med hver
oversætter gav `e793b11f…` mod `4ede5f51…`, men **0 afvigende linjer**
dekompileret. Forskellen er 70 bytes af 4096, fordelt på fem identitetsfelter:

| Byte | Størrelse | Felt |
| --- | --- | --- |
| 137-140 | 4 | PE-headerens `TimeDateStamp` |
| 1597-1612 | 16 | modulets MVID |
| 1821-1824 | 4 | tidsstempel i debug directory |
| 1905-1920 | 16 | PDB-id |
| 2065-2096 | 32 | PDB-checksum |

Kæden: oversætteren skriver sit eget navn i PDB'en — `compiler-version:
4.12.0-3.25609.5+d0558bff…` står ordret i filen — og DLL'en bærer PDB'ens id og
SHA-256. De to øvrige felter er hashes af indholdet.

**Bit-identitet er strengere end kode-identitet.** Konsekvensen er hård: en
distribution der bygger oversætteren fra kilde, kan aldrig ramme leverandørens
artefakter, uanset at koden er den samme. Bit-for-bit-verifikation kræver
leverandørens egen oversætterbinær, pinnet ved indhold.

**Præcedens til en anbefaling:** begge `csc.dll` har indlejrede PDB-stier der
begynder med `/_/`. Både Microsoft og Arch bruger `PathMap` på deres egne
udgivelser. Phoenix har ingen (verificeret 19/8). Anbefalingen er altså ikke en
ny idé, men at gøre det værktøjsleverandøren gør på sig selv.

## Læringer der ikke hører til ét eksperiment

- **Determinisme** er en egenskab ved processen, **reproducerbarhed** ved
  beskrivelsen. Det første måles på én maskine; det andet kræver at inputtet er
  erklæret godt nok til at en anden kan opnå det.
- **Kryds-OS er ikke barren.** Definitionen kræver samme *erklærede* byggemiljø.
  Debian gemmer det i `.buildinfo`. Vores faldne måling 7/9 var
  underspecifikation, ikke et OS-problem.
- **En assembly** er én PE-fil med IL og metadata. Roslyn laver præcis én per
  projekt; MSBuild laver ingen — den genererer kildekode, kalder oversætteren én
  gang, og kopierer. `bin/`-DLL'en er en kopi af `obj/`-DLL'en; derfor
  `rm -rf bin obj` og ikke bare `rm -rf bin`.
- **PE-tidsstemplet er ikke et tidspunkt.** Fire bytes af en hash i et felt der
  er mærket som sekunder siden 1970. `86 39 3d df` -> 3.745.331.590 ->
  2088-09-06. Feltet kan kun udtrykke 1970-2106, så to tredjedele af tiden peger
  det ud i fremtiden. Determinismen sletter dermed byggetidspunktet: vil man
  vide hvornår, skal svaret komme fra en attestation ved siden af artefaktet.
- **Artefakter ligger i lag** — assembly, `.nupkg`, zip, OCI-lag. Arkivmetadata
  (tidsstempler, ejerskab, filrækkefølge) bider først fra lag to. Derfor er
  dagens grønne resultater betingede af at der ikke er et pakketrin.
- **`.deps.json` bærer `sha512` for næsten hver afhængighed** (46 af 47 i en
  rigtig Phoenix-fil), og loaderen kontrollerer dem ikke. Skal efterprøves, men
  holder det, er det et fund lige ved siden af standardgabet.
- I Phoenix bygger jeres eget byg **fire** af omkring 300 assemblies i en
  release. Resten er kopierede bytes, oversat af en anden csc et andet sted.

## Håndværk der virkede

- Fast absolut sti på alle maskiner. `/private/tmp` frem for `/tmp`, fordi
  macOS' `/tmp` er et symlink.
- SDK pinnet med `global.json` og `rollForward: disable`. `dotnet --version`
  **fra projektmappen** — uden for den får man sin nyeste SDK.
- Miljøblok optaget *før* målingen, med hele `dotnet --info` (ikke `head -12`,
  som skjuler både commit og `global.json`-linjen), plus `command -v` og
  `csc.dll`-hashen.
- `sha256sum -c`: jeres evidensfiler er allerede checksum-filer, så gårsdagens
  fil er dagens test.
- `env LC_ALL=C` i alt der sorterer. Målt: samme filer sorteret med `da_DK.UTF-8`
  og `C.UTF-8` giver to forskellige manifest-hashes.
- Byg aldrig inde i repoet. Editoren på repoet, terminalen på laboratoriet.
- `pedump` (til diffoscope) og `ilspycmd` gør forskellen mellem "hvor" og "hvad".
  Uden `pedump` falder diffoscope tilbage til hexdump på .NET-filer.

## Rettelser til tidligere formuleringer

- **"Samme kilde, forskellig binær" var forkert** om 7/9-resultatet.
  `dotnet --info` viser at de to SDK'er er bygget fra forskellige
  kilderevisioner (`d0558bff3d` mod `3f97250e38`). Den rigtige formulering er at
  versionsnummeret ikke identificerer kilderevisionen.
- **RID og `dotnet`-værten blev ikke uafhængigt udelukket** af eksperiment 3.
  De fulgte med SDK'en: RID skiftede fra `arch-x64` til `linux-x64` og værten
  fra 10.0.11 til 9.0.19. Konklusionen er derfor "SDK'en bestemmer", ikke
  "oversætteren alene bestemmer".
- **Kontrollen med `-p:RuntimeIdentifier=linux-x64` målte det forkerte.** Med en
  RID flytter outputtet til `bin/Release/net9.0/linux-x64/`, og så ændrer den
  indlejrede PDB-sti sig — verificeret: stien blev
  `/private/tmp/rb1/obj/Release/net9.0/linux-x64/minlib.pdb`. Forskellen var
  stien, ikke RID'en. Vil man isolere RID, skal `PathMap` først fjerne
  stiforskellen.

## Forbehold

- At Roslyns deterministiske hash inddrager oversætterens egen identitet, er
  sluttet ud af observationen (samme IL, forskelligt MVID). Skal efterprøves mod
  Roslyns kilde før det citeres som mekanisme.
- De fire PDB-relaterede felter i byte-tabellen er identificeret ud fra placering
  og størrelse, ikke mod formatspecifikationen. `TimeDateStamp` er verificeret
  ved offset.
- 0 afvigende linjer er målt på **dekompileret C#** fra ilspycmd, ikke på rå IL.
  Stærk indikation, ikke bevis for identiske IL-bytes.
- Alt måles stadig på en tom klasse: ingen afhængigheder, ingen pakning, ingen
  arkiver, kun x64 Linux.

## I morgen

1. Peters gentagelse af eksperiment 1 på `ubuntu-vm`.
2. `environment-axes` — seks akser på `arch`, syv på `ubuntu-vm`
   (`+fileordering` kræver `disorderfs`, som kun findes der). Peter skal have
   `reprotest==0.7.32` og `diffoscope==329` via pipx, og fulde stier i
   kommandoerne.
3. Kommandoerne samles i `experiments/` som scripts, med dagens hashes som
   forventede værdier, så de siger til når tallene ikke kommer ud igen.
