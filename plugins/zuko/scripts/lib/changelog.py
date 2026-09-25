#!/usr/bin/env python3
"""Create and check the repo's CHANGELOG.md (Keep a Changelog 1.1.0).

Usage: changelog.py init           <project-dir>
       changelog.py add-unreleased <project-dir> [--write]
       changelog.py check          <project-dir> --base <commit> [--label <name>]

  init    write a new file: the header, an empty "## [Unreleased]", and one
          heading per semver tag, newest first, dated by the tag and saying
          only "Released before this changelog was kept." Tags that are not
          semver are named and skipped. Refuses a file that already exists
  add-unreleased  for a file in another shape: propose "## [Unreleased]"
          directly above its first "## " heading, or at the end when it has
          none. --write applies it; every other byte stays as it was
  check   the ship gate's question. A branch needs a line when a commit in
          <commit>..HEAD is feat or fix, carries "!" before its colon, or has a
          "BREAKING CHANGE: " footer. New lines are the "- " lines under
          [Unreleased] on disk that were not there at <commit>, counted as a
          multiset: a moved line is not new, a reworded one is. The file must
          exist and have the heading whatever the commits are. --label is
          accepted, like decisions.py, and not printed

Code fences are skipped: a "## " line inside one is an example, not a heading.

Exit 0 written, proposed, nothing to do, or the check passed. Exit 1 init found
a file already there, or the check found problems, each on a
"CHANGELOG.md  <problem>" line with any detail on indented lines below it.
Exit 2 bad usage, a base that is not a commit, a project folder that does not
exist, or no file for add-unreleased.
"""
import os
import re
import subprocess
import sys
from collections import Counter

NAME = "CHANGELOG.md"
USAGE = ("usage: changelog.py init <project-dir>\n"
         "       changelog.py add-unreleased <project-dir> [--write]\n"
         "       changelog.py check <project-dir> --base <commit> [--label <name>]")

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
NEEDS_LINE = re.compile(r"^(feat|fix)(\([^)]*\))?!?: |^[a-z]+(\([^)]*\))?!: ")
BREAKING = re.compile(r"^BREAKING[ -]CHANGE: ", re.M)


def git(project, *args):
    return subprocess.run(["git", "-C", project] + list(args),
                          capture_output=True, text=True)


def unfenced(lines):
    """(index, line) of every line outside a code fence."""
    fenced = False
    for i, line in enumerate(lines):
        if FENCE.match(line):
            fenced = not fenced
        elif not fenced:
            yield i, line


def headings(lines):
    """(index, line) of every "## " heading outside a code fence."""
    return [(i, line) for i, line in unfenced(lines) if line.startswith("## ")]


def unreleased(text):
    """The "- " lines under [Unreleased], stripped, up to the next "## "
    heading; None when the file has no [Unreleased] heading."""
    section = None
    for _, line in unfenced(text.splitlines()):
        if line.startswith("## "):
            if section is not None:
                break
            if UNRELEASED.match(line):
                section = []
        elif section is not None and line.startswith("- "):
            section.append(line.strip())
    return section


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
    # of a lightweight one. lstrip=2 drops exactly "refs/tags/": refname:short
    # prints "tags/v0.1.0" when a branch has the same name. Outside a git repo
    # this fails: no tags.
    listed = git(project, "for-each-ref",
                 "--format=%(refname:lstrip=2) %(creatordate:short)", "refs/tags")
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
    found = headings(lines)
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


def check(project, base):
    if git(project, "rev-parse", "--verify", "--quiet", base + "^{commit}").returncode != 0:
        print("changelog.py: base '%s' is not a commit" % base, file=sys.stderr)
        return 2
    path = os.path.join(project, NAME)
    if not os.path.isfile(path):
        print("%s  missing — /ship creates it" % NAME)
        return 1
    with open(path, encoding="utf-8") as handle:
        now = unreleased(handle.read())
    if now is None:
        print('%s  has no "## [Unreleased]" heading' % NAME)
        return 1

    log = git(project, "log", "--format=%h%x1f%s%x1f%b%x1e", base + "..HEAD")
    needing = []
    for record in log.stdout.split("\x1e"):
        fields = record.lstrip("\n").split("\x1f")
        if len(fields) == 3 and (NEEDS_LINE.match(fields[1]) or BREAKING.search(fields[2])):
            needing.append("%s %s" % (fields[0], fields[1]))
    if not needing:
        print("Changelog: no feat or fix commits — no line needed")
        return 0

    # "./" resolves from the project dir, which may sit below the repo root.
    shown = git(project, "show", "%s:./%s" % (base, NAME))
    before = (unreleased(shown.stdout) if shown.returncode == 0 else None) or []
    new = sum((Counter(now) - Counter(before)).values())
    if new == 0:
        print("%s  no new line under [Unreleased] — this branch has feat or fix commits:" % NAME)
        for commit in needing:
            print("                %s" % commit)
        return 1
    print("Changelog: %d new line%s under [Unreleased] for %d feat/fix commit%s"
          % (new, "" if new == 1 else "s", len(needing), "" if len(needing) == 1 else "s"))
    return 0


def main(argv):
    if len(argv) == 2 and argv[0] == "init":
        command, args = init, [argv[1]]
    elif len(argv) in (2, 3) and argv[0] == "add-unreleased" and argv[2:] in ([], ["--write"]):
        command, args = add_unreleased, [argv[1], argv[2:] == ["--write"]]
    elif (len(argv) in (4, 6) and argv[0] == "check" and argv[2] == "--base"
          and argv[4:5] in ([], ["--label"])):
        command, args = check, [argv[1], argv[3]]
    else:
        print(USAGE, file=sys.stderr)
        return 2
    if not os.path.isdir(argv[1]):
        print("changelog.py: %s is not a directory" % argv[1], file=sys.stderr)
        return 2
    return command(*args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
