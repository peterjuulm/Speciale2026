# What a release should say about itself: practice, standards and Phoenix today (14 October 2026)

Grounds: four surveys made on 14/10, three on the web and one of the
local literature; and our own reads of the reference release
`v0.0.0-thesis.6`
([phoenix-reference-release](2026-10-14-phoenix-reference-release.md)).
The surveys were run by research agents with instructions to cite a
source for every claim. `[V]` below means the survey read the claim in
the source that day, or we read it in our own files; `[I]` means memory
or inference. Sources are at the end, keyed A (reproducible-builds
projects), B (attestations and signing), C (SBOMs and regulation) and D
(the local literature). Codex (Astra) reviewed a first draft at 13:43;
its corrections are folded in.

## Question

How should Phoenix document, per release, what it ships, what it was
built with, and how a third party can verify and rebuild it? The
readers are WS's customers and their auditors, WS itself, and the
thesis. What do comparable projects do, and what do the standards and
regulation ask?

## What the domain asks

- EN 17255-2 requires the software version in every report (6.5.1),
  the version of all software elements for any point in time on request
  (6.5.3), an event log of all actions (6.7.1), configuration changes
  with old and new values (6.7.2), and unique identification codes for
  hardware and software (6.8.5). `[V]` D3
- It never ties a version or an identification code to the installed
  binary: none of the words checksum, hash or signature occurs in it,
  and it defines neither "version" nor "identification code". `[V]` D3
- OIML D31 (2023), for software-controlled measuring instruments,
  defines software identification as a readable sequence, unique,
  protected, shown on command and changed by any software change. It
  names a version string for normal risk and a checksum of the
  executable for raised risk. `[V]` D1 p. 15, 20-21
- D31's example examination report lists every source file with size,
  date and SHA-256, the manuals with SHA-256, and the executable's
  checksum; the 2019 edition had no per-file hashes. `[V]` D1 p. 70-71
- A "traced update" in D31 needs an integrity check (checksum or hash),
  an origin check (for example a signature) and an audit-trail entry
  with the installed and previous identification, time and source.
  `[V]` D1 p. 44-45
- WELMEC 7.2 (2021) requires, from risk class C, that each instrument's
  legally relevant binary equal the type examined, with bit-level
  identity from class C. `[V]` D2 p. 17-18, 147
- Neither D31 edition nor WELMEC's 2026 draft extract mentions SBOMs,
  toolchains, reproducible builds or the supply chain. `[V]` D1, D2

## What reproducible-builds projects publish

Debian, Arch Linux, Bitcoin Core, Tor Browser, F-Droid, Nix and Guix,
Go and Maven's Reproducible Central, read on 14/10 (A).

- Every one publishes a plain hash list of its outputs and a record of
  the build environment: Debian's signed `.buildinfo` with every
  build dependency's version and every output's SHA-256, Arch's
  `.BUILDINFO` inside each package, Maven's `.buildspec`, Go's build
  information inside each binary (`go version -m`). `[V]` A-D1, A-D2,
  A-A1, A-M2, A-G5
- The source is named by tag or commit, and the inputs are kept
  retrievable: snapshot.debian.org, the Arch Archive, a pinned Guix
  commit, Go's toolchain modules. `[V]` A-D5, A-A4, A-N4, A-G3
- Signatures stay outside the bytes compared. Bitcoin Core and Tor
  Browser publish an unsigned and a signed hash list; Bitcoin keeps the
  macOS and Windows signatures in a separate repository. F-Droid
  rebuilds unsigned, copies the developer's signature onto its rebuild,
  checks it, and compares bytes; it also pins the signer certificate's
  SHA-256. Go strips code signatures before comparing. `[V]` A-B2, A-B7,
  A-T1, A-F1, A-G2
- Several builders or rebuilders sign their results, sometimes with a
  threshold: Bitcoin Core combines the signatures once six or more
  builders match, and an apt transport accepts X of N rebuilders'
  in-toto attestations. Eclipse Temurin takes third-party-signed
  reproduction claims by pull request. `[V]` A-B3, A-D9, C-S22
- Each ships its verifier as a program: `verify.py`, `debrebuild`,
  `makerepropkg`, `gorebuild`, `guix challenge`, `rebuild.sh`. `[V]`
  A-B4, A-D7, A-A2, A-G2, A-N1, A-M3
- reproducible-builds.org asks that the environment be recorded and
  shipped with each binary, at least the tool versions, and lists three
  ways to handle embedded signatures: paste them in as a build input,
  compare with a tool that skips them, or strip them. `[V]` A-R2, A-R4

## Attestations and signing: what exists, what it costs, what it shows

