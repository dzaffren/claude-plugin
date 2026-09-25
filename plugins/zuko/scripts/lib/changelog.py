#!/usr/bin/env python3
"""Create and check the repo's CHANGELOG.md (Keep a Changelog 1.1.0).

Usage: changelog.py init           <project-dir>

  init    write a new file: the header, an empty "## [Unreleased]", and one
          heading per semver tag, newest first, dated by the tag and saying
          only "Released before this changelog was kept." Tags that are not
          semver are named and skipped. Refuses a file that already exists

Exit 0 written. Exit 1 the file already exists. Exit 2 bad usage or a project
folder that does not exist.
"""
import os
import re
import subprocess
import sys

NAME = "CHANGELOG.md"
USAGE = "usage: changelog.py init <project-dir>"

HEADER = """# Changelog

All notable changes to this project are documented in this file. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
"""
PAST = "\n## [%s] - %s\n\nReleased before this changelog was kept.\n"
SEMVER = re.compile(r"^v?(\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?)$")


def git(project, *args):
    return subprocess.run(["git", "-C", project] + list(args),
                          capture_output=True, text=True)


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


def main(argv):
    if len(argv) == 2 and argv[0] == "init":
        if not os.path.isdir(argv[1]):
            print("changelog.py: %s is not a directory" % argv[1], file=sys.stderr)
            return 2
        return init(argv[1])
    print(USAGE, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
