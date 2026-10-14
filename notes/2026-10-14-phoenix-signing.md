# Signing the Windows release, and checking a rebuild against it, 14 October 2026

## Question

The release job signs every unsigned `.exe` and `.dll` in the Windows
publish, each with an RFC 3161 timestamp, and packs the zips after signing
([phoenix-windows-release](2026-10-13-phoenix-windows-release.md), W55).
Two runs of the job cannot give the same zips, and a rebuild can never
equal the release byte for byte. How can a rebuild still be checked
against a signed release, file for file and zip for zip?
reproducible-builds.org names three ways for embedded signatures: paste
the signature into the rebuilt artefact, ignore it in the comparison, or
strip it from the release ("Embedded signatures"). Bitcoin Core does the
first for its Windows binaries: signatures are made once, published
detached, and attached with osslsigncode in a second, reproducible build
stage. Which of the three works for this release, and exactly?

## Setup

Run by Claude at Leo's request, on `arch`. Two unsigned builds of
`100e3912`'s Windows release, from the reruns of 13-14/10: the first
builds of `W2-none` and `W2-all`, the same bytes. `A` stands in for the
release, `B` for a rebuild. The WS signing image (`deployment/signing`:
Ubuntu 26.04 by digest, jsign 7.5 by checksum, osslsigncode 2.13), built
here, run as the job runs it, with the image's own path for local signing:
`SIGN_WITH_KEYSTORE` with a throwaway test certificate made for this run
(a CA and a code-signing certificate from openssl). Timestamps come from
the release's own RFC 3161 server.

The steps:

0. Unzip both builds' zips; pack `A`'s trees again with
   `scripts/pack-release-zip.sh` and the commit's time.
1. Sign two copies of `A`, `A1` and `A2`, each with `sign-windows.sh`.
2. Strip: `osslsigncode remove-signature` on every file signed in `A1`;
   compare with `A`.
3. Paste: `osslsigncode extract-signature` from every file signed in
   `A1`, `attach-signature` onto the same file in `B`; compare with `A1`;
   verify; pack, and compare with `A1`'s zips.
4. A negative control: one byte of `B`'s `ApplicationCore.dll` changed
   before pasting.

## Expectation, written before the run

All `[I]`.

0. Packing an unzipped tree again gives back its zip byte for byte.
1. `A1` and `A2` differ in every file signed and in both zips. Files
   already signed by their vendors are left alone, the same in both.
2. Stripping gives back `A` except for the PE checksum, which signing
   sets and stripping does not reset.
3. Pasting gives `A1` byte for byte: every signed file, both zips; and
   the pasted signatures verify.
4. With the changed byte, the pasted signature does not verify.

Added at 06:38, after the run, before step 3b: every `attach-signature`
in step 3 failed. osslsigncode verifies the result as it attaches it, and
with no `-CAfile` it trusts the system's store, which holds neither the
test CA nor the Microsoft root the timestamps chain to. Codex, consulted
on the design meanwhile, pointed out a second trap: a file written by
`attach-signature` is new, so it may lose the executable bit that
`pack-release-zip.sh` reads the mode from. Step 3b repeats step 3 with
`-CAfile` and `-TSA-CAfile` given the same trust file as the verification,
and each pasted file given its rebuilt twin's mode; and two more negative
controls: `A1`'s signature of one file attached to another, and one byte
changed in the migrator's bundle, the data after its PE image.

3b. Pasting gives `A1` byte for byte: all 177 signed files and both zips;
    the pasted signatures verify. Both new negative controls fail to
    attach.


## Commands

Verbatim in `data/2026-10-14-phoenix-signing/arch/kommando.txt`; the
scripts are `experiments/phoenix-rt/signing-probe.sh` (steps 0-4) and
`signing-paste.sh` (step 3b).

## Result

`[V]` (lists and logs in private data: `probe.out`, `paste2.out`,
`paste-tool-tests.txt`). The probe 06:30-06:36, step 3b 06:39-06:40.

0. Held. Both zips packed again from their unzipped trees are the same
   files.