- SLSA v1.2 (November 2025): Build L1 asks that provenance exist, L2
  that the hosted platform sign it, L3 for hardened, isolated builds
  whose steps cannot reach the signing secrets. Reproducible builds are
  not required, but SLSA names independent rebuilders as one way to
  verify. Its Verification Summary Attestation (VSA) states a verdict
  without the pipeline's details. `[V]` B-1, B-2, B-5, B-7
- in-toto Statement v1 binds a predicate to subjects by digest. Its
  predicates include SLSA provenance, VSA, SPDX, CycloneDX, test
  results and a release predicate (v0.2). `[V]` B-8, B-9, B-11
- GitHub's artifact attestations work on private repositories only with
  GitHub Enterprise Cloud. `[V]` B-24
- Sigstore's keyless signing writes the repository, workflow, tag,
  commit and run URL into a public, permanent transparency log; Docker
  verifies its hardened images with the log switched off to keep
  customer data out of it. Signing with keys one controls, without the
  log, avoids this. `[V]` B-14, B-15, B-19, B-20
- BuildKit's provenance always carries `invocationId` and the build's
  start and finish times, so it is never byte-reproducible; the image
  index that holds it differs per build. `[V]` B-30, and W65. It does
  name the build's base images by digest, the SDK image included, and
  the SBOM scanner by its moving tag. `[V]` our read of the release
  below
- GHCR has no OCI Referrers API, so signatures and SBOMs attached as
  referrers fall back to tags there. `[V]` B-43
- Microsoft signs every supported .NET container image with Notation
  through Azure Artifact Signing, the service WS signs its Windows
  binaries with. `[V]` B-45, B-55, B-56

## SBOMs and regulation

- The EU Cyber Resilience Act likely covers Phoenix's zips and images:
  software supplied to customers and run on their systems. `[V]` C-S2
  for the reading of "product"; whether no exclusion applies is `[I]`.
- Its main obligations apply from 11 December 2027; vulnerability
  reporting (Art. 14) has applied since 11 September 2026, also to
  products already on the market. `[V]` C-S1, C-S3, C-S4
- The CRA's SBOM floor is low: a machine-readable SBOM in a commonly
  used format, covering at least the top-level dependencies, kept in
  the technical documentation and given to a market surveillance
  authority on reasoned request. Giving it to users is the
  manufacturer's choice. The documentation is kept for ten years or
  the support period, whichever is longer. `[V]` C-S1
- No implementing act fixes an SBOM format yet, and no harmonised
  standard is cited; prEN 40000-1-3 asks that own components be fully
  identified, third-party ones at the direct level. `[V]` C-S1, C-S6;
  the absence of an act is `[I]`.
- BSI TR-03183-2 v2.1.0 (August 2025) is stricter: CycloneDX 1.6+ or
  SPDX 3.0.1+, per component the SHA-512 of the deployable file and
  dependencies down to the first component outside the delivery, one
  SBOM per version, no vulnerability data inside, signing recommended.
  It notes that hashes identify components only if the build is
  reproducible. `[V]` C-S12
- CISA's Minimum Elements 2026, co-signed by 18 agencies including BSI
  and ANSSI, add an author signature, the generating tool and its
  version, a component hash and the licence, one SBOM per release.
  `[V]` C-S11
- Byte-stable SBOMs need pinned fields: CycloneDX's `serialNumber` and
  timestamp, SPDX's creation time and document namespace. Microsoft's
  `sbom-tool` can fix both, syft cannot yet (an open pull request).
  `[V]` C-S16, C-S17, C-S18, C-S21
- IEC 62443-4-1 requires no SBOM, but asks for a process for external
  components and update documentation naming the affected versions and
  how to verify a patch. `[V]` C-S26
- NIST's SSDF (SP 800-218) asks for a way for acquirers to verify a
  release's integrity (PS.2) and for each release to be archived with
  its integrity and provenance data (PS.3). `[I]` cited by Codex's
  review, not read here
- Vendors differ: Microsoft puts an SPDX manifest with per-file hashes
  inside each build's output; Schneider Electric has required an SBOM
  per production release since 2021; HashiCorp publishes SHA256SUMS and
  a detached signature, no SBOM. `[V]` C-S19, C-S24, C-S23

## What Phoenix ships today

Read in `v0.0.0-thesis.6`'s files and registry entries on 14/10, field
names only where personal data is involved. `[V]` That is a prerelease
of the thesis branch; main's release workflow configures the same
SHA256SUMS and the same image attestations (`provenance: true`,
`sbom: true` on all five images), so the metadata is the same in kind
`[V]`, the counts are this release's.

