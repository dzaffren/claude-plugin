#!/usr/bin/env python3
"""Create and check the repo's CHANGELOG.md (Keep a Changelog 1.1.0).

Usage: changelog.py init           <project-dir>
       changelog.py add-unreleased <project-dir> [--write]

  init    write a new file: the header, an empty "## [Unreleased]", and one
          heading per semver tag, newest first, dated by the tag and saying
          only "Released before this changelog was kept." Tags that are not
          semver are named and skipped. Refuses a file that already exists
  add-unreleased  for a file in another shape: propose "## [Unreleased]"
          directly above its first "## " heading, or at the end when it has
          none. --write applies it; every other byte stays as it was

Code fences are skipped: a "## " line inside one is an example, not a heading.

Exit 0 written, proposed, or nothing to do. Exit 1 init found a file already
there. Exit 2 bad usage, a project folder that does not exist, or no file for
add-unreleased.
"""
import os
import re
import subprocess
import sys

NAME = "CHANGELOG.md"
USAGE = ("usage: changelog.py init <project-dir>\n"
         "       changelog.py add-unreleased <project-dir> [--write]")

HEADER = """# Changelog

All notable changes to this project are documented in this file. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
"""
PAST = "\n## [%s] - %s\n\nReleased before this changelog was kept.\n"
SEMVER = re.compile(r"^v?(\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?)$")
UNRELEASED = re.compile(r"^## \[Unreleased\]\s*$")
FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")


def git(project, *args):
    return subprocess.run(["git", "-C", project] + list(args),
                          capture_output=True, text=True)


def headings(lines):
    """(index, line) of every "## " heading outside a code fence."""
    fenced = False
    for i, line in enumerate(lines):
        if FENCE.match(line):
            fenced = not fenced
        elif not fenced and line.startswith("## "):
            yield i, line


def precedence(version):
    """A sort key in semver order: a pre-release sorts below its release,
    numeric identifiers compare as numbers and below alphanumeric ones."""
    core, _, pre = version.partition("-")
    key = tuple(int(n) for n in core.split("."))
    if not pre:
        return key + ((1,),)
    ids = tuple((0, int(p), "") if p.isdigit() else (1, 0, p) for p in pre.split("."))
    return key + ((0,) + ids,)


def init(project):
    path = os.path.join(project, NAME)
    if os.path.exists(path):
        print("%s already exists — use add-unreleased" % NAME)
        return 1
    # creatordate is the tagger date of an annotated tag and the commit date
    # of a lightweight one. Outside a git repo this fails: no tags.
    listed = git(project, "for-each-ref",
                 "--format=%(refname:short) %(creatordate:short)", "refs/tags")
    tags, skipped = [], []
    for line in listed.stdout.splitlines() if listed.returncode == 0 else []:
        tag, _, date = line.partition(" ")
        match = SEMVER.match(tag)
        if match:
            tags.append((precedence(match.group(1)), tag, match.group(1), date))
        else:
            skipped.append(tag)
    tags.sort(reverse=True)

    with open(path, "w", encoding="utf-8") as handle:
        handle.write(HEADER + "".join(PAST % (version, date) for _, _, version, date in tags))

    if not tags:
        print("%s: created with [Unreleased] and no past versions" % NAME)
    else:
        print("%s: created with [Unreleased] and %d past version%s from tags (%s)"
              % (NAME, len(tags), "" if len(tags) == 1 else "s",
                 ", ".join(tag for _, tag, _, _ in tags)))
    if skipped:
        print("Skipped tags that are not semver: %s" % ", ".join(skipped))
    return 0


def add_unreleased(project, write):
    path = os.path.join(project, NAME)
    if not os.path.isfile(path):
        print("changelog.py: no %s in %s — init creates one" % (NAME, project), file=sys.stderr)
        return 2
    # newline="" keeps the file's own line endings, byte for byte.
    with open(path, encoding="utf-8", newline="") as handle:
        text = handle.read()
    lines = text.splitlines(keepends=True)
    found = list(headings(lines))
    if any(UNRELEASED.match(line) for _, line in found):
        print("%s already has [Unreleased]" % NAME)
        return 0
    if found:
        i, line = found[0]
        where = "above line %d" % (i + 1)
        shown = '%s, "%s"' % (where, line[3:].strip())
        new = lines[:i] + ["## [Unreleased]\n", "\n"] + lines[i:]
    else:
        where = shown = "at the end of the file"
        new = [text, "" if text.endswith("\n") else "\n", "\n## [Unreleased]\n"]
    if not write:
        print("%s exists without [Unreleased]. Proposed change:" % NAME)
        print("  + ## [Unreleased]   (%s)" % shown)
        return 0
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write("".join(new))
    print("%s: added [Unreleased] %s" % (NAME, where))
    return 0


def main(argv):
    if len(argv) >= 2 and not os.path.isdir(argv[1]):
        print("changelog.py: %s is not a directory" % argv[1], file=sys.stderr)
        return 2
    if len(argv) == 2 and argv[0] == "init":
        return init(argv[1])
    if len(argv) in (2, 3) and argv[0] == "add-unreleased" and argv[2:] in ([], ["--write"]):
        return add_unreleased(argv[1], argv[2:] == ["--write"])
    print(USAGE, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