1. Held. 1048 PE files, of which 177 unsigned: our assemblies, the app
   hosts, the migrator and the unsigned third-party files. `A1` and `A2`
   each differ from `A` in exactly those 177, and from each other in all
   177; the 871 files their vendors signed and every non-PE file are left
   alone. Both zips differ between `A1` and `A2`.
2. Held, with one more kind of difference. Stripping gives back 123 of the
   177 files byte for byte. 53 differ in the PE checksum only. The
   migrator differs in the checksum and in length: 7 bytes more than `A`
   (530636265 to 530636272), the padding signing added before the
   signature, which stripping keeps.
3. Failed as run: all 177 `attach-signature` calls failed, so nothing was
   pasted (see the addendum above).
3b. Held. 0 failures; all 1048 PE files are `A1`'s byte for byte, and all
    2130 files have `A1`'s paths and modes. All 177 pasted signatures
    verify, timestamps included. Both zips packed from the pasted tree
    are `A1`'s zips byte for byte, and the pasted migrator is `A1`'s. Both
    new negative controls fail: another file's signature does not attach
    (`MISMATCH` of the message digest), nor does the migrator's signature
    once a byte of its bundle has changed.
4. Held. With one bit of `ApplicationCore.dll` changed, `attach-signature`
   refuses (exit 1) and `verify` reports the digest mismatch.

The same procedure as a tool for WS, 06:45-06:47: on the WS branch,
`deployment/signing/paste-signatures.sh` in the signing image. It finds
the binaries signed in the release and unsigned in the rebuild, attaches
each signature with the trust file, keeps the rebuilt file's mode,
verifies signature and timestamp, and compares every file's name, bytes
and mode with the release. On `A1` against `B`: 177 pasted, 2130 files
the same, exit 0; its output packed with `pack-release-zip.sh` gives both
of `A1`'s zips byte for byte, and its migrator is `A1`'s. One changed
byte in a rebuilt DLL: that signature fails, the file is named, exit 1.
One extra file in the rebuild: named, exit 1.

## Interpretation

**A signed release can be rebuilt byte for byte: paste its signatures.**
`[V]` for this release and a test certificate. The unsigned build is the
same in two builds (W55), and the signature is the only input a rebuilder
cannot make. Taking it from the release, the rebuild gives back every
signed file and both zips exactly. The comparison stays strict: nothing
is ignored, and every file's bytes are compared at the end. Before
that, a signature would not attach to a DLL with one bit changed, nor
to the migrator with one bit of its bundle changed, the two changes
tested. This is the approach reproducible-builds.org calls
pasting, and the one Bitcoin Core uses for its Windows binaries `[I]`.

**Stripping is a weaker check.** `[V]` `remove-signature` leaves the PE
checksum and, for the migrator, the padding, so a stripped release never
equals the unsigned build without a rule for which bytes to ignore. Such
a rule is a judgement each verifier would have to trust. It still serves
to diagnose which bytes differ.

**The tool has to give the trust file and the mode.** `[V]`
`attach-signature` verifies against the system's store unless `-CAfile`
and `-TSA-CAfile` are given; and it writes a new file, so 171 of the 177
signed files would lose the executable bit that the zips record. Both
traps are inside `paste-signatures.sh` now, not in each verifier's hands.

**The release job can prove each release checkable.** `[I]` The job now
keeps the unsigned tree before signing and runs the tool on its own
output afterwards; a release whose signatures do not paste back fails
before it is packed. This needs the job itself to run, with the real
signing service: not tested.

## Caveats

- A throwaway certificate from openssl, not WS's certificate through
  Azure Artifact Signing. jsign makes the signature either way; the
  service's certificate chain and its timestamp policy were not used.
- The timestamps came from the release's own RFC 3161 server, so they
  are real, but taken on one morning.
- One build pair, one machine, one osslsigncode (2.13 from Ubuntu's
  archive, unpinned in the image).

## Not tested

- The release job's new steps on a runner, and signing through Azure.
- A verifier with another osslsigncode version.