- The zips: SHA256SUMS lists them with the migrators, the SQL script
  and `upgrade.sh`, as plain text without a signature. The WebAPI zip's
  `WebAPI.deps.json` lists its 206 NuGet packages, each with a SHA-512,
  but there is no SBOM and no build record. Its assemblies carry the
  version and the full commit (`v0.0.0-thesis.6+be5fc56e…`).
- The frontend inside the zips lists none of the npm packages it
  bundles.
- The Windows binaries: 177 signed by WS through Azure, 871 signed by
  their vendors, of 1048.
- The images carry no OCI labels of their own: no source, commit or
  Phoenix version label. The two .NET images carry only
  `org.opencontainers.image.version=24.04`, inherited from their Ubuntu
  base. Their assemblies carry Phoenix's version, without the commit.
- Each image tag points at an index with an SPDX 2.3 SBOM made by
  syft 1.51.0 (read in two of the five images) and SLSA provenance in
  BuildKit's detailed mode. The provenance names the
  base images and the SDK image by digest. It also carries
  the GitHub run's context: the actor, the run's ids, the runner's name
  and image, and the whole event payload, including the pusher's name
  and email, the commit's author and committer with their emails, and
  the commit message. WS's last release, `v1.0.50`, carries the same
  name and email fields in its `ws-pems` image (read 14/10, field paths
  only). `[V]` Anyone with pull access can read them.
- GitHub Releases on a private repository; WS's plan has no artifact
  attestations.

## Interpretation

**Phoenix's records are partial and undocumented.** `[I]` The bytes can
now be rebuilt, and the images carry an SBOM and provenance. But the
zips have neither, SHA256SUMS covers the files and not the images and
is unsigned, and nothing tells a customer what the records are or how
to use them. Every reproducible-builds project above publishes a record
and the means to check it; Phoenix publishes hashes and raw tool
output.

**What the tools generate serves the pipeline, not the readers.** `[I]`
BuildKit's provenance names the base images and the SDK image, but not
the lock files that decide the packages, and it changes with every
build. It also carries the GitHub event payload, with personal data
such as names and email addresses that a customer-facing record does
not need. An auditor may still need the builder's identity, the times
and the run, so the raw provenance is internal evidence to keep, not
something to delete. The syft SBOM on the images is SPDX 2.3, below the
BSI profile's SPDX 3.0.1; the BSI profile is a target WS may choose,
not an obligation the research establishes.

**Signatures and rebuilds check different things.** `[I]` A signature
makes a record attributable to WS. A rebuild tests that the record's
outputs follow from its inputs. Neither proves an SBOM complete or the
software correct. Kettle's authors write that CI logs, signed checksums
and pipeline provenance "prove only that some system made a statement"
(D6 p. 2); reproducibility is what lets a third party test the output
claims of such a statement. An independent rebuild makes its own
provenance and its own verdict; it does not regenerate WS's.

**The shape that follows from the practice.** `[I]` In the order a
small team could introduce it, each step usable on its own:

1. One signed release manifest, generated by the pipeline, from which
   SHA256SUMS is derived. Its core is what a rebuild can regenerate:
   every deliverable by digest, each image by its `linux/amd64`
   manifest, the source as repository, tag and commit, and the inputs
   as SDK version and archive hash, Node, BuildKit, base image digests
   and lock-file hashes. Beside the core sit the release's own fields,
   which no rebuild reproduces: the published image indexes, which a
   download can be checked against, the date and the signature. A
   short human-readable summary and a download verifier go with it.
   The signature uses a key WS controls, with a named signer identity,
   a published key, and rules for rotation, revocation and replacing a
   release; public
   keyless Sigstore would publish WS's release history. The existing
   Azure signing service is the first place to look. Candidate formats:
   an in-toto Statement with SLSA provenance v1 and no `metadata` block
   (B-4), or CycloneDX's formulation.
2. One SBOM per deliverable, bound into the signed manifest by digest,
   in one supported format to begin with. Lock files and `deps.json`
   are a start, but coverage has to be checked against what is
   shipped: lock files can hold development packages and miss native
   or bundled components, and a package's hash is not an installed
   file's. An SBOM may sit inside an archive if it describes the
   payload; the archive's own hash then lives outside it.
3. The inputs preserved and a delayed rebuild automated: the rebuild
   recipe as a program WS owns, as `gorebuild` and `verify.py` are,
   run later on empty caches, with the release's signatures pasted by
   the WS branch's `paste-signatures.sh`. Each rebuild's result is kept
   as its own evidence. The reference release was rebuilt at once, with
   warm caches and Debian's live archive; hashes cannot bring back
   deleted inputs.
