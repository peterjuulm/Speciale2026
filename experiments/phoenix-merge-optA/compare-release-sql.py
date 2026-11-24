"""compare-release-sql.py PUBLISHED OURS [EXTRA_MIGRATION ...]

Compares two idempotent release SQL scripts of the PostgreSQL migrations
(dotnet ef migrations script --idempotent) after setting aside what EF
Core 10 writes differently from EF Core 9:

- the EF version each history row records ('9.0.0' or '10.0.12');
- EF 10's transaction per migration ("COMMIT;" and "START TRANSACTION;"
  between migrations, where EF 9 has one transaction).

Every DO $EF$ block of OURS that names one of the EXTRA_MIGRATION ids (the
migrations OURS has and PUBLISHED does not) is taken out first. It prints
the counts and whether the rest is identical, and if not, the first
differing lines. Exit 0 when identical.

Written 23 November 2026 for the merge of main (option A): OURS is the
merge's script, PUBLISHED main's bootstrap-postgresql-v1.0.60.sql.
"""
import difflib
import re
import sys

EF_VERSION = re.compile(r"(VALUES \('[0-9]{14}_[^']+', )'(9\.0\.0|10\.0\.12)'\);")
BREAK = "COMMIT;\n\nSTART TRANSACTION;\n"


def normalise(path):
    text = open(path, encoding="utf-8-sig").read()
    rows = len(EF_VERSION.findall(text))
    breaks = text.count(BREAK)
    return EF_VERSION.sub(r"\1'<EF>');", text).replace(BREAK, ""), rows, breaks


published, rows_a, breaks_a = normalise(sys.argv[1])
ours, rows_b, breaks_b = normalise(sys.argv[2])
removed = 0
for extra in sys.argv[3:]:
    pattern = r"DO \$EF\$\n(?:(?!END \$EF\$;).)*?'" + re.escape(extra) + r"'.*?\nEND \$EF\$;\n\n?"
    for block in re.findall(pattern, ours, re.S):
        ours = ours.replace(block, "", 1)
        removed += 1
print(f"published: {rows_a} history rows, {breaks_a} transaction breaks")
print(f"ours:      {rows_b} history rows, {breaks_b} transaction breaks; {removed} blocks of {', '.join(sys.argv[3:]) or 'no extra migration'} taken out")
same = published == ours
print("identical after that:", same)
if not same:
    for line in list(difflib.unified_diff(published.split("\n"), ours.split("\n"), lineterm="", n=1))[:40]:
        print(line)
sys.exit(0 if same else 1)
