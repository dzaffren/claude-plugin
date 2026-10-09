#!/usr/bin/env python3
"""List the zuko docs a Stop hook judges.

Usage: stop_scope.py <project dir>

Prints one path per line, <project dir>/docs/specs/..., sorted. A doc is
listed when it is

  - a zuko doc: shape.md, or a file with a line starting
    "**Version:** v<N> · **Status:**" (the spec template's first line), and
  - in docs/specs/ to depth 2, outside archive/, and
  - touched: different from the merge-base with the base branch (committed on
    the branch, staged or unstaged), or new and untracked.

The base branch is origin/HEAD, then main, then master. Not a git work tree, or
no base branch → every zuko doc is listed, as before this filter existed.

Exit 0 printed (nothing when no zuko doc was touched). Exit 1 git failed or a
touched file cannot be read; the reason goes to stderr.
"""
import os
import re
import subprocess
import sys

MARKER = re.compile(r"^\*\*Version:\*\* v[0-9]+ · \*\*Status:\*\*", re.M)


class GitError(Exception):
    pass


def git(project, *args):
    """git's stdout, or GitError with its stderr."""
    done = subprocess.run(["git", "-C", project] + list(args),
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if done.returncode != 0:
        raise GitError("git %s: %s" % (" ".join(args), done.stderr.decode(errors="replace").strip()))
    return done.stdout.decode(errors="surrogateescape")


def base_commit(project):
    """The merge-base with the base branch, or None when there is no work
    tree or no base branch to compare against."""
    try:
        if git(project, "rev-parse", "--is-inside-work-tree").strip() != "true":
            return None
    except (GitError, OSError):
        return None
    try:
        origin_head = git(project, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD").strip()
    except GitError:
        origin_head = ""
    for candidate in (origin_head, "main", "master"):
        if not candidate:
            continue
        try:
            git(project, "rev-parse", "--verify", "--quiet", candidate)
            return git(project, "merge-base", "HEAD", candidate).strip()
        except GitError:
            continue
    return None


def in_scope(rel):
    """docs/specs/<name>.md or docs/specs/<dir>/<name>.md, outside archive/.
    A name holding a newline cannot be printed one per line, and no slice or
    idea is named that way."""
    parts = rel.split("/")
    return (rel.endswith(".md") and "\n" not in rel and parts[:2] == ["docs", "specs"]
            and len(parts) in (3, 4) and "archive" not in parts[2:-1])


def every_doc(project):
    found = []
    for root, dirs, files in os.walk(os.path.join(project, "docs", "specs")):
        for name in files:
            rel = os.path.relpath(os.path.join(root, name), project).replace(os.sep, "/")
            if in_scope(rel):
                found.append(rel)
    return found


def touched_docs(project, base):
    changed = git(project, "diff", "--name-only", "-z", "--relative", base, "--", "docs/specs")
    new = git(project, "ls-files", "--others", "--exclude-standard", "-z", "--", "docs/specs")
    return [rel for rel in set(changed.split("\0") + new.split("\0"))
            if rel and in_scope(rel) and os.path.isfile(os.path.join(project, rel))]


def is_zuko_doc(path):
    if os.path.basename(path) == "shape.md":
        return True
    with open(path, encoding="utf-8", errors="replace") as doc:
        return MARKER.search(doc.read()) is not None


def main(argv):
    if len(argv) != 1:
        print("usage: stop_scope.py <project dir>", file=sys.stderr)
        return 1
    project = argv[0]
    try:
        base = base_commit(project)
        candidates = every_doc(project) if base is None else touched_docs(project, base)
        for rel in sorted(candidates):
            path = os.path.join(project, rel)
            if is_zuko_doc(path):
                print(path)
    except (GitError, OSError, UnicodeError) as error:
        print("stop_scope.py: %s" % error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
