# Dagens fund, 9. september 2026

Undersøgelsesnotat, ikke et eksperimentnotat. Dagens plan var miljøakserne med
reprotest; de blev ikke kørt. I stedet blev mekanismen bag gårsdagens resultat
målt hele vejen igennem, og macOS-spørgsmålet afgjort.

Alt måles på `arch`. Grundlaget er egne kørsler mod filer på maskinen plus to
arkiver hentet direkte fra Microsoft og verificeret mod deres publicerede
SHA-512.

- [environment-axes](2026-09-09-environment-axes.md) — stadig ikke kørt

## Resultater

| Spørgsmål | Svar |
| --- | --- |
| Kan en Mac ramme samme version **og** commit? | Ja, via `dotnet-install.sh`. Homebrew kan ikke `[V]` |
| Er Microsofts `csc.dll` den samme på tværs af platforme? | Nej. Tre forskellige binærer kalder sig alle 9.0.120 `[V]` |
| Hvorfor? | ReadyToRun — `csc.dll` bærer arkitekturspecifik maskinkode `[V]` |
| Hvordan beregnes PDB-checksummen? | SHA-256 af PDB'en med dens egne 20 id-bytes nulstillet `[V]` |
| Hvor står oversætterens identitet i outputtet? | Kun i PDB'en. Nul træf i DLL'en `[V]` |
| Læser `csc` sin egen metadata? | Ja. 44 bytes IL, målt `[V]` |

## Hovedfundet

**DLL'en bærer en hash af oversætterens identitet, aldrig identiteten selv.**

Oversætterens commit-streng står to gange i `minlib.pdb` og nul gange i
`minlib.dll` — hverken som UTF-8 eller UTF-16. `[V]`

Kæden, målt led for led:

1. `csc.dll` erklærer sig selv i `AssemblyInformationalVersion`, en post på 62
   bytes i `#Blob`-heapen: `4.12.0-3.25609.5+d0558bff…` `[V]`
2. `GetCommitHash()` i `csc.dll` — 44 bytes IL — spørger hvilken assembly den
   selv bor i, henter `CommitHashAttribute` med reflection og returnerer dens
   `Hash` `[V]`
3. Strengen ankommer ordret i PDB'ens CompilationOptions-blob som
   `compiler-version` `[V]`
4. PDB-checksummen i DLL'ens debug directory er SHA-256 af PDB'en med id-feltet
   nulstillet. Verificeret byte for byte `[V]`
5. PDB-id'et er de første 20 bytes af den hash med UUID-v4-bittene tvunget:
   `8f` til `4f`, `65` til `a5`. MVID'en bruger samme trick `[V]`

Efterprøv punkt 4:

    python3 -c "
    import struct,hashlib
    b=bytearray(open('/private/tmp/rb1/bin/Release/net9.0/linux-x64/minlib.pdb','rb').read())
    off,size=struct.unpack_from('<II',b,16+struct.unpack_from('<I',b,12)[0]+4)
    print('som den ligger   ', hashlib.sha256(b).hexdigest())
    b[off:off+20]=b'\x00'*20
    print('med id nulstillet', hashlib.sha256(b).hexdigest())
    "

Skal give `98bcbc158ee51d8f656f9a4a919e54e5f639b0bd9564de0bfdb134f6016f7500`, og
det tal står i DLL'ens debug directory, post af type 19.

Det forklarer gårsdagens 70 afvigende bytes fordelt på fem felter og ikke én
byte mere: der var ingen tekststreng at afvige i, kun hashes.

**Og det gør kanalen lukbar.** Skrives der ingen PDB, findes hverken CodeView-
eller checksum-posten, og oversætterens identitet har ingen vej ind i
artefaktet. Ikke testet — se "I morgen".

## Microsofts SDK er platformspecifik

Forudsigelsen fra i går om at `csc.dll` var den samme på tværs af RID'er var
forkert. Målt på arkiver hentet fra `builds.dotnet.microsoft.com` og verificeret
mod SHA-512'en i Microsofts `releases.json`:

| SDK 9.0.120 | `csc.dll` sha256 | størrelse | `.text` | Machine | Roslyn-commit |
| --- | --- | --- | --- | --- | --- |
| Microsoft osx-arm64 | `1824569732a63f5d…` | 132.096 | 102.400 | `0xec20` | `fc52718e…` |
| Microsoft linux-x64 | `644a4d336dcd11a7…` | 121.856 | 91.648 | `0xfd1d` | `fc52718e…` |
| Arch-pakken | `1b7543aa709363b6…` | 121.856 | 91.648 | `0xfd1d` | `d0558bff…` |

