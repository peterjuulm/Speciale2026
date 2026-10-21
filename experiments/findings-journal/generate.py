#!/usr/bin/env python3
"""Build the offline findings viewer from the public Markdown index."""

import argparse
from collections import Counter
from hashlib import sha256
from html import escape
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "notes/findings-table.md"
TEMPLATE = Path(__file__).with_name("template.html")
OUTPUT = ROOT / "journal/index.html"
# Prefix of the finding id -> group. The order is the order of the table.
GROUPS = {
    "E": "Minimal .NET library",
    "W": "WS.PEMS",
    "T": "Toolchain probes",
    "R": "reprotest probes",
}
LAYERS = {
    "1": ".NET build",
    "2": "Publish",
    "3": "Frontend",
    "4": "Archives",
    "5": "Containers",
    "M": "Measurement",
}
# First word of the Status cell -> (key on the page and in links, label).
STATES = {
    "red": ("open", "open"),
    "green": ("closed", "closed or stable"),
    "rejected": ("rejected", "rejected"),
}
BARE_STATUS = re.compile(r"(green|red|rejected)(\s+`\[V\]`)?")


def parse_findings(source):
    """Reject malformed rows rather than silently losing a finding."""
    rows = []
    seen = set()
    for number, line in enumerate(source.splitlines(), 1):
        if not re.match(r"^\s*\|\s*[EWTR]\d+\s*\|", line):
            continue
        cells = [part.strip().replace(r"\|", "|")
                 for part in re.split(r"(?<!\\)\|", line)[1:-1]]
        if len(cells) != 10:
            raise ValueError(f"Line {number}: expected 10 cells, got {len(cells)}")
        identifier, layer, cause, observation, where, writer, mitigation, fix, status, measured = cells
        state = re.match(r"^(green|red|rejected)\b", status)
        if not state:
            raise ValueError(f"Line {number}: unknown status {status!r}")
        layers = list(dict.fromkeys(value.strip() for value in layer.split(",")))
        if any(value not in LAYERS for value in layers):
            raise ValueError(f"Line {number}: unknown layer {layer!r}")
        if identifier in seen:
            raise ValueError(f"Line {number}: duplicate finding {identifier}")
        seen.add(identifier)
        rows.append(dict(id=identifier, layers=layers, cause=cause,
                         observation=observation, where=where, writer=writer,
                         mitigation=mitigation, fix=fix, status=status,
                         state=state[1], measured=measured))
    if not rows:
        raise ValueError("The source contains no finding rows")
    return rows


def inline(text, identifiers, links=True):
    """Render code spans and known finding references, never raw HTML.

    The list rows sit inside a <summary>, so they pass links=False.
    """
    def reference(match):
        if links and match[0] in identifiers:
            return f'<a href="#{match[0]}">{match[0]}</a>'
        return match[0]

    def prose(value):
        return re.sub(r"\b[EWTR]\d+\b", reference, escape(value))

    result = []
    end = 0
    for match in re.finditer(r"(`+)(.+?)\1", text):
        result.append(prose(text[end:match.start()]))
        result.append(f"<code>{escape(match[2])}</code>")
        end = match.end()
    result.append(prose(text[end:]))
    return "".join(result)


def note_links(measured):
    # Only link note names explicitly present in the recorded run description.
    # Ambiguous names retain every matching note, with their dates in the label.
    links = []
    for path in sorted([*(ROOT / "notes").glob("*.md"),
                        *(ROOT / "dependencies/notes").glob("*.md")],
                       key=lambda path: path.name):
        name = re.sub(r"^\d{4}-\d{2}-\d{2}-", "", path.stem)
        names = [name]
        if name.startswith("phoenix-") and "-" in name.removeprefix("phoenix-"):
            names.append(name.removeprefix("phoenix-"))
        if not any(re.search(r"(?<![\w-])" + re.escape(value) + r"(?![\w-])", measured)
                   for value in names):
            continue
        links.append(f'<a href="../{escape(path.relative_to(ROOT).as_posix(), quote=True)}">'
                     f'{escape(path.stem)}</a>')
    return "".join(f"<li>{link}</li>" for link in links)


def layer_label(value):
    return f"{value} {LAYERS[value]}"


def join_items(items):
    """Join with middle dots. A dot stays with the item before it, so a line never starts with one."""
    dotted = [f'<span class="item">{item}<span class="sep" aria-hidden="true">&nbsp;·</span></span>'
              for item in items[:-1]]
    return "\n".join(dotted + [items[-1]])


def toggle(name, value, label, count, checked=False):
    """A radio button drawn as plain text. The page script keeps the count current."""
    state = " checked" if checked else ""
    return (f'<label class="opt"><input type="radio" name="{name}" value="{value}"{state} autocomplete="off">'
            f'<span class="opt-text">{escape(label)} '
            f'<span class="count">(<span class="n">{count}</span><span class="sr-only"> findings</span>)</span>'
            f'</span></label>')


