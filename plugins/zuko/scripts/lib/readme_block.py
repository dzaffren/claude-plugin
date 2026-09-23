#!/usr/bin/env python3
"""Render the README's zuko block from OVERVIEW.md.

Usage: readme_block.py <project-dir> [--write|--check]

The block is a pure function of OVERVIEW.md: its description, its "## Run it"
table and its "## Slices" table, plus a docs list of the repo files that exist.
It sits in README.md between a line starting `<!-- zuko:start` and a line
`<!-- zuko:end -->`.

  no flag   print the block, markers included
  --write   replace the bytes between the markers; every other byte is kept
  --check   compare the block in README.md with what the overview renders to

Exit 0 printed, rewritten, or up to date. Exit 1 stale, or README.md has no
block. Exit 2 when the block cannot be rendered; the message names the file and
what is wrong, and nothing is printed or written.
"""
import difflib
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

# What a start marker's skip list may name: one key per section.
SKIP_KEYS = ("what", "install", "features", "docs")
SKIP = re.compile(r"^<!-- zuko:start\s+skip=(\S*)")

NOT_SET_UP = "not set up yet"
DIFF_CAP = 40

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


def skipped(start):
    """The section keys the start marker's skip list leaves out."""
    match = SKIP.match(start)
    keys = [key for key in (match.group(1) if match else "").split(",") if key]
    for key in keys:
        if key not in SKIP_KEYS:
            raise CannotRender('README.md  unknown skip key "%s"' % key)
    return keys


def block_lines(project, start):
    """The whole block, markers included, one string per line.

    The start marker is kept as given: it carries the user's skip list.
    """
    skip = skipped(start)
    lines = [start, ""]
    for key, heading, body in sections(project):
        if key not in skip:
            lines += ["## " + heading, ""] + body + [""]
    return lines + [END]


def normalised(text):
    """The block as --check compares it: padding and table shape ignored.

    Trailing spaces go; a table row's cells lose their padding and inner runs
    of spaces; a separator cell keeps only its dashes-and-colons shape. A
    formatter that re-aligns the tables must not make the block look stale.
    """
    lines = []
    for line in text.splitlines():
        line = line.rstrip()
        if line.lstrip().startswith("|"):
            cells = [" ".join(cell.split()) for cell in split_row(line)]
            if is_separator(line):
                cells = [re.sub("-+", "-", cell) for cell in cells]
            line = "| " + " | ".join(cells) + " |"
        lines.append(line)
    return lines


def stale_diff(current, rendered):
    diff = list(difflib.unified_diff(
        current.splitlines(), rendered.splitlines(),
        "README.md", "rendered from OVERVIEW.md", lineterm=""))
    if len(diff) > DIFF_CAP:
        diff = diff[:DIFF_CAP] + ["... diff cut at %d lines" % DIFF_CAP]
    return diff


class NoBlock(Exception):
    """README.md is missing or has no markers: exit 1."""


def find_block(readme):
    """Where the block sits in README.md's bytes.

    Returns (inner start, inner end, start marker line, line ending): the byte
    range between the two marker lines, the start marker as text, and the
    ending the start marker line uses, so a rewrite keeps the file's style.
    """
    start = end = None
    offset = 0
    for raw in readme.splitlines(keepends=True):
        line = raw.rstrip(b"\r\n")
        text = line.decode("utf-8", "replace")
        if start is None and text.startswith("<!-- zuko:start"):
            start = (offset, raw, line)
        elif start is not None and text.rstrip() == END:
            end = offset
            break
        offset += len(raw)
    if start is None:
        raise NoBlock("README.md  no zuko block — onboarding adds it")
    begin, raw, line = start
    return (begin + len(raw), end, line.decode("utf-8", "replace"),
            raw[len(line):].decode())


def main(argv):
    if len(argv) not in (2, 3) or argv[2:] not in ([], ["--write"], ["--check"]):
        sys.stderr.write(USAGE + "\n")
        return 2
    project, mode = argv[1], (argv[2:] or [None])[0]
    path = os.path.join(project, "README.md")
    try:
        with open(path, "rb") as handle:
            readme = handle.read()
    except FileNotFoundError:
        readme = b""
    try:
        try:
            inner_start, inner_end, start, eol = find_block(readme)
        except NoBlock:
            if mode:
                raise
            start = DEFAULT_START
        lines = block_lines(project, start)
    except NoBlock as err:
        sys.stderr.write("%s\n" % err)
        return 1
    except CannotRender as err:
        sys.stderr.write("%s\n" % err)
        return 2

    if mode is None:
        sys.stdout.buffer.write(("\n".join(lines) + "\n").encode("utf-8"))
        return 0
    inner = "".join(line + eol for line in lines[1:-1]).encode("utf-8")
    if mode == "--write":
        with open(path, "wb") as handle:
            handle.write(readme[:inner_start] + inner + readme[inner_end:])
        sys.stderr.write("README.md  zuko block rewritten\n")
        return 0
    current = readme[inner_start:inner_end].decode("utf-8", "replace")
    rendered = inner.decode("utf-8")
    if normalised(current) != normalised(rendered):
        sys.stderr.write("README.md  zuko block is stale — run render-readme-block.sh --write\n")
        for line in stale_diff(current, rendered):
            sys.stderr.write(line + "\n")
        return 1
    sys.stderr.write("README.md  zuko block up to date\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
