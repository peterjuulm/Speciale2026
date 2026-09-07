# Speciale2026

Reproducible Builds in the .NET framework and WS.PEMS.
MSc thesis, IT University of Copenhagen, autumn 2026.
Leo Sakharov and Peter Juul Møller.

## Layout

    experiments/   one directory per experiment, named for the day it was run
    data/          output from runs: environment blocks, hash lists, logs
    notes/         what each experiment measured, and what came out

## Rules

- An experiment is a script that checks its own numbers. The expected values
  from the first run live in the script, and it says so when they change.
- Never build inside this repository. A .NET project inside a git repo gets the
  HEAD commit embedded in AssemblyInformationalVersion, so the hash shifts with
  every commit regardless of PathMap. Scripts work in a temporary directory.
- One file per machine under `data/`, named after who ran it. Two people writing
  the same file is a merge conflict, not a measurement.
- Text goes in git, bytes do not.
- Nothing from Weel-Sandvig's source or build output: this repository is public.
