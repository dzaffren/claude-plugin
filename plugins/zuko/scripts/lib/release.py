#!/usr/bin/env python3
"""Plan and cut a release: the gates, the next version, the changelog and the
manifest versions. Commits, tags, pushes and the GitHub release are the
/release skill's; this script never runs them.

Usage: release.py plan  <project-dir> [--version X.Y.Z]

  plan   run the gates and print the report. Every failing gate is listed.
         The last line is always one "NEXT: " line saying what the skill does:
         stop

Exit 0 the gates passed. Exit 1 a gate failed: "NEXT: stop". Exit 2 bad usage,
a project folder that does not exist, or one that is not a git repository.
"""
import importlib.util
import json
import os
import re
import subprocess
import sys


def load(name):
    """A sibling module in lib/, loaded by path: the names are not importable."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), name + ".py")
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


changelog = load("changelog")
readme_block = load("readme_block")
git = changelog.git

USAGE = "usage: release.py plan <project-dir> [--version X.Y.Z]"

# host, then owner/repo, from https, ssh:// and scp-style git@host:path URLs.
REMOTE = re.compile(r"^(?:[a-z][a-z+]*://)?(?:[^@/]+@)?([^/:]+)(?::\d+)?[:/]+(.+?)(?:\.git)?/*$")
OWNER_REPO = re.compile(r"^[\w.-]+/[\w.-]+$")
# A check run passes on these conclusions and a commit status on "success";
# anything else, including one still running, is not passing.
PASSING_RUN = ("success", "neutral", "skipped")


class Gates:
    """The gate report: every line in order, failing ones marked."""

    def __init__(self):
        self.lines = []

    def ok(self, name, text):
        self.lines.append((name, text, True))

    def fail(self, name, text):
        self.lines.append((name, text, False))

    @property
    def failed(self):
        return any(not passed for _, _, passed in self.lines)

    def show(self):
        print("Release gates FAILED" if self.failed else "Release gates")
        for name, text, passed in self.lines:
            if passed != self.failed:
                print("  %-11s%s" % (name, text))


def plural(count, word):
    return "%d %s%s" % (count, word, "" if count == 1 else "s")


def gh(*args):
    """(exit code, stdout, stderr) of a gh call; a missing gh is an error too."""
    try:
        done = subprocess.run(["gh"] + list(args), capture_output=True, text=True)
    except FileNotFoundError:
        return 127, "", "gh: command not found"
    return done.returncode, done.stdout, done.stderr


def first_line(text):
    return next((line.strip() for line in text.splitlines() if line.strip()), "no output")


def branch_gate(project, gates):
    name = git(project, "symbolic-ref", "--short", "-q", "HEAD").stdout.strip()
    if name == "main":
        gates.ok("branch", "main")
    else:
        gates.fail("branch", "on %s — release from main" % (name or "a detached HEAD"))


def tree_gate(project, gates):
    changed = git(project, "status", "--porcelain").stdout.splitlines()
    if changed:
        gates.fail("tree", "%s — commit or stash them first" % plural(len(changed), "uncommitted file"))
    else:
        gates.ok("tree", "clean")


def remote_gate(project, gates):
    """owner/repo on GitHub, or None when origin is anything else."""
    url = git(project, "config", "--get", "remote.origin.url").stdout.strip()
    if not url:
        gates.fail("remote", "no origin remote — add the GitHub repo as origin")
        return None
    match = REMOTE.match(url)
    host = match.group(1).lower() if match else url
    if host == "github.com" and OWNER_REPO.match(match.group(2)):
        gates.ok("remote", "github.com/" + match.group(2))
        return match.group(2)
    if host == "gitlab.com":
        gates.fail("remote", "origin is gitlab.com — GitLab releases come in slice 6")
    else:
        gates.fail("remote", "origin is %s — /release supports GitHub only" % host)
    return None


def test_command(project):
    """The command in backticks in the overview's "Run it" test row, or None."""
    path = os.path.join(project, "OVERVIEW.md")
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8", errors="replace") as handle:
        visible = readme_block.visible_lines(handle.read().splitlines())
    try:
        rows = readme_block.read_table(visible, "Run it", ["Task", "Command"])
    except readme_block.CannotRender:
        return None
    for row in rows:
        if row["Task"] == "test":
            match = re.search(r"`([^`]+)`", row["Command"])
            if match and match.group(1).strip() != readme_block.NOT_SET_UP:
                return match.group(1)
    return None


