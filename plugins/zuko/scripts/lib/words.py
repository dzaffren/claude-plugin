#!/usr/bin/env python3
"""Find the hard words in the lines that this work added to a shape or spec.

Usage: words.py check <project dir> <path>...

  check  one "<path>\t<line>\t<message>" line for each finding, in the order
         of the paths given. A path that is not a zuko doc in docs/specs/
         (stop_scope.in_scope, stop_scope.is_zuko_doc) is skipped before the
         word list is read. Only added lines are read: the lines changed since
         the merge-base with the base branch, or every line of an untracked
         file, or every line when there is no work tree or no base branch.

         The words are the "## Word list" table in references/voice.md: Kind
         (label, metaphor or hard), Word, Write instead. A Word cell may hold
         two spellings split by " / ". A label passes only inside brackets; a
         metaphor or a hard word never passes. A D or O number passes only
         inside brackets.

         Not read: fenced code, inline code, text in double quotes, headings,
         the "## Glossary" section, the "### Decisions to record" section, and
         the ID, Type, Raised at, Owner and Status columns of a table. The
         rules are in docs/specs/plain-words.md.

Exit 0 printed (nothing when no added line has a finding). Exit 2 bad usage,
a doc that cannot be read, git failed, or voice.md has no word list.
"""
import importlib.util
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name, file):
    """A neighbour by its path, not by import: a host that loads this file
    from `python3 -` has the project folder first on sys.path."""
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, file))
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


pr_body = _load("pr_body", "pr_body.py")
fence = _load("fence", "fence.py")
glossary = _load("glossary", "glossary.py")
stop_scope = _load("stop_scope", "stop_scope.py")

USAGE = "usage: words.py check <project dir> <path>..."
VOICE = os.path.join(HERE, "..", "..", "references", "voice.md")
KINDS = ("label", "metaphor", "hard")
SCRIPT_COLUMNS = {"id", "type", "raised at", "owner", "status"}
NUMBER = re.compile(r"(?<![\w./-])[DO][0-9]+(?![\w/-])")
INLINE_CODE = re.compile(r"(`+).*?\1", re.S)
QUOTE = re.compile(r'"[^"\n]*"|“[^”\n]*”')
HUNK = re.compile(r"^@@ -[0-9,]+ \+([0-9]+)(?:,([0-9]+))? @@", re.M)
MESSAGE = {
    "label": '"%s" is a zuko label used alone. Write "%s".',
    "metaphor": '"%s" is a metaphor. Write "%s".',
    "hard": '"%s" is a hard word. Write "%s".',
}


class Unreadable(Exception):
    pass


def cells(line):
    return [cell.strip() for cell in pr_body.CELL.split(line.strip())[1:-1]]


def word_list():
    """[(kind, word, write instead)] from voice.md, or Unreadable."""
    try:
        with open(VOICE, encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except (OSError, UnicodeDecodeError) as error:
        raise Unreadable("cannot read voice.md: %s" % error)
    found, inside, header = [], False, None
    for line in lines:
        if line.startswith("## "):
            if inside:
                break
            inside = line.strip() == "## Word list"
            continue
        if not inside or not line.lstrip().startswith("|"):
            continue
        row = cells(line)
        if header is None:
            header = [cell.lower() for cell in row]
            continue
        if header != ["kind", "word", "write instead"] or set("".join(row)) <= set("-: "):
            continue
        if len(row) == 3 and row[0] in KINDS:
            for word in row[1].split(" / "):
                found.append((row[0], word.strip(), row[2]))
    if not found:
        raise Unreadable("voice.md has no ## Word list table.")
    return found


def added_lines(project, rel, count):
    """The 1-based line numbers this work added to rel, a set."""
    every = set(range(1, count + 1))
    base = stop_scope.base_commit(project)
    if base is None:
        return every
    if stop_scope.git(project, "ls-files", "--others", "--exclude-standard", "--", rel).strip():
        return every
    diff = stop_scope.git(project, "diff", "-U0", "--no-color", "--no-ext-diff", base, "--", rel)
    added = set()
    for start, length in HUNK.findall(diff):
        start, length = int(start), int(length or "1")
        added.update(range(start, start + length))
    return added


def blank(match):
    """The match as spaces, its newlines kept, so line numbers hold."""
    return re.sub(r"[^\n]", " ", match.group(0))


def readable(lines):
    """The lines with every part the check does not read blanked out."""
    out, open_fence, section, skip_columns = [], "", None, None
    for line in lines:
        if open_fence:
            if fence.closes(line, open_fence):
                open_fence = ""
            out.append("")
            continue
        marker = pr_body.FENCE.match(line)
        if marker:
            open_fence = marker.group(1)
            out.append("")
            continue
        heading = re.match(r"^(#{1,6})\s", line)
        if heading:
            level = len(heading.group(1))
            if level <= 2:
                section = "glossary" if line.strip() == "## Glossary" else None
            elif level == 3:
                section = "decisions" if line.strip() == "### Decisions to record" else \
                    (section if section == "glossary" else None)
            out.append("")
            continue
        if section:
            out.append("")
            continue
        if line.lstrip().startswith("|"):
            row = cells(line)
            if skip_columns is None:
                skip_columns = [cell.lower() in SCRIPT_COLUMNS for cell in row]
                out.append("")
                continue
            if set("".join(row)) <= set("-: "):
                out.append("")
                continue
            kept = [cell for cell, skip in zip(row, skip_columns + [False] * len(row)) if not skip]
            out.append(" | ".join(kept))
            continue
        skip_columns = None
        out.append(line)
    text = INLINE_CODE.sub(blank, "\n".join(out))
    return QUOTE.sub(blank, text).split("\n")


def in_brackets(line, at):
    return line.count("(", 0, at) > line.count(")", 0, at)


def findings(line, words):
    found = []
    for kind, word, instead in words:
        for match in glossary.use(word).finditer(line):
            if kind == "label" and in_brackets(line, match.start()):
                continue
            found.append((match.start(), MESSAGE[kind] % (match.group(0), instead)))
    for match in NUMBER.finditer(line):
        if not in_brackets(line, match.start()):
            found.append((match.start(), '"%s" comes before its plain words. Write the plain words, then "(%s)".'
                          % (match.group(0), match.group(0))))
    return [message for _, message in sorted(found)]


def relative(project, path):
    return os.path.relpath(os.path.abspath(path), os.path.abspath(project)).replace(os.sep, "/")


def check(project, path, words):
    """[(line number, message)] for a zuko doc; the caller has checked in_scope."""
    if not os.path.isfile(path) or not stop_scope.is_zuko_doc(path):
        return []
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().splitlines()
    added = added_lines(project, relative(project, path), len(lines))
    out = []
    for number, line in enumerate(readable(lines), 1):
        if number in added:
            out.extend((number, message) for message in findings(line, words))
    return out


def main(argv):
    if len(argv) < 3 or argv[0] != "check":
        print(USAGE, file=sys.stderr)
        return 2
    project, words = argv[1], None
    try:
        for path in argv[2:]:
            if not stop_scope.in_scope(relative(project, path)):
                continue
            if words is None:
                words = word_list()
            for number, message in check(project, path, words):
                print("%s\t%d\t%s" % (path, number, message))
    except Unreadable as error:
        print(error, file=sys.stderr)
        return 2
    except (stop_scope.GitError, OSError, UnicodeError) as error:
        print("words.py: %s" % error, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    # UTF-8 with LF on every OS; a byte that is not UTF-8 goes out as it came (D98, D99).
    for stream in (sys.stdin, sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8", errors="surrogateescape", newline="\n")
    sys.exit(main(sys.argv[1:]))
