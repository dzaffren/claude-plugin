#!/usr/bin/env python3
"""Read a spec's Decided alone rows and its Review section for /ship.

Usage: pr_body.py check  <spec>
       pr_body.py render <spec>

The rows are the table under "## Open items", the Review lines are the lines
under "## Review"; both outside code fences, so an example in the spec is
never read as the spec's own. A row is Decided alone when its Status cell is
exactly that, and its Answer then holds "Chose:", "Other:" and "Undo:". The
rules live in references/ledger.md, the body layout in skills/ship/SKILL.md.

  check   each Decided alone row has all three parts, and the Review section
          has at least one run line ("<YYYY-MM-DD> · ..."). Passing, it prints
          what it read: the row count and the run count
  render  the PR body's first two parts: Your call, as a table of the rows
          copied word for word, then the Review lines as they are

Exit 0 printed, or the check passed. Exit 1 the check found problems, one line
each; render prints them to stderr and nothing to stdout. Exit 2 bad usage, or
a spec that cannot be read.
"""
import re
import sys

USAGE = "Usage: pr_body.py check <spec>\n       pr_body.py render <spec>"

FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
ROW = re.compile(r"^\s*\|\s*O[0-9]+\s*\|")
CELL = re.compile(r"(?<!\\)\|")
RUN = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2} · ")
DATE = re.compile(r"\s*[0-9]{4}-[0-9]{2}-[0-9]{2}\s*$")
PARTS = ("Chose:", "Other:", "Undo:")


def sections(text):
    """{heading: [lines]} for each "## " heading outside a code fence. A fence
    closes on its own character, at least as long, with nothing after it, so
    a ```` block can hold a ``` example."""
    found, current, fence = {}, None, ""
    for line in text.splitlines():
        marker = FENCE.match(line)
        if fence:
            if marker and marker.group(1)[0] == fence[0] and len(marker.group(1)) >= len(fence) \
                    and not line[marker.end():].strip():
                fence = ""
        elif marker:
            fence = marker.group(1)
        elif line.startswith("## "):
            current = line[3:].strip()
            found.setdefault(current, [])
            continue
        if current is not None:
            found[current].append(line)
    return found


def decided(ledger):
    """(id, what, {part: text}) for each Decided alone row, in order."""
    rows = []
    for line in ledger:
        if not ROW.match(line):
            continue
        cells = [cell.strip() for cell in CELL.split(line.strip())[1:-1]]
        if len(cells) < 7 or cells[5] != "Decided alone":
            continue
        answer = cells[6]
        at = sorted((answer.find(part), part) for part in PARTS if part in answer)
        parts = {}
        for i, (start, part) in enumerate(at):
            end = at[i + 1][0] if i + 1 < len(at) else len(answer)
            parts[part] = answer[start + len(part):end].strip()
        if "Undo:" in parts:
            parts["Undo:"] = DATE.sub("", parts["Undo:"])
        rows.append((cells[0], cells[1], parts))
    return rows


def missing(parts):
    gone = ['"%s"' % part for part in PARTS if part not in parts]
    if len(gone) == 1:
        return "no " + gone[0]
    return ", ".join("no " + part for part in gone[:-1]) + " and no " + gone[-1]


def review(lines):
    """The Review lines, blank lines at either end dropped."""
    while lines and not lines[0].strip():
        lines = lines[1:]
    while lines and not lines[-1].strip():
        lines = lines[:-1]
    return lines


def read(path):
    """(rows, review lines or None, problems)."""
    found = sections(open(path, encoding="utf-8").read())
    problems = []
    if "Open items" not in found:
        problems.append("No '## Open items' section in the spec.")
    rows = decided(found.get("Open items", []))
    for row_id, _, parts in rows:
        if len(parts) < len(PARTS):
            problems.append("%s  Decided alone row has %s" % (row_id, missing(parts)))
    lines = None
    if "Review" not in found:
        problems.append("No '## Review' section in the spec. Run /review on this branch first.")
    else:
        lines = review(found["Review"])
        if not any(RUN.match(line) for line in lines):
            problems.append("The '## Review' section has no run line. Run /review on this branch first.")
    return rows, lines, problems


def check(rows, lines):
    if not rows:
        print("Decided alone: no rows")
    elif len(rows) == 1:
        print("Decided alone: 1 row, with Chose, Other and Undo")
    else:
        print("Decided alone: %d rows, each with Chose, Other and Undo" % len(rows))
    runs = sum(1 for line in lines if RUN.match(line))
    print("Review: %d run%s recorded" % (runs, "" if runs == 1 else "s"))


def render(rows, lines):
    out = ["## Your call", ""]
    if not rows:
        out.append("Nothing was decided without you.")
    else:
        if len(rows) == 1:
            out.append("1 thing was decided without you. It can be undone.")
        else:
            out.append("%d things were decided without you. Each one can be undone." % len(rows))
        out += ["", "| ID | What | Chose | Other | Undo |", "| --- | --- | --- | --- | --- |"]
        for row_id, what, parts in rows:
            out.append("| %s | %s | %s |" % (row_id, what, " | ".join(parts[part] for part in PARTS)))
    out += ["", "## Review", ""] + lines
    print("\n".join(out))


def main(argv):
    if len(argv) != 2 or argv[0] not in ("check", "render"):
        print(USAGE, file=sys.stderr)
        return 2
    try:
        rows, lines, problems = read(argv[1])
    except (OSError, UnicodeDecodeError) as error:
        print("pr_body.py: cannot read %s: %s" % (argv[1], error), file=sys.stderr)
        return 2
    if problems:
        print("\n".join(problems), file=sys.stdout if argv[0] == "check" else sys.stderr)
        return 1
    (check if argv[0] == "check" else render)(rows, lines)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
