#!/usr/bin/env python3
"""Render the README's zuko block from OVERVIEW.md.

Usage: readme_block.py <project-dir> [--write|--check]

No flag prints the block, markers included. The block is a pure function of
OVERVIEW.md: its description, its "## Run it" table and its "## Slices" table,
plus a docs list of the repo files that exist.

Exit 0 printed. Exit 2 when the overview cannot be rendered; the message names
the file and what is wrong, and nothing partial is ever printed.
"""
import os
import re
import sys

DEFAULT_START = ("<!-- zuko:start — generated from OVERVIEW.md; "
                 "edit that file, not this block -->")
END = "<!-- zuko:end -->"
USAGE = "usage: render-readme-block.sh [--write|--check]"

# Listed only when the file exists, so later slices need no renderer change.
DOCS = [
    ("Overview", "OVERVIEW.md"),
    ("Architecture", "docs/ARCHITECTURE.md"),
    ("Decisions", "DECISIONS.md"),
    ("Changelog", "CHANGELOG.md"),
]

NOT_SET_UP = "not set up yet"

FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
SEPARATOR_CELL = re.compile(r"^:?-+:?$")
# A pipe splits cells unless it is escaped, as Markdown tables write it.
CELL_BREAK = re.compile(r"(?<!\\)\|")


class CannotRender(Exception):
    """The stderr line for an exit 2."""


def visible_lines(lines):
    """The lines with every fenced code block blanked to None.

    A table inside a fence is an example, not data. None also breaks a table,
    so rows on either side of a fence never join into one.
    """
    visible = []
    fence = None
    for line in lines:
        opener = FENCE.match(line)
        if fence:
            if (opener and opener.group(1)[0] == fence[0]
                    and len(opener.group(1)) >= len(fence)
                    and not line[opener.end():].strip()):
                fence = None
            visible.append(None)
        elif opener:
            fence = opener.group(1)
            visible.append(None)
        else:
            visible.append(line)
    return visible


def split_row(line):
    body = line.strip()
    if body.startswith("|"):
        body = body[1:]
    if body.endswith("|") and not body.endswith("\\|"):
        body = body[:-1]
    return [cell.strip() for cell in CELL_BREAK.split(body)]


def is_separator(line):
    cells = split_row(line)
    return all(SEPARATOR_CELL.match(cell) for cell in cells)


def section_table(visible, title):
    """The first table under "## {title}": (line number, row text) pairs."""
    heading = "## " + title
    start = next((i for i, line in enumerate(visible)
                  if line is not None and line.rstrip() == heading), None)
    if start is None:
        return []
    rows = []
    for number, line in enumerate(visible[start + 1:], start + 2):
        if line is not None and re.match(r"#{1,2} ", line):
            break
        if line is not None and line.lstrip().startswith("|"):
            rows.append((number, line))
        elif rows:
            break
    return rows


def read_table(visible, title, columns):
    """Rows of the "## {title}" table as dicts of the named columns."""
    rows = section_table(visible, title)
    if not rows:
        raise CannotRender('OVERVIEW.md  no "## %s" table' % title)
    unreadable = 'OVERVIEW.md  cannot read the "## %s" table: ' % title
    header = split_row(rows[0][1])
    if len(rows) < 2 or not is_separator(rows[1][1]):
        raise CannotRender(unreadable + "no separator row under the header")
    for column in columns:
        if column not in header:
            raise CannotRender(unreadable + 'no "%s" column' % column)
    records = []
    for number, line in rows[2:]:
        cells = split_row(line)
        if len(cells) != len(header):
            raise CannotRender(unreadable + "line %d has %d cells, the header %d"
                               % (number, len(cells), len(header)))
        records.append({column: cells[header.index(column)] for column in columns})
    return records


def description(lines, visible):
    """The paragraph(s) between the Status line and the first ## heading."""
    status = next((i for i, line in enumerate(visible)
                   if line is not None and line.startswith("**Status:**")), None)
    if status is None:
        raise CannotRender("OVERVIEW.md  no **Status:** line")
    end = next((i for i, line in enumerate(visible)
                if i > status and line is not None and line.startswith("## ")),
               len(lines))
    body = lines[status + 1:end]
    while body and not body[0].strip():
        body.pop(0)
    while body and not body[-1].strip():
        body.pop()
    return body


def render_table(header, rows):
    widths = [max(len(row[i]) for row in [header] + rows) for i in range(len(header))]

    def line(cells):
        return "| " + " | ".join(c.ljust(w) for c, w in zip(cells, widths)) + " |"

    return [line(header), line(["-" * w for w in widths])] + [line(r) for r in rows]


def sections(project):
    """The block's sections as (key, heading, body lines), in order."""
    path = os.path.join(project, "OVERVIEW.md")
    if not os.path.isfile(path):
        raise CannotRender("OVERVIEW.md  missing")
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().splitlines()
    visible = visible_lines(lines)

    what = description(lines, visible)
    commands = [
        [row["Task"], row["Command"]]
        for row in read_table(visible, "Run it", ["Task", "Command"])
        if row["Command"].strip("` ") != NOT_SET_UP
    ]
    shipped = [
        "- " + row["What it does"]
        for row in read_table(visible, "Slices", ["Slice", "Status", "What it does"])
        if row["Status"] == "Shipped"
    ]
    docs = ["- [%s](%s)" % (name, file) for name, file in DOCS
            if os.path.isfile(os.path.join(project, file))]

    found = [("what", "What it does", what)]
    if commands:
        found.append(("install", "Install and run",
                      render_table(["Task", "Command"], commands)))
    found.append(("features", "Features", shipped or ["Nothing shipped yet"]))
    found.append(("docs", "Docs", docs))
    return found


def block_lines(project, start):
    """The whole block, markers included, one string per line."""
    lines = [start, ""]
    for _key, heading, body in sections(project):
        lines += ["## " + heading, ""] + body + [""]
    return lines + [END]


def main(argv):
    if len(argv) != 2:
        sys.stderr.write(USAGE + "\n")
        return 2
    project = argv[1]
    try:
        lines = block_lines(project, DEFAULT_START)
    except CannotRender as err:
        sys.stderr.write("%s\n" % err)
        return 2
    sys.stdout.buffer.write(("\n".join(lines) + "\n").encode("utf-8"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
