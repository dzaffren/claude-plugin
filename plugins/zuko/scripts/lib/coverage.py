"""The coverage ledger, docs/security/coverage.md: each unit, and the mark that
says whether a release pentest has checked it. release.py loads this module;
pick prints the old files from it, and cut writes the ledger.

A unit is a file git tracks, except a file in a test or tests folder, a file
under docs/, and a .md file at the repo root (O2). A mark is one of:

  vX.Y.Z           the pentest of that release checked it, with no lead
  lead in vX.Y.Z   that pentest checked it, and a lead on it is still open
  reset in vX.Y.Z  it changed in a release that shipped without a pentest
  unchecked        no pentest has checked it
"""
import os
import re

NAME = "docs/security/coverage.md"
UNCHECKED = "unchecked"
LIMIT = 10
MARK = re.compile(r"^(?:(?:lead in |reset in )?v\d+\.\d+\.\d+|unchecked)$")
TABLE_RULE = re.compile(r"^:?-+:?$")


class Unreadable(Exception):
    """A ledger pick and cut cannot read; the message is the line they print."""

    def __init__(self, what):
        super().__init__("Coverage ledger unreadable: " + what)


def units(tracked):
    """The tracked paths that count as units, in path order."""
    return sorted(path for path in tracked
                  if not {"test", "tests"} & set(path.split("/")[:-1])
                  and not path.startswith("docs/")
                  and not ("/" not in path and path.endswith(".md")))


def cells(line):
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def read(project):
    """{path: mark} from the ledger; None when there is no ledger. Every line
    after the File and Mark header must be a row with a known mark, and no
    path may be listed twice: Unreadable otherwise."""
    path = os.path.join(project, NAME)
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8", errors="replace") as handle:
        lines = handle.read().splitlines()
    header = next((i for i, line in enumerate(lines)
                   if line.strip().startswith("|") and cells(line) == ["File", "Mark"]), None)
    if header is None:
        raise Unreadable("no File and Mark table")
    marks = {}
    for number, line in enumerate(lines[header + 1:], header + 2):
        text = line.strip()
        if not text:
            continue
        row = cells(text)
        if all(TABLE_RULE.match(cell) for cell in row):
            continue
        if not (text.startswith("|") and text.endswith("|")) or len(row) != 2 or not row[0]:
            raise Unreadable("line %d: %s is not a File and Mark row" % (number, text))
        unit, mark = row
        if unit in marks:
            raise Unreadable("line %d: %s is listed twice" % (number, unit))
        if not MARK.match(mark):
            raise Unreadable('line %d: the mark "%s" is not vX.Y.Z, lead in vX.Y.Z, '
                             "reset in vX.Y.Z or unchecked" % (number, mark))
        marks[unit] = mark
    return marks


def pick(units, marks, changed, limit=LIMIT):
    """(old files, count): up to limit (path, mark) pairs outside the range,
    each lead first, then each reset, then each unchecked unit, each group in
    path order (O5); and how many units outside the range are on the list."""
    marks = marks or {}
    changed = set(changed)
    listed = [(unit, marks.get(unit, UNCHECKED)) for unit in units if unit not in changed]
    found = [pair for start in ("lead in ", "reset in ", UNCHECKED)
             for pair in listed if pair[1].startswith(start)]
    return found[:limit], len(found)


def marked(units, old, version, changed, checked=None, leads=()):
    """{unit: mark} for the new ledger. checked is None for a release that
    shipped without a pentest: each unit the range changed is reset. Else a
    unit the range changed and the pentest did not check has no check of its
    new code."""
    marks = {unit: (old or {}).get(unit, UNCHECKED) for unit in units}
    changed = [unit for unit in changed if unit in marks]
    if checked is None:
        for unit in changed:
            marks[unit] = "reset in v" + version
        return marks
    for unit in changed:
        marks[unit] = UNCHECKED
    for unit in checked:
        if unit in marks:
            marks[unit] = "v" + version
    for unit in leads:
        if unit in marks:
            marks[unit] = "lead in v" + version
    return marks


def checked_count(marks):
    """The units a pentest has checked, with a lead open or not."""
    return sum(mark.startswith(("v", "lead in ")) for mark in marks.values())


def render(marks, version, today):
    """The ledger text for marks, one row for each unit in path order."""
    checked = sum(mark.startswith("v") for mark in marks.values())
    leads = sum(mark.startswith("lead in ") for mark in marks.values())
    lines = ["# Coverage", "",
             "**Updated:** v%s · %s" % (version, today),
             "**Units:** %d · **Checked:** %d · **Lead:** %d · **Not checked:** %d"
             % (len(marks), checked, leads, len(marks) - checked - leads),
             "", "| File | Mark |", "| ---- | ---- |"]
    lines += ["| %s | %s |" % (unit, marks[unit]) for unit in sorted(marks)]
    return "\n".join(lines) + "\n"
