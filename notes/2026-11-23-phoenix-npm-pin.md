# One pinned npm for the frontend lock: E1-S3-08 closed (23 November 2026)

Grounds: the change `765ea6aa2` on the WS branch, measured on Leo's Mac
Studio (`macstudio`), on GitHub's runners (two runs of a temporary
workflow on the branch) and on `arch` over SSH. Done by Claude in a side
session of the writing session, with Leo's go-ahead to push to the
branch for the GitHub runs.

## Question

The frontend lock was written by the developers' npm 11, while the
release ran npm 10.9.9, the npm Node 22.23.3 bundles. npm 10's lock
writer has no `libc` field (E1-S3-08, W46). Can one npm version, pinned
by hash as Node is, both write the lock and install from it? With it,
does `npm ci` on real Linux (glibc) install the same packages, and do
builds of one commit give the same export on every machine?

## Expectation

None in a note before the runs. In the session, before the first
measurement, the expectation was: the pinned npm installs on Linux what
the release installed before, and the export does not change. The
musl builds turned out to differ (Result 3).

## Setup

- **What was found in npm's source:**
  - npm 10.9.9's writer leaves `libc` out
    (`@npmcli/arborist/lib/shrinkwrap.js:85-105`); npm 11.21.2's has it.
    That is the only field in which their lists differ.
  - npm 10.9.9 does read `libc` from a lock entry
    (`load-virtual.js:268`) and checks it (`reify.js:717-727`).
  - The branch's lock at `2cd85fd01` had no `libc` left: the merge of
    13/10 took main's lock, which had none.
- **The change (`765ea6aa2`):**
  - `package.json` gets `"packageManager": "npm@11.21.2+sha512.<hex>"`,
    the format `mcp/web` already uses for pnpm.
  - The `install-node` action installs that tarball from
    registry.npmjs.org after Node, checks its SHA-512, and stops unless
    `npm --version` matches.
  - The WebAPI Dockerfile does the same on its SPA path.
  - npm 11.21.2 rewrote the lock: it resolved the 68 platform entries
    again. Their parents name exact versions.

  11.21.2 is the newest npm 11 at least seven days old, as the repo's own
  `min-release-age=7` asks.
- **`macstudio`:** Node 22.23.3 from nodejs.org (SHA-256 checked). The
  "Linux" installs ran with npm's `--os=linux --cpu=x64 --libc=glibc`
  overrides. Stage 3's `build.sh` (SHA-256 `04ea8b35…`) ran in
  `git archive` labs.
- **GitHub:** a workflow `zz-thesis-npm-pin-test.yml`, added to the
  branch and removed again. No other workflow fires on a push to the
  branch.
  - [Run 45190675131](https://github.com/Weel-Sandvig/WS.Phoenix/actions/runs/45190675131):
    - the release's frontend job on `ubuntu-24.04` (with lint and jest)
      and on `ws-office`, the release's runner;
    - the install step against wrong pins;
    - the WebAPI image with `SKIP_SPA_BUILD=false`;
    - actionlint, shellcheck and hadolint.
  - [Run 45193962026](https://github.com/Weel-Sandvig/WS.Phoenix/actions/runs/45193962026):
    `build.sh` twice on `ubuntu-24.04`, and actionlint on the changed
    workflows.
- **`arch`:** Node 22.23.3 and npm 11.21.2, both checked by hash. An
  online `npm ci`, then `build.sh` in two labs.

## Commands

Verbatim in `data/2026-11-23-phoenix-npm-pin/<machine>/kommando.txt`.

## Result

`[V]` throughout (`results.txt` per machine).

1. **The lock:**
   - npm 11.21.2 re-resolved the 68 platform entries: 1407 entries
     before and after, no version, URL or hash changed, and 36 entries
     gained `libc` (+108 lines, −0).
   - Another pass of the same npm, `install --package-lock-only` or a
     full `npm install`, leaves the file byte-identical.
   - npm 10.9.9's full `npm install` strips the 36 again.
2. **The export:** the same 995 files, list SHA-256 `887db5f9…`, in
   every build:

   | Machine | Builds |
   | --- | --- |
   | `macstudio` | `build.sh` three times on two paths, plus once at `2cd85fd01` with npm 10.9.9 |
   | GitHub `ubuntu-24.04`, glibc 2.39 | `build.sh` twice on two paths, plus the release's frontend job once, in a checkout, with lint and jest |
   | `ws-office` | the release's frontend job |
   | `arch`, glibc 2.44 | `build.sh` twice on two paths |
3. **The install on glibc Linux:**
   - With the pinned npm and the new lock, it is 1336 packages and
     109,839 files, the same on GitHub and on `arch`. Both equal
     `macstudio`'s simulation: the same package list, and every file the
     same path and SHA-256.
   - The release's install before (npm 10.9.9, the old lock), simulated,
     had 1343 packages. The new one leaves out the five x64 musl builds,
     and `@img/sharp-wasm32` with its runtime, which only sharp's
     freebsd and wasm32 builds need. It adds nothing.
   - Every file the new install has is the same in the old.
4. **The image** (`SKIP_SPA_BUILD=false`, GitHub):
   - The Dockerfile checked `npm-11.21.2.tgz`, and npm reported 11.21.2.
   - `wwwroot` holds the 995 export files unchanged, plus 63 files of the
     Identity UI.
   - With a wrong hash, the build stopped at the check.
5. **The install step on a runner:** a wrong hash, another version with
   this version's hash, and no field each failed it. The committed pin
   passed.
6. **Linters:**
   - actionlint 1.7.12 with shellcheck: nothing in the changed
     workflows. On all workflows, notes (SC2086, SC2035, SC2129) on lines
     the change does not touch.
   - hadolint 2.15.1, at PR validation's threshold: DL3003 on two lines
     of the WebAPI Dockerfile, one from the earlier Node pin and one from
     this change. Fixed after the merge (`30b5c745d`).

## Interpretation

- **E1-S3-08 is closed.** `[V]` One npm writes the lock and installs from
  it. It is pinned by hash, as Node is, and every frontend path uses it.
  The lock is that npm's fixed point.
- **The fix holds on real Linux with glibc.** `[V]` On two machines with
  different glibc versions the install is the same, file for file, and
  the export is the same on four machines and two operating systems.
- **The pin changes what is installed, not what ships.** `[V]` Seven
  unused packages fewer on Linux, and the same export as before the
  change.
- **Pinning npm 10.9.9 would not have done it.** `[V]` Its writer drops
  `libc`, so a lock it writes makes a glibc runner install the musl
  builds too.

## Caveats

- Nothing stops a developer's own npm from writing the lock. An npm 10
  `npm install` strips `libc` again. Neither of the two possible guards
  is in the change:
  - `devEngines` in `package.json`, which npm checks only on `npm run`;
  - a CI check that rewrites the lock with the pinned npm and diffs it.
- The release workflow itself (a tag) did not run. Its frontend job ran
  as the release calls it, on the release's runner.

## Not tested

- arm64 Linux.
- main's npm audit gate under npm 11.21.2. It is only in the later merge.
