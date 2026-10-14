# Speciale2026

Reproducible Builds in the .NET framework and WS.PEMS.
MSc thesis, IT University of Copenhagen, autumn 2026.
Leo Sakharov and Peter Juul Møller.

## Layout

    experiments/   one directory per experiment, named for the day it was run
    data/          output from runs: environment blocks, hash lists, logs
    notes/         what each experiment measured, and what came out
    journal/       an offline HTML viewer of the findings table

## Findings journal

Open [journal/index.html](journal/index.html) in your browser. It works offline.
The page is generated from `notes/findings-table.md`. The experiment notes
remain the evidence. Closed or stable (green in the table) means closed or
stable within the recorded experiment, not a percentage of the release that is
reproducible.

Filter by state (open, closed or stable, rejected), by layer and by group. Each
count is what you would get by choosing that value with the other filters
applied. The search box matches every field as you type, marks the matches and
needs every word to match. Press `/` to jump to it and `Esc` to clear it. Sort
by id or by layer, and expand or collapse everything in view.

The address bar holds the view, so a link can open it:

    journal/index.html#state=open&layer=1    open findings in layer 1
    journal/index.html#q=umask&sort=layer    a search, sorted by layer
    journal/index.html#W27                   finding W27, opened

The keys are `state` (`open`, `closed`, `rejected`), `layer` (`1` to `5`, `M`),
`group` (`E`, `W`, `T`, `R`), `q` and `sort` (`id`, `layer`).

After editing the table, regenerate the page from the repository root:

```sh
python3 experiments/findings-journal/generate.py
```

`generate.py --check` fails if the saved page differs from what the table and
template produce. GitHub runs it on pushes and pull requests that touch the
table, the generator or the page
(`.github/workflows/findings-journal.yml`). The filter and link logic has
tests. They need Node 18 or later and nothing from npm:

```sh
node --test experiments/findings-journal/logic.test.js
```

Edit `experiments/findings-journal/template.html` to change the page.

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