def tests_gate(project, repo, gates):
    """CI checks on HEAD decide; with none at all, the overview's test command.
    Decided on total_count, never on the combined state: a commit with no CI
    reads "pending"."""
    sha = git(project, "rev-parse", "HEAD").stdout.strip()
    short = git(project, "rev-parse", "--short", "HEAD").stdout.strip()
    total, failing = 0, []
    for endpoint, key, label, passed in (
            ("check-runs?per_page=100", "check_runs", "name",
             lambda run: run.get("conclusion") in PASSING_RUN),
            ("status", "statuses", "context",
             lambda status: status.get("state") == "success")):
        code, out, err = gh("api", "repos/%s/commits/%s/%s" % (repo, sha, endpoint))
        try:
            if code != 0:
                raise ValueError(first_line(err or out))
            data = json.loads(out)
            total += int(data["total_count"])
            failing += [item.get(label, "?") for item in data.get(key, []) if not passed(item)]
        except (ValueError, KeyError, TypeError, AttributeError) as problem:
            gates.fail("tests", "could not read CI checks on %s: %s" % (short, problem))
            return

    if total:
        if failing:
            gates.fail("tests", "%d of %s on %s failing: %s"
                       % (len(failing), plural(total, "CI check"), short, ", ".join(failing)))
        else:
            gates.ok("tests", "%s on %s, all passing" % (plural(total, "CI check"), short))
        return

    command = test_command(project)
    if command is None:
        gates.fail("tests", 'no CI checks on %s and no test command in OVERVIEW.md "Run it"' % short)
        return
    code = subprocess.run(["bash", "-c", command], cwd=project, stdin=subprocess.DEVNULL,
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode
    if code == 0:
        gates.ok("tests", 'no CI checks on %s — ran "%s": exit 0' % (short, command))
    else:
        gates.fail("tests", '"%s" exited %d' % (command, code))


def changelog_gate(project, gates):
    path = os.path.join(project, changelog.NAME)
    if not os.path.isfile(path):
        gates.fail("changelog", "%s missing — /ship creates it" % changelog.NAME)
        return
    with open(path, encoding="utf-8") as handle:
        lines = changelog.unreleased(handle.read())
    if lines is None:
        gates.fail("changelog", '%s has no "## [Unreleased]" heading' % changelog.NAME)
    elif not lines:
        gates.fail("changelog", "[Unreleased] has no lines — nothing to release")
    else:
        gates.ok("changelog", "%s under [Unreleased]" % plural(len(lines), "line"))


def plan(project):
    gates = Gates()
    branch_gate(project, gates)
    tree_gate(project, gates)
    repo = remote_gate(project, gates)
    if repo:
        tests_gate(project, repo, gates)
    changelog_gate(project, gates)
    gates.show()
    if gates.failed:
        print("NEXT: stop")
        return 1
    return 0


def main(argv):
    if len(argv) == 2 and argv[0] == "plan":
        project = argv[1]
    else:
        print(USAGE, file=sys.stderr)
        return 2
    if not os.path.isdir(project):
        print("release.py: %s is not a directory" % project, file=sys.stderr)
        return 2
    if git(project, "rev-parse", "--git-dir").returncode != 0:
        print("release.py: %s is not a git repository" % project, file=sys.stderr)
        return 2
    return plan(project)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