4. Vulnerability handling from now on, with an owner: reporting, triage
   and maintained assessments through the support period, a
   `security.txt`, and CSAF with VEX when customers or integrations ask
   for it. The research does not show CSAF to be mandatory.

Two questions sit beside the steps. Access: a customer can check a
download with the manifest and the public key, but an auditor who is to
rebuild needs the private source and the dependencies, which takes an
arrangement. Instructions: customers need the supported versions, the
migration requirements, the verification commands and a contact, in
plain words.

**The domain's missing binding.** `[I]` EN 17255-2 asks for a version
in every report but nothing that ties it to the bytes. D31 does that
for measuring instruments with a checksum of the executable at raised
risk. A release manifest's digest identifies a whole release as
distributed. Shown by the application, it would still be the
application's own statement: it names the package, not what actually
runs, its configuration or its models, unless the application computes
it over its own files, as a D31 checksum of the executable would be.
Whether and how is a question for WS, not settled here.

**What to avoid.** `[I]` Handing customers BuildKit's raw provenance;
claiming a SLSA level the setup does not meet (L2 needs
platform-signed provenance); a manifest that calls itself reproducible
as a whole when only its core is.

## Caveats

- The surveys were made in one day by research agents. Their `[V]`
  marks were checked in this note only where we could read the source
  ourselves: one survey claim was wrong. It said GitHub's context never
  reaches BuildKit's provenance; our release's provenance holds it, so
  the measurement stands.
- The CRA text was read in a secondary copy (EUR-Lex did not load), and
  the reading of scope is not legal advice.
- Standards are moving: CycloneDX 2.0 and SPDX 3.1 are announced, the
  CRA's harmonised standards are due from late 2026, and syft's
  deterministic mode is an open pull request.
- Vendor practice was read from public pages; what vendors give
  customers under NDA is not known.
- What Phoenix ships was read in one thesis prerelease. WS's production
  releases share its configuration, not necessarily its counts.

## Not checked

- CEN's own pages on the CRA standards; IEC 62443-4-1's paywalled
  clauses; EN 17255-1, -3 and -4.
- Whether Azure Artifact Signing, through Notation or otherwise, can
  sign files such as SHA256SUMS, and whether Notation works with GHCR.
- Whether GitHub's immutable releases work on WS's plan for a private
  repository.
- Whether BuildKit's minimal provenance mode still carries the GitHub
  context; only the detailed mode was read.
- Any SBOM tool run on Phoenix's zips, and the coverage of any SBOM
  against the files shipped.
- NIST SP 800-218's text (cited from Codex's review).

## Sources

A, reproducible-builds projects:
A-D1 https://wiki.debian.org/ReproducibleBuilds/BuildinfoFiles (2018-08-14);
A-D2 https://manpages.debian.org/testing/dpkg-dev/deb-buildinfo.5.en.html (2026-09-09);
A-D5 https://snapshot.debian.org/;
A-D7 https://manpages.debian.org/testing/devscripts/debrebuild.1.en.html (2026-10);
A-D9 https://lists.reproducible-builds.org/pipermail/rb-general/2025-November/003945.html (2025-11-26);
A-A1 https://man.archlinux.org/man/BUILDINFO.5 (2026-05-06);
A-A2 https://man.archlinux.org/man/makerepropkg.1 (2026-10-04);
A-A4 Arch wiki, Arch Linux Archive (2026-03-12);
A-B2 https://github.com/bitcoin-core/guix.sigs;
A-B3 https://github.com/bitcoin/bitcoin/blob/master/doc/release-process.md;
A-B4 https://github.com/bitcoin/bitcoin/tree/master/contrib/verify-binaries;
A-B7 https://github.com/bitcoin-core/bitcoin-detached-sigs;
A-T1 https://dist.torproject.org/torbrowser/15.0.25/ (2026-10-12);
A-F1 https://f-droid.org/docs/Reproducible_Builds/;
A-N1 https://guix.gnu.org/manual/en/html_node/Invoking-guix-challenge.html;
A-N4 https://guix.gnu.org/manual/en/html_node/Invoking-guix-time_002dmachine.html;
A-G2 https://pkg.go.dev/golang.org/x/build/cmd/gorebuild (2026-10-11);
A-G3 https://go.dev/doc/toolchain;
A-G5 https://pkg.go.dev/runtime/debug#BuildInfo;
A-M2 https://github.com/jvm-repo-rebuild/reproducible-central/blob/master/doc/BUILDSPEC.md;
A-M3 https://github.com/jvm-repo-rebuild/reproducible-central/blob/master/doc/TOOLS.md;
A-R2 https://reproducible-builds.org/docs/embedded-signatures/;
A-R4 https://reproducible-builds.org/docs/perimeter/.

