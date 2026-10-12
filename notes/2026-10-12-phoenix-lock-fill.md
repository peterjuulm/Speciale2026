# Phoenix: restoring the frontend lock file's hashes (W41)

Experiment note, 12 October 2026, on `mac`. Run by Peter; the commands were
written by Claude. Data in `data/2026-10-12-phoenix-lock-fill/mac/`.

## Question

391 of the 1509 entries in `src/WebAPI/ClientApp/package-lock.json` have
neither `resolved` nor `integrity` (W41). Can the release pipeline's npm
(10.8.2 with Node 20.20.2) restore them without changing any version?

## Expectation, written before the run

None in a note. In the session, before the first npm command: it was not
known whether npm alone fills the fields. The plan was to try `npm install
--package-lock-only` first and a full `npm install` second, and to keep the
result only if no version changed (status board, Next up 1).

## Setup

- Node 20.20.2 for darwin-arm64 from nodejs.org, unpacked in `~/rb1-node`.
  The tarball's SHA-256 matched `SHASUMS256.txt`, and that file's signature
  checked against `nodejs/release-keys`. Homebrew's Node 22.23.2 with npm
  11.19.1 stays the default.
- Worked in the WS.Phoenix worktree on `thesis/reproducible-builds` at
  `a16eb506`, not in a lab: nothing is built, only the lock file changes,
  and git holds the original.
- npm ran under `env -i` with `HOME`, `PATH` (`~/rb1-node/bin` first) and
  `npm_config_update_notifier=false`.

## Commands

Verbatim in `kommando.txt`. After a count of the missing fields: `npm install
--package-lock-only`, then `npm install`, then `git checkout` of the lock
file, then `experiments/phoenix-fe/fill-lock.js`, then a count, a version
check against `HEAD` and `git diff --numstat`.

## Result

| Step | npm's summary | Missing after | Lock diff (+/-) |
| --- | --- | --- | --- |
| `install --package-lock-only` | up to date | 391 | none |
| `install`, old `node_modules` in place | added 160, removed 44, changed 94 | 391 | 0 / 90 |
| `git checkout` of the lock | | 391 | none |
| `fill-lock.js` | controls 20 of 20 match; filled 391 | 0 | 782 / 0 |

The 90 removed lines are the `libc` field of 30 platform packages, for
example `@img/sharp-*`. Against `HEAD` the filled file has 0 entries added,
0 removed and 0 versions changed. Committed as `e19ca414` on the branch.

## Interpretation

- **npm 10.8.2 cannot repair a v3 lock file** `[V]`, read in its source
  (`@npmcli/arborist`). In `reify.js:757-797`, an entry without `resolved`
  is fetched by `name@version`, but the URL and hash pacote returns are
  never written back to the entry. In `build-ideal-tree.js:660-663`, npm
  fetches missing metadata only for a lock with `lockfileVersion` below 2,
  that is, one written by npm 6, which never stored that data. A version 2
  or 3 file is trusted as complete; the code calls one with gaps "damaged".
- **What we did instead**: `fill-lock.js` asks the same npm,
  `npm view <name>@<version> version dist.tarball dist.integrity`, for the
  exact version already in the lock. No range is resolved, so no version can
  change. It writes only the two fields, after `version` as npm orders them,
  and only if every answer has the same version and 20 entries that already
  had both fields come back identical.
- **Where the fields went**: they were complete until `73430fb1`
  (9 April 2026), which rewrote the whole lock and left 486 entries without
  them `[V]`. Why is not established.
- **New, W46**: npm 10.8.2's lock writer has no `libc` in its list of saved
  fields; npm 11.19.1's has it (`shrinkwrap.js:98`) `[V]`. The committed lock
  has 30 `libc` fields, so a newer npm than the pipeline's wrote it. The
  lock's bytes depend on which npm writes it, and CI never writes it: it
  only runs `npm ci`.

## Caveats and not tested

- The new hashes come from the registry's metadata, not from hashing the
  tarballs here. The next online `npm ci` checks them against the bytes
  `[I]`.
- Leo's reprotest run of today uses `a16eb506`, before this commit. Its
  offline cache holds the same tarballs, so its installs should not differ
  `[I]`.
- Whether `npm ci` with npm 10.8.2 still sees `libc` when its reader drops
  the field is not tested. If not, CI on Linux could also install the musl
  variants `[I]`.
- The worktree's `node_modules` was changed by the full install. It is not
  in git and does not ship.
