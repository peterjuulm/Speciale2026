# The release workflow on GitHub with the fixes, 14 October 2026

## Question

The second dry run of the release workflow; the first was
[phoenix-ci-dry-run](2026-10-13-phoenix-ci-dry-run.md) on 13/10. Since
then the WS branch installs exactly the SDK in `global.json`, alone, in
every job (W58); checks each signed release by pasting its signatures
onto the unsigned build ([phoenix-signing](2026-10-14-phoenix-signing.md));
fixes the locale before SHA256SUMS; and builds the MCP images with
pinned bases and without what records the build
([phoenix-shipped](2026-10-14-phoenix-shipped.md)). Does every output of
the run now equal a local rebuild, with nothing added to the local SDK?
And do the release job's new steps work on GitHub's runners?

## Setup

Run by Claude at Leo's request, on his conditions for runs on GitHub
(13/10). A throwaway commit on the branch head `3c375938` changes three
workflow files with a script kept in private data, as on 13/10:

- No `build-and-test`, so no tests; no GitHub Release: the `release` job
  stops after writing SHA256SUMS and uploads it.
- `docker-images`: no registry login and no push. All five images, the
  two .NET images and the three MCP images, are written as OCI tarballs
  with `rewrite-timestamp=true` and uploaded as artifacts, kept one day.
  No `gha` cache.
- `publish-windows` on `ubuntu-latest`, without the `release-signing`
  environment. The binaries are signed with a throwaway CA and
  certificate made in the job, through the signing image's
  `SIGN_WITH_KEYSTORE` path, with timestamps from the release's RFC 3161
  server. The job's new check runs as it would in a release, with the
  test CA added to its trust. The CA's certificate is uploaded; the keys
  stay on the runner.
- A job on `windows-latest` runs the new SDK action, builds
  `ApplicationCore` and prints the runtime its PDB records.
- Every job is bounded to an hour: `gh` could not reach GitHub's API when
  the run began, as the keyring was locked, so the run starts unattended,
  and its artifacts, the run and the tag wait for Leo to unlock it.

The tag `v0.0.0-thesis.3` on that commit starts the run; only the tag is
pushed.

The local side is `experiments/phoenix-rt/ci-local.sh`, extended today
with the SQL script and the MCP images, on `arch`, with the SDK the new
installer put in a folder of its own: runtime 10.0.12 only, nothing
added. The Windows outputs are checked as the signing README says a
rebuild is checked: CI's signatures pasted onto the local unsigned build
with `paste-signatures.sh`, then packed with the commit's packing script
(`ci-compare.sh`, extended today).

## Expectation, written before the run's results

All `[I]`.

1. Every job succeeds, the Windows job's check included. The PDB on
   `windows-latest` records runtime 10.0.12, though the runner has other
   .NET installed.
2. CI's frontend export equals the local one.
3. Both Linux zips, the Linux migrator and the SQL script equal the local
   ones byte for byte: CI's compiler ran on the SDK's own runtime, so W58
   is gone.
4. With CI's signatures pasted onto the local build, both Windows zips
   and the Windows migrator are CI's byte for byte.
5. All five images have the same image manifest in CI and here.
6. SHA256SUMS written here over the local outputs, the Windows ones
   pasted, equals CI's.
