# The developers' commands on the WS branch, 13 October 2026

## Question

The WS branch changes how Phoenix restores, builds and versions itself:
locked NuGet restores (W22), one pinned SDK (`global.json`), deterministic
paths, `APP_VERSION` (W45), the design-time factories moved into the
startup projects (W52), a filled frontend lock (W41) and a pinned Node
(W40). Every check so far ran the release's commands or CI's. Do the
commands a developer runs every day, the Makefile's targets, still work on
the branch, and do they leave the committed files, the lock files above
all, as they are?

## Setup

Run by Claude at Leo's request, on `arch`, on the branch head `5ec085ac`,
with `experiments/phoenix-rt/dev-workflows.sh`. A shallow clone of the
branch stands in for a developer's checkout, so `git status` shows what a
developer would see after each command. SDK 10.0.401, Node 22.23.3 with
npm 10.9.9, an empty home folder, so no .NET user secrets are read. Every
step runs in its own user, network and PID namespace without a network,
and nothing it starts outlives it. NuGet and npm work from the caches of
the earlier runs; npm runs offline, without its audit and fund requests.

The developers' configuration points the design-time commands at
`localhost:5432`, the port of the developer's own database. So the
database steps run where `127.0.0.1:5432` leads only to a scratch
PostgreSQL 17 container: the container has no network, and inside the
namespace `socat` forwards that port to the container's Unix socket.
Main's design-time guard counts only `localhost` and `127.*` as local, not
a socket path, which is why the forward is needed.

## Expectation, written before the run

All `[I]`.

1. `make install-tools` and `make build` (Debug) succeed, and `git status`
   stays empty: the build changes no committed file, no lock file.
2. `make db-migrate` applies all 160 migrations to an empty database. With
   a remote host in the environment, main's guard stops it before any
   connection, with its message about a host that is not local.
3. `make db-migration-add` runs through the WebAPI's design-time factory
   and creates a migration with no operations, since the model matches the
   snapshot; the snapshot stays as committed. `make db-migration-remove`
   takes the migration out again, and `git status` is empty.
4. A package referenced directly where it was transitive: the locked
   restore CI runs fails with NU1004 until a developer's plain restore has
   updated the lock files, and passes after it.
5. `make install-frontend`, which runs `npm install`, is the one open
   question: if npm 10.9.9 keeps the `libc` field, as npm 11 does, the
   install writes the 36 fields main's lock lost (W46) back; if it drops
   it, as 10.8.2 does, the lock stays as committed. Either way `resolved`
   and `integrity` stay in every entry (W41).
6. `make dev-frontend` serves the start page without a server error, and
   its log shows no compile error.

## Commands

Verbatim in `data/2026-10-13-phoenix-dev-workflows/arch/kommando.txt`, the
numbers in `results.txt` beside it; the logs in private data.