Alle tre er ReadyToRun-billeder: `ManagedNativeHeader` bærer signaturen `RTR\0`.
`csc.dll` er altså ikke ren IL, men IL plus forudoversat maskinkode til én
arkitektur. Derfor er ARM64-udgaven 10.240 bytes større. `[V]`

`Machine`-feltet er ikke en arkitekturkode, men arkitekturen XOR en OS-konstant,
så Windows nægter at indlæse et fremmed billede som native kode:

    AMD64 0x8664 ^ Linux 0x7B79 = 0xfd1d
    ARM64 0xAA64 ^ Apple 0x4644 = 0xec20

Konstanterne står i `dotnet/runtime`, tag `v9.0.19`,
`src/coreclr/inc/pedecoder.h` linje 96-112. `[V]`

Men kilderevisionen er den samme. `.version` i begge Microsoft-arkiver siger
`3f97250e38169d4fede59f43029c6d987c015eb4` og servicing-nummer
`9.0.120-servicing.26371.12`; kun RID-linjen skiller. Og begge `csc.dll` bærer
samme Roslyn-streng. `[V]`

Derfor står forudsigelsen for macOS stadig — men af en anden grund end i går:
oversætter-binæren er en anden fil, men den erklærede identitet er den samme, så
outputtet burde blive `4b3808d1…`, identisk med `ubuntu-vm`. `[I]`

Det giver en skarpere formulering end i går:

> I går: to oversættere med identisk kode, forskellige metadata-strenge, gav
> forskelligt output. Forudsigelsen nu: to oversættere med forskellige bytes og
> forskellig maskinkode, samme metadata-streng, giver identisk output.

Det er ikke oversætterens bytes der bestemmer outputtet. Det er den identitet
oversætteren påstår om sig selv.

## macOS-vejen

`dotnet-install.sh` er den eneste måde at ramme 9.0.120 på en Mac. `[V]`

Homebrews `dotnet`-formel bygger fra kilde — kilde-URL er
`github.com/dotnet/dotnet`, samme samlede kildetræ Arch-pakken bruger, med
`cmake`, `pkgconf`, `rapidjson` og `llvm@20` som byggeafhængigheder. `dotnet@9`
findes, men er på 9.0.121. Casket `dotnet-sdk` er Microsofts rigtige `.pkg`, men
kun i nyeste version (10.0.401).

Verifikationen er `3f97250e38`. Microsoft bygger én kilderevision til alle
platforme, så commit-feltet er RID-uafhængigt. Siger Peters Mac noget andet, er
det et andet byg.

reprotest kan ikke køre på macOS: ingen Homebrew-formel, og modulet kalder
`unshare`, `setarch`, `domainname`, `disorderfs` og `faketime`. Manualsiden
siger selv at kun Debian- og RPM-baserede pakker understøttes. Macen kan altså
bidrage til eksperiment 1 og 3, ikke til akserne. `[V]`

## Læringer der ikke hører til ét eksperiment

**Proveniensen ligger i PDB'en, ikke i assembly'en.** PDB'en er 10.352 bytes mod
DLL'ens 3.072 — 3,4 gange større for en klasse på to linjer. `#Blob` er 96
procent af filen og indeholder 164 reference-assemblies nævnt ved navn og MVID.
DLL'en nævner én `AssemblyRef`, fordi den kun behøver `System.Runtime` for at
køre. `[V]`

Konsekvensen: vil man vide hvad et byg bestod af — hvilke referencer, hvilke
kildefiler med hvilke hashes, hvilken oversætter — står svaret i
fejlsøgningsfilen. Bygges der uden PDB, eller udgives PDB'erne ikke sammen med
binærerne, findes den maskinlæsbare optegnelse ikke længere.

**ECMA-335 stopper hvor reproducerbarheden begynder.** Søgt igennem 6. udgave
(juni 2012): nul træf på "Debug Directory", "IMAGE_DEBUG" og "Portable PDB".
"reproducible" står tre gange, alle tre om flydende-komma-præcision (s. 317).
Metadataformatet og PE-udvidelserne er standardiseret; debug directory,
`CodeView`, `PDB Checksum`, `Repro`-posten, Portable PDB-formatet og
`CompilationOptions` findes kun i Microsofts egne dokumenter, som de kan ændre
uden en revision. `[V]`

Det rimer på udgangspunktet fra PEMS-siden: standarden beskriver instrumentet,
mens mekanismen der afgør identiteten står uden for den.

