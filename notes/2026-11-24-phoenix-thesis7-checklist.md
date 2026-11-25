# Checklist for v0.0.0-thesis.7 (24 November 2026)

Grounds: the state of the WS branch `thesis/reproducible-builds` on the
afternoon of 24 November, after stages 0-2 of the release record
([phoenix-build-manifest](2026-11-24-phoenix-build-manifest.md)). Written
by Claude in a side session of the writing session, at Leo's request. Leo
gives the go for the tag himself. Nothing here has been run against a real
release yet.

## The tag

- **Name:** `v0.0.0-thesis.7`. It is a pre-release: a hyphen in the tag
  makes `03-release.yml` mark the GitHub Release as a pre-release, and it
  never moves `:latest`.
- **Commit:** the tip of `thesis/reproducible-builds` once dry run 5's
  temporary workflows are removed. Written for `c9e9022d0`; the branch
  then moved twice (`7d5c05eb0`, a rebuild.sh fix; `96e2990a6`, the SQL
  in the invariant culture), and the tag went on
  `96e2990a6128eed919eb216a3779f3d0613ce6cc` (`96e2990a6`) at 17:56 on
  24/11. The outcome is in
  [phoenix-thesis7-release](2026-11-24-phoenix-thesis7-release.md).
  No `zz-*` file may be in its tree:

  ```bash
  git ls-tree -r --name-only <commit> .github/workflows | grep zz
  ```

  This must print nothing.
- **Who:** Leo pushes the tag, or Claude on Leo's explicit word for this
  tag:

  ```bash
  git tag -a v0.0.0-thesis.7 <commit> -m "v0.0.0-thesis.7"
  git push origin refs/tags/v0.0.0-thesis.7
  ```

  The push starts `03-release.yml` (`on: push: tags: 'v*.*.*'`). Nothing
  else does.

## Before the tag

1. Main CI is green for that commit. The release's `validate-lookup`
   reuses a green Main CI run of the commit, or runs Main CI itself. The
   integration test `EntityFrameworkPerformanceTests.BatchQuery_VsIndividualQueries`
   is timing-based (batch at least 2× faster). On the office runner it
   failed in 2 of 3 Main CI runs on 24/11 (1.27×, 1.65×), and passed in
   the third and in that morning's manual checks. On `main` it has not
   failed recently.
   - If it fails on the tagged commit, rerun the failed job
     (`gh run rerun <id> --failed`) until green, before the tag or while
     the release waits: `validate-lookup` waits for a running Main CI.
   - Changing the test is WS's decision, not the branch's.
2. The last dry run (5) is green: done, [run 45403522195](https://github.com/Weel-Sandvig/WS.Phoenix/actions/runs/45403522195), on `8491a0d63`, whose tree is `c9e9022d0`'s plus the two temporary workflow files.
3. The Arch verify-twice against dry run 5 says SAME twice. It waits for
   Arch to be back on the office network.
4. Leo has decided whether the images' provenance files are published
   (now they are release assets) or kept internal.

## What to check on the published release

Run in a scratch folder:

```bash
gh release view v0.0.0-thesis.7 -R Weel-Sandvig/WS.Phoenix --json assets --jq '.assets[].name'
gh release download v0.0.0-thesis.7 -R Weel-Sandvig/WS.Phoenix -D published
```

- **20 assets:**
  - the four zips;
  - both migrators;
  - `bootstrap-postgresql-v0.0.0-thesis.7.sql`;
  - `upgrade.sh`;
  - `SHA256SUMS`;
  - `build-manifest.json`;
  - five `*-v0.0.0-thesis.7.spdx.json`;
  - five `*-v0.0.0-thesis.7.provenance.json`.
- **`SHA256SUMS`:** 8 lines; `cd published && sha256sum -c SHA256SUMS`
  says OK for all 8. It does not list `build-manifest.json`, the SBOMs or
  the provenance files.
- **`build-manifest.json`:**
  - 19 subjects: the 9 files, the 5 SBOMs and the 5 images. No
    `.provenance.json` among them.
  - Each file subject's SHA-256 equals the downloaded file's.
  - `predicate.buildDefinition.externalParameters.source.digest.gitCommit`
    is the tagged commit; `env.APP_VERSION` is `v0.0.0-thesis.7`.
- **Images:** for each of `ws-pems`, `ws-pems-job-worker`,
  `wspems-mcp-server`, `wspems-chat-server` and `wspems-mcp-auth-broker`:

  ```bash
  docker buildx imagetools inspect ghcr.io/weel-sandvig/<image>:v0.0.0-thesis.7
  ```

  - `MediaType` is an image manifest, not an index;
  - `Digest` equals the image's subject in `build-manifest.json`.

  The release job checks this itself after tagging and fails otherwise.
- **Provenance files:** no `github_` keys, e-mail addresses or names
  (dry run 4 had none). They hold build times and IDs; that is expected.
- **The release notes** end with the "How to rebuild this release"
  paragraph.

## The rebuilds after publication

### Arch

In a fresh clone, never Leo's `~/Dev/Weel-Sandvig/WS.Phoenix`, under the
memory guard. `rb1-tools` gives `zip`, and `rb1-docker` gives buildx:

```bash
git clone -q /private/tmp/rb1-merge-src /private/tmp/rb1-t7-src
git -C /private/tmp/rb1-t7-src fetch -q https://github.com/Weel-Sandvig/WS.Phoenix refs/tags/v0.0.0-thesis.7:refs/tags/v0.0.0-thesis.7
git -C /private/tmp/rb1-t7-src checkout -q v0.0.0-thesis.7
cd /private/tmp && PATH=/private/tmp/rb1-tools:$PATH DOCKER_CONFIG=/private/tmp/rb1-docker \
  /tmp/claude-1000/ws-mem-run.sh 14 bash /private/tmp/rb1-t7-src/scripts/release/rebuild.sh v0.0.0-thesis.7 /private/tmp/rb1-t7-work1
```

Then the same into `rb1-t7-work2`. The work folder needs about 20 GB.

### Mac Studio

**Not ready.**
- `rebuild.sh` supports Linux x64 only: `install-node.sh` pins only the
  linux-x64 and linux-arm64 Node archives, and the images need Linux.
- The Mac's colima VM and Docker were removed in the cleanup of 24/11.
- A Mac rebuild needs either a Linux x64 VM (colima with Rosetta, and the
  Rosetta fix now in the Dockerfiles), or a macOS port of the verifier.
  The port would need pinned darwin Node hashes in `node.sha256`, and an
  image build under emulation. Neither has been tried.

### What "identical" means

`rebuild.sh` ends with `SAME`: the `build-manifest.json` it writes from
the rebuilt files equals the published one, byte for byte. That covers:

- all 9 release files, the Windows ones after the published signatures
  are pasted;
- the 5 SBOMs;
- the 5 images' `linux/amd64` manifests.

The provenance files are not compared: they differ on every build. The two
work folders must also agree with each other (the release files, the
images' OCI manifests).

## Still blocking or open

- Dry run 5 and the Arch verify-twice against it: the verify-twice waits
  for Arch.
- Main CI green on the tagged commit (the flaky timing test).
- Leo's decision on publishing the provenance files.
- The Mac Studio rebuild path (above).
- Not run in any dry run, since they need the real tag and secrets:
  - the real signing environment (`release-signing`, Azure);
  - `windows-smoke`;
  - the GHCR push and the tagging with `--prefer-index=false`.

  The tagging was meant to be tried against a throwaway registry on Arch
  (`65-tag-digest.sh`). It has not run, and the release job checks the
  tag's digest itself.
