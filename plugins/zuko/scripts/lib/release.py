#!/usr/bin/env python3
"""Plan and cut a release: the gates, the next version, the changelog and the
manifest versions. Commits, tags, pushes and the GitHub release are the
/release skill's; this script never runs them.

Usage: release.py plan  <project-dir> [--version X.Y.Z]

  plan   run the gates and print the report; every failing gate is listed.
         Then the last version, the commits since it and the proposed one:
         a breaking commit bumps major (minor below 1.0.0), else a feat bumps
         minor, else a fix bumps patch, else nothing is proposed. --version
         checks an override: refused when it is not a plain X.Y.Z above the
         last version, advised against when its size does not match the
         commits. The last line is always one "NEXT: " line saying what the
         skill does: stop, ask X.Y.Z, confirm X.Y.Z or ask-version

The last version is the newest plain semver tag on HEAD's history.

Exit 0 the gates passed. Exit 1 a gate failed or the override was refused:
"NEXT: stop". Exit 2 bad usage, a project folder that does not exist, or one
that is not a git repository.
"""
import importlib.util
import json
import os
import re
import subprocess
import sys
from datetime import date


def load(name):
    """A sibling module in lib/, loaded by its path, whatever sys.path holds."""
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
RANK = {None: 0, "patch": 1, "minor": 2, "major": 3}


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
    """The number of lines under [Unreleased]."""
    path = os.path.join(project, changelog.NAME)
    if not os.path.isfile(path):
        gates.fail("changelog", "%s missing — /ship creates it" % changelog.NAME)
        return 0
    with open(path, encoding="utf-8") as handle:
        lines = changelog.unreleased(handle.read())
    if lines is None:
        gates.fail("changelog", '%s has no "## [Unreleased]" heading' % changelog.NAME)
        return 0
    if not lines:
        gates.fail("changelog", "[Unreleased] has no lines — nothing to release")
    else:
        gates.ok("changelog", "%s under [Unreleased]" % plural(len(lines), "line"))
    return len(lines)


def show(version):
    return "%d.%d.%d" % version


def parse(text):
    """(major, minor, patch) of a plain X.Y.Z, a leading v allowed; None otherwise."""
    match = changelog.SEMVER.match(text)
    if not match or match.group(2):
        return None
    return tuple(int(n) for n in match.group(1).split("."))


def semver_tags(project, *where):
    """(tag, version) for every plain X.Y.Z tag, pre-releases left out."""
    tags = git(project, "tag", "--list", *where).stdout.split()
    return [(tag, parse(tag)) for tag in tags if parse(tag)]


def last_tag(project):
    """(tag, version) of the newest semver tag on HEAD's history, or None."""
    return max(semver_tags(project, "--merged", "HEAD"), key=lambda pair: pair[1], default=None)


class Commit:
    """A commit read the way the ship gate reads it: its type when it is one
    of those that needs a changelog line, and whether it is breaking."""

    def __init__(self, subject, body):
        self.subject = subject
        match = changelog.NEEDS_LINE.match(subject)
        self.kind = re.match(r"[a-z]+", subject).group(0) if match else None
        self.breaking = bool((match and match.group(0).endswith("!: "))
                             or changelog.BREAKING.search(body))


def commits_since(project, tag):
    log = git(project, "log", "--format=%s%x1f%b%x1e", tag + "..HEAD" if tag else "HEAD")
    commits = []
    for record in log.stdout.split("\x1e"):
        fields = record.lstrip("\n").split("\x1f")
        if len(fields) == 2:
            commits.append(Commit(*fields))
    return commits


def called_for(last, commits):
    """(size, reason) the commits call for; (None, None) when nothing does."""
    if any(commit.breaking for commit in commits):
        if last[0] == 0:
            return "minor", "a breaking change on 0.x bumps minor (semver §4)"
        return "major", "a breaking change since %s bumps major" % show(last)
    if any(commit.kind == "feat" for commit in commits):
        return "minor", "a feat since %s bumps minor" % show(last)
    if any(commit.kind == "fix" for commit in commits):
        return "patch", "a fix since %s bumps patch" % show(last)
    return None, None


def bump(version, size):
    major, minor, patch = version
    if size == "major":
        return major + 1, 0, 0
    if size == "minor":
        return major, minor + 1, 0
    return major, minor, patch + 1


def size_of(last, version):
    if version[0] != last[0]:
        return "major"
    return "minor" if version[1] != last[1] else "patch"


def refusal(text, version, last, proposed):
    """Why an override names no release it could mean, or None when it is fine."""
    if version is None:
        why = ('"%s" is a pre-release; those are not supported yet.' % text
               if changelog.SEMVER.match(text) else '"%s" is not a version.' % text)
    elif last and version <= last:
        why = '"%s" is not above %s.' % (text, show(last))
    else:
        return None
    return "%s Give a plain X.Y.Z%s%s." % (why, " above %s" % show(last) if last else "",
                                          ", or yes for %s" % show(proposed) if proposed else "")