B, attestations and signing:
B-1 https://slsa.dev/blog/2025/11/announce-slsa-v1.2 (2025-11-24);
B-2 https://slsa.dev/spec/v1.2/build-requirements;
B-4 https://slsa.dev/spec/v1.2/build-provenance;
B-5 https://slsa.dev/spec/v1.2/verification_summary;
B-7 https://slsa.dev/spec/v1.2/faq;
B-8 https://github.com/in-toto/attestation/tree/main/spec/predicates;
B-9 https://raw.githubusercontent.com/in-toto/attestation/main/spec/predicates/release.md;
B-11 https://docs.sigstore.dev/about/bundle/ (2025-01-14);
B-14 https://raw.githubusercontent.com/sigstore/fulcio/main/docs/oid-info.md;
B-15 https://raw.githubusercontent.com/sigstore/rekor/main/README.md;
B-19 https://docs.docker.com/dhi/how-to/verify/;
B-20 https://github.com/sigstore/cosign/releases/tag/v3.0.3 (2025-12);
B-24 https://raw.githubusercontent.com/actions/attest/main/README.md;
B-30 https://raw.githubusercontent.com/moby/buildkit/master/solver/llbsolver/provenance.go;
B-43 https://github.com/orgs/community/discussions/208532 (2026-09-22);
B-45 https://learn.microsoft.com/en-us/azure/container-registry/container-registry-tutorial-github-sign-notation-artifact-signing (2025-09-07);
B-55 https://raw.githubusercontent.com/dotnet/dotnet-docker/main/documentation/image-signatures.md;
B-56 https://github.com/dotnet/dotnet-docker/issues/4589 (closed 2026-04-14).

C, SBOMs and regulation:
C-S1 Regulation (EU) 2024/2847, Arts. 2, 13, 14, 69; Annexes I, II, VII, read at https://www.springlex.eu/en/packages/cra/cra-regulation/;
C-S2 https://ec.europa.eu/newsroom/dae/redirection/document/131456 (Commission guidance, 2026-07-27);
C-S3 https://ec.europa.eu/newsroom/dae/redirection/document/123307 (CRA FAQ, 2026-09-04);
C-S4 https://digital-strategy.ec.europa.eu/en/policies/cyber-resilience-act (2026-09-07);
C-S6 https://www.vulnir.com/cra/pren-40000-1-3-pre_fv/ (2026-08);
C-S11 https://www.cisa.gov/sites/default/files/2026-07/2026_cisa_sbom_minimum_elements_508c.pdf (2026-07-29);
C-S12 https://www.bsi.bund.de/SharedDocs/Downloads/EN/BSI/Publications/TechGuidelines/TR03183/BSI-TR-03183-2_v2_1_0.pdf (2025-08-20);
C-S16 https://spdx.dev/news/; https://spdx.github.io/spdx-spec/v3.0.1/model/Build/Classes/Build/;
C-S17 https://cyclonedx.org/news/cyclonedx-v2.0-coming-soon (2026-08-05); https://ecma-international.org/publications-and-standards/standards/ecma-424/;
C-S18 https://raw.githubusercontent.com/microsoft/sbom-tool/main/docs/sbom-tool-arguments.md;
C-S19 https://devblogs.microsoft.com/engineering-at-microsoft/generating-software-bills-of-materials-sboms-with-spdx-at-microsoft/ (2021-10-13);
C-S21 https://oss.anchore.com/docs/guides/sbom/formats/; https://github.com/anchore/syft/pull/3932 (2026-07);
C-S22 https://adoptium.net/news/2026/09/temurin-reproducible-verification-builds-2026/ (2026-09-02);
C-S23 https://releases.hashicorp.com/terraform/1.16.0/;
C-S24 https://www.pnnl.gov/sites/default/files/media/file/Leveraging%20SBOMs%20for%20Vulnerability%20Management%20Crossley.pdf;
C-S26 https://webstore.iec.ch/en/publication/33615.

D, the local literature (`literature/DRIVE-Litteratur/` in Leo's
working copy; in Drive under `Litterature/`):
D1 OIML D31 (2023) and (2019), Software controlled measuring instruments;
D2 WELMEC Guide 7.2 (2021) and its 2026 draft extract;
D3 EN 17255-2 (2020), printed page numbers;
D4 Lamb & Zacchiroli (2021);
D5 Benedetti et al. (2025);
D6 Asad & Arko (2026), Kettle.