**Microsoft sammenligner selv commit-hash, ikke versionsnummer.**
`GetCommitHash()` findes fordi oversætter-klienten og `VBCSCompiler`-serveren
skal afgøre om de er samme byg før de taler sammen. De har altså selv
konkluderet at `9.0.120` ikke identificerer en binær. Det er stadig en
strengsammenligning, ikke en hash af bytes — ét skridt videre end
compliance-dokumentation normalt er, og ét skridt fra det vi argumenterer for.

**En PDB er ikke en PE-fil.** `minlib.dll` starter på `4d 5a` (`MZ`);
`minlib.pdb` starter på `42 53 4a 42` (`BSJB`). PDB'en er ren metadata uden
container, fordi den kun læses og aldrig indlæses som kode. `objdump -p` svarer
"file format not recognized" på den, og det er det rigtige svar. `[V]`

I DLL'en ligger `BSJB` på offset 596, og de tolv bytes lige før den er hele
programmet:

    0e 1f 2a 2a 1e 02 28 0c 00 00 0a 2a    IL-koden, 12 bytes
    42 53 4a 42                            metadataen begynder, 1212 bytes

Forholdet mellem beskrivelse og kode er hundrede til én.

## Håndværk der virkede

`ildasm` findes til linux-x64 som NuGet-pakke,
`runtime.linux-x64.Microsoft.NETCore.ILDAsm`. Den giver samme manifest-format
som Microsofts dokumentation viser, og erstatter den håndskrevne PE-parsing.
To forbehold: brug `-caverbal`, ellers kommer attributværdier ud som hex, og
brug `-` frem for `/`, som Linux-byggets argumentparser ikke forstår. Den kan
ikke printe 64-bit hex — `.imagebase`, `.stackreserve` og tabel-bitmasken kommer
ud som `0x%016I64x`.

`objdump -p` skriver selv "This is a reproducible build file hash, not a
timestamp" om `TimeDateStamp`. Det er et uafhængigt værktøj — GNU binutils, ikke
Microsofts — der behandler feltet som en hash. Værd at citere. Den kender ikke
posten af type 19 og kalder den `Unknown`.

`strings -a -n 2` på PDB'en giver hele CompilationOptions-blokken. Standard
`strings` kræver fire tegn i træk; med to bliver nøgle-værdi-parrene hver sin
linje.

`grep -abo BSJB fil.dll` giver byte-offsettet på metadataen uden nogen parsing.

## Rettelser til tidligere formuleringer

Forudsigelsen om at Microsofts `csc.dll` var den samme fil på tværs af RID'er
var forkert. Den er platformspecifik, fordi den er ReadyToRun. Konklusionen om
macOS holder, men begrundelsen er en anden: det er den erklærede identitet der
er fælles, ikke binæren.

Gårsdagens note linker til `2026-09-08-empty-class.md` og
`2026-09-08-environment-axes.md`. Begge filer er siden omdøbt, så de to
henvisninger peger ingen steder. Ikke rettet i selve notatet — en note der
optager en kørsel skrives ikke om.

## Forbehold

macOS-forudsigelsen er `[I]`. Ingen af os har kørt et byg på en Mac endnu.

Rækkefølgen inde i `csc` — at `MVID` og `TimeDateStamp` stemples før `PDB-id` og
`PDB-checksum` — er en slutning ud fra at felterne skal patches efter en
indholdshash. Det målte er at DLL'en indeholder PDB'ens id og checksum.

`GetCommitHash()` sidder i `BuildProtocolConstants`, altså protokollen mellem
oversætter-klient og -server. Det er ikke bevist at PDB-skriveren bruger den
samme læser. At strengen rejser fra `csc.dll` til PDB'en er derimod målt direkte.

Om `Repro`-posten overlever `DebugType=none` er ukendt.

Kanalen via referencesættet er ikke testet. At 164 assemblies med MVID står i
PDB'ens `#Blob` er målt; at en anden targeting pack derfor ændrer DLL'en, følger
af kæden men er ikke efterprøvet.

Målingerne af Homebrew er læst ud af `formulae.brew.sh`' API, ikke ud af en
Mac. Hvad Peter faktisk har installeret, ved vi først når han kører
`dotnet --info`.

## I morgen

1. Miljøakserne. Seks på `arch`, syv på `ubuntu-vm`. Notatet ligger klar og har
   ligget klar to dage.
2. Peters gentagelse af eksperiment 1 på `ubuntu-vm`, og hans `csc.dll`-hash fra
   Macen — forventet `644a4d33…` hvis han har Microsofts SDK til x64, eller
   `1824569732a63f5d…` hvis Macen er ARM64.
3. `DebugType=none` med hver af de to oversættere. Forventningen: samme hash for
   begge, og forskellig fra både `541bed82…` og `4b3808d1…`. Rammer de hinanden,
   er kanalen isoleret til PDB'en.