def advice(version, last, called, proposed, commits):
    """What the commits call for when the override's size does not match, or None."""
    given = size_of(last, version)
    breaking = [commit for commit in commits if commit.breaking]
    v, since = show(version), show(last)
    if given == "major" and not breaking:
        return ("%s is a major, but nothing since %s is marked breaking. Fine for a milestone; "
                "users may look for something they must change. Release %s? yes, or give "
                "another version." % (v, since, v))
    if RANK[given] < RANK[called] and breaking:
        # A caret range pins the major, or the minor below 1.0.0.
        pin = str(last[0]) if last[0] else "0.%d" % last[1]
        return ('%s is a %s, but "%s" is breaking, which calls for %s. Users pinned to ^%s get '
                "it without warning. Release %s anyway? yes, or give another version."
                % (v, given, breaking[0].subject, show(proposed), pin, v))
    if RANK[given] < RANK[called]:
        return ("%s is a patch, but a feat since %s calls for a minor (%s). Users read a patch "
                "as fixes only. Release %s anyway? yes, or give another version."
                % (v, since, show(proposed), v))
    if given == "minor" and called == "patch":
        return ("%s is a minor, but nothing since %s is a feat; the fixes call for a patch (%s). "
                "Users read a minor as new features. Release %s anyway? yes, or give another "
                "version." % (v, since, show(proposed), v))
    return None


def tag_gate(project, version, gates):
    """A tag for this version anywhere but HEAD stops the release."""
    head = git(project, "rev-parse", "HEAD").stdout.strip()
    for tag, tagged in semver_tags(project):
        at = git(project, "rev-parse", tag + "^{commit}").stdout.strip()
        if tagged == version and at != head:
            gates.fail("tag", "%s exists at %s, not HEAD — check it by hand; zuko never moves a tag"
                       % (tag, at[:7]))


def has_status_line(project):
    path = os.path.join(project, "OVERVIEW.md")
    if not os.path.isfile(path):
        return False
    with open(path, encoding="utf-8", errors="replace") as handle:
        return any(line.startswith("**Status:**") for line in handle)


class Release:
    """Everything plan shows and cut writes, worked out once."""

    def __init__(self, project, override):
        self.gates = gates = Gates()
        branch_gate(project, gates)
        tree_gate(project, gates)
        repo = remote_gate(project, gates)
        if repo:
            tests_gate(project, repo, gates)
        self.lines = changelog_gate(project, gates)

        tagged = last_tag(project)
        self.tag, self.last = tagged if tagged else (None, None)
        self.commits = commits_since(project, self.tag)
        self.called, self.reason = called_for(self.last, self.commits)
        self.proposed = bump(self.last, self.called) if self.called else None

        self.override = override
        self.refused = self.advice = None
        self.version = self.proposed
        if override is not None:
            self.version = parse(override)
            self.refused = refusal(override, self.version, self.last, self.proposed)
            if not self.refused and self.version != self.proposed:
                self.advice = advice(self.version, self.last, self.called, self.proposed,
                                     self.commits)
        if self.version and not self.refused:
            tag_gate(project, self.version, gates)
        self.overview = has_status_line(project)


def print_plan(release, today):
    v = show(release.version)
    if release.version == release.proposed:
        why = release.reason
    elif release.proposed:
        why = "your version; the commits call for %s" % show(release.proposed)
    else:
        why = "your version; nothing since %s calls for a release" % show(release.last)
    print("Proposed      %s  — %s" % (v, why))
    print()
    writes = [(changelog.NAME, "[Unreleased] → [%s] - %s, links" % (v, today))]
    if release.overview:
        writes.append(("OVERVIEW.md", "Release: v%s on the status line" % v))
    width = max(len(path) for path, _ in writes) + 3
    print("Will write")
    for path, what in writes:
        print("  %s%s" % (path.ljust(width), what))
    print("Then")
    print('  commit "chore(release): v%s" on main · annotated tag v%s' % (v, v))
    print("  push main and v%s to origin · GitHub release v%s" % (v, v))
    print()


def plan(project, override):
    release = Release(project, override)
    release.gates.show()
    if release.gates.failed:
        print("NEXT: stop")
        return 1
    print()
    commits = release.commits
    print("Last version  %s  from tag %s" % (show(release.last), release.tag))
    print("Since then    %s: %d feat · %d fix · %d breaking"
          % (plural(len(commits), "commit"), sum(c.kind == "feat" for c in commits),
             sum(c.kind == "fix" for c in commits), sum(c.breaking for c in commits)))
    if release.refused:
        print()
        print(release.refused)
        print("NEXT: stop")
        return 1
    if release.version is None:
        print()
        print("Nothing since %s calls for a release: %s, none feat, fix or breaking."
              % (show(release.last), plural(len(commits), "commit")))
        print("[Unreleased] has %s. Give a version to release anyway, or stop here."
              % plural(release.lines, "line"))
        print("NEXT: ask-version")
        return 0
    print_plan(release, date.today().isoformat())
    v = show(release.version)
    if release.advice:
        print(release.advice)
        print("NEXT: confirm %s" % v)
    else:
        print("Release %s? Say yes, or give another version." % v)
        print("NEXT: ask %s" % v)
    return 0


def main(argv):
    if len(argv) in (2, 4) and argv[0] == "plan" and argv[2:3] in ([], ["--version"]):
        project, override = argv[1], (argv[3] if len(argv) == 4 else None)
    else:
        print(USAGE, file=sys.stderr)
        return 2
    if not os.path.isdir(project):
        print("release.py: %s is not a directory" % project, file=sys.stderr)
        return 2
    if git(project, "rev-parse", "--git-dir").returncode != 0:
        print("release.py: %s is not a git repository" % project, file=sys.stderr)
        return 2
    return plan(project, override)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
