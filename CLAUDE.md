# Speciale2026

Eksperimenter til Leo Sakharov og Peter Juul Møllers speciale om
reproducerbare builds i .NET og WS.PEMS (MSc Software Design, ITU, efterår
2026). Selve specialeteksten skrives i Overleaf; her ligger kun det der skal
kunne køres igen, og det der kom ud af det. Arbejdssproget er dansk med æøå
direkte i filerne. Kun `README.md` er på engelsk.

**Repoet er public.** Intet fra Weel-Sandvigs kildekode, byggeoutput eller
interne dokumenter må lande her. Ingen IP-adresser, nøgler eller personlige
stier ud over dem der allerede står i `environment.txt`-filerne.

## Struktur

- `notes/åååå-mm-dd-emne.md`: ét notat per eksperiment. Faste afsnit:
  spørgsmål, **forventning skrevet før kørslen**, kommandoer ordret, resultat,
  fortolkning, forbehold. Observation og fortolkning holdes adskilt.
- `notes/åååå-mm-dd-dagens-fund.md`: undersøgelsesnotater uden kørsel.
- `notes/dotnet-build-hvem-laver-hvad.md`: baggrund om MSBuild kontra Roslyn.
  Ordlisten står i `notes/2026-09-07-empty-class.md`.
- `data/<eksperiment>/<maskine>/`: `environment.txt`, `hashes.txt`,
  `sources.txt`, `rt-*.log` fra reprotest, `kommando.txt` med den ordrette
  byggekommando. Tekst går i git, bytes gør ikke: aldrig DLL'er eller pakker.
- `experiments/`: scripts. Tom indtil videre; kørslerne er hidtil
  håndkommandoer der står i notaterne.

Notat og datamappe navngives efter **den dag kørslen fandt sted**, ikke
planlægningsdagen. Én fil per maskine under `data/`; to personer i samme fil
er en flettekonflikt, ikke en måling.

Påstande der skal kunne citeres mærkes `[V]` (verificeret: fil, linje eller
en kørsel der kan gentages) eller `[I]` (inferens). En forudsigelse er `[I]`
indtil den er målt.

## Maskinerne

Tre miljøer, alle med laboratoriet i `/private/tmp/rb1` og SDK pinnet til
9.0.120 via `global.json` med `rollForward: disable`:

| Navn | Hvad | Særligt |
| --- | --- | --- |
| `arch` | Leos laptop, Arch Linux | To SDK 9.0.120: Arch-pakken i `/usr/share/dotnet` (csc `1b7543aa…`) og Microsofts i `~/.dotnet` (csc `644a4d33…`). De giver forskellige bytes. Sig altid hvilken der bruges. |
| `ubuntu-vm` | Delt droplet, Ubuntu 24.04 | apt har egne udgaver af alt i `/usr/bin`. De rigtige ligger i `/root/.dotnet` og `/root/.local/bin` og findes kun i PATH i interaktive shells. **Brug fulde stier i alt der måler.** `disorderfs` findes kun her. |
| `mac` | Peters laptop, Apple Silicon | Microsofts SDK via `dotnet-install.sh`. reprotest kan ikke køre på macOS. |

## Fælder, alle betalt for én gang

- **Byg aldrig inde i et git-repo.** SDK'en indlejrer HEAD-commit'en i
  `AssemblyInformationalVersion`, så hashen skrider ved hvert commit uanset
  `PathMap`. Derfor ligger laboratoriet i `/private/tmp/rb1`.
- **Pipe aldrig reprotests output.** Den efterlader en barneproces der holder
  pipen åben, så `| tail` aldrig ser slut. Omdiriger til fil.
- **reprotests "successful" gælder kun inden for kørslen.** Kontrol og
  eksperiment bygger i samme tilfældige `/tmp/reprotest.XXXXXX/`. Uden
  `PathMap` giver hver kørsel sin egen hash. Sammenlign hashes på tværs af
  kørsler, ikke kun verdikter.
- **`PathMap` fra kommandolinjen skal bruge shellens `$PWD`**, altså
  `-p:PathMap=$PWD/=/_/`. `$(MSBuildProjectDirectory)` udfyldes ikke i globale
  egenskaber og ignoreres stille. Tjek med `strings minlib.dll | grep pdb`, der
  skal stå `/_/obj/...`.
- **`ContinuousIntegrationBuild` lukker ikke sti-følsomhed.** Det gør `PathMap`.
- **Ryd `bin/` og `obj/` før reprotest**, ellers kopieres gammelt output med
  ind i testmappen.
- Versionsnummeret `9.0.120` identificerer ikke oversætteren. Roslyn-commit'en
  i `csc.dll` gør. Skriv derfor altid `csc.dll`-hashen i miljøblokken.

## Arbejdsgang

1. Skriv notatet med forventning **før** kørslen. Commit gerne den tomme
   resultattabel først.
2. Optag miljøblokken på hver maskine (`dotnet --info`, `uname`, `umask`,
   `locale`, værktøjsversioner, `csc.dll`-hash, `date -Is`).
3. Kør. Gem loggene under `data/`, kommandoen i `kommando.txt`.
4. Udfyld resultat og fortolkning. Ret ikke forventningen bagefter; skriv
   i stedet hvor den fejlede.
5. `git pull --rebase` før push. Vi skriver begge direkte i `main`.

## Hvor vi står

Se `notes/2026-09-09-dagens-fund.md` for mekanismen (compilerens identitet
rejser via PDB-checksummen ind i DLL'en) og de to `2026-09-14`-notater for
miljøakserne: alt tåles undtagen byggemappen og oversætteren. Den første
lukkes med `PathMap`, den anden ved at hente SDK'en fra samme kilde. Åbne
spørgsmål står under "Forbehold" og "Ikke testet" i det nyeste notat.