def state_toggles(rows):
    counts = Counter(STATES[row["state"]][0] for row in rows)
    items = [toggle("state", "all", "all", len(rows), checked=True)]
    for key, label in STATES.values():
        items.append(toggle("state", key, label, counts[key]))
    return join_items(items)


def layer_toggles(rows):
    # A finding that spans two layers counts once under each of them.
    counts = Counter(value for row in rows for value in row["layers"])
    items = [toggle("layer", "all", "all", len(rows), checked=True)]
    for value in LAYERS:
        items.append(toggle("layer", value, layer_label(value), counts[value]))
    return join_items(items)


def group_toggles(rows):
    counts = Counter(row["id"][0] for row in rows)
    items = [toggle("group", "all", "all", len(rows), checked=True)]
    for key, name in GROUPS.items():
        items.append(toggle("group", key, f"{key} {name}", counts[key]))
    return join_items(items)


def finding_html(row, identifiers):
    identifier = row["id"]
    state, state_label = STATES[row["state"]]
    group = GROUPS[identifier[0]]
    layers = " ".join(row["layers"])
    layer_cell = ", ".join(f'<span data-field="layers">{escape(layer_label(value))}</span>'
                           for value in row["layers"])
    excerpt = inline(row["observation"], identifiers, links=False)
    # A bare "green" or "red" adds nothing to the state. A qualified status does.
    status_note = ""
    if not BARE_STATUS.fullmatch(row["status"]):
        status_note = ('<span class="status-note"><span class="note-label">Recorded status:</span> '
                       '<span data-hl>' + inline(row["status"], identifiers, links=False)
                       + '</span></span>')
    fields = [
        ("observation", "Observation", row["observation"], "Not recorded"),
        ("where", "Affected output", row["where"], "Not recorded"),
        ("writer", "Written by", row["writer"], "Not recorded"),
        ("mitigation", "Mitigation", row["mitigation"], "Not recorded"),
        ("fix", "Fix or boundary", row["fix"], "No separate fix recorded"),
        ("status", "Exact recorded status", row["status"], "Not recorded"),
        ("measured", "Measured in", row["measured"], "Not recorded"),
        ("group", "Group", group, "Not recorded"),
    ]
    # Placeholder text carries no data-field, so a search never matches it.
    content = []
    for name, label, value, placeholder in fields:
        if value:
            content.append(f'<dt>{label}</dt><dd data-field="{name}">'
                           f'{inline(value, identifiers)}</dd>')
        else:
            content.append(f'<dt>{label}</dt><dd class="none">{placeholder}</dd>')
    content = "\n".join(content)
    related = note_links(row["measured"])
    notes = ""
    if related:
        notes = ('<div class="related"><p class="related-title">Notes named in this record</p>'
                 f'<ul>{related}</ul></div>')
    cause = escape(row["cause"])
    return f'''<article class="finding" id="{identifier}" data-group="{identifier[0]}" data-layers="{layers}" data-state="{state}">
<details>
<summary>
<span class="id" data-field="id">{identifier}</span>
<span class="layer"><span class="sr-only">Layer </span>{layer_cell}</span>
<span class="cause" data-field="cause">{cause}</span>
<span class="state"><span class="sr-only">State </span><span data-field="state">{state_label}</span></span>
<span class="excerpt" data-hl>{excerpt}</span>
{status_note}
<span class="found-in" hidden></span>
<span class="toggle" aria-hidden="true"><span class="show">Show evidence</span><span class="hide">Hide evidence</span></span>
</summary>
<div class="evidence">
<dl>
{content}
</dl>
{notes}
<p class="links"><a href="#{identifier}">Link to {identifier}</a> <a href="../notes/findings-table.md">Open the source table</a></p>
</div>
</details>
</article>'''


def generate():
    source_bytes = SOURCE.read_bytes()
    rows = parse_findings(source_bytes.decode("utf-8"))
    identifiers = {row["id"] for row in rows}
    values = {
        "FINDINGS": "\n".join(finding_html(row, identifiers) for row in rows),
        "STATE_TOGGLES": state_toggles(rows),
        "LAYER_TOGGLES": layer_toggles(rows),
        "GROUP_TOGGLES": group_toggles(rows),
        "TOTAL": str(len(rows)),
        "SOURCE_HASH": sha256(source_bytes).hexdigest(),
    }
    template = TEMPLATE.read_text(encoding="utf-8")

    def substitute(match):
        if match[1] not in values:
            raise ValueError(f"Unknown template placeholder {match[0]}")
        return values[match[1]]
    return re.sub(r"@@([A-Z_]+)@@", substitute, template)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if the saved page is stale")
    args = parser.parse_args()
    try:
        page = generate().encode("utf-8")
    except (OSError, ValueError) as error:
        parser.exit(1, f"Findings journal: {error}\n")
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_bytes() != page:
            print("Findings journal is stale. Run python3 experiments/findings-journal/generate.py", file=sys.stderr)
            return 1
        print("Findings journal matches its source and template.")
    else:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_bytes(page)
        print(f"Wrote {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
