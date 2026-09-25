#!/usr/bin/env python3
"""Plan and cut a release: the gates, the next version, the changelog and the
manifest versions. Commits, tags, pushes and the GitHub release are the
/release skill's; this script never runs them.

Usage: release.py plan  <project-dir> [--version X.Y.Z]
       release.py cut   <project-dir> --version X.Y.Z --date YYYY-MM-DD
       release.py notes <project-dir> --version X.Y.Z

  plan   run the gates and print the report; every failing gate is listed.
         Then the last version, the commits since it and the proposed one:
         a breaking commit bumps major (minor below 1.0.0), else a feat bumps
         minor, else a fix bumps patch, else nothing is proposed. --version
         checks an override: refused when it is not a plain X.Y.Z above the
         last version, advised against when its size does not match the
         commits. A release tag at HEAD whose release is unfinished is
         resumed instead: not on origin, or on origin with no GitHub
         release; the tests and changelog are not checked again. The last
         line is always one "NEXT: " line saying what the skill does: stop,
         ask X.Y.Z, confirm X.Y.Z, ask-first, ask-version, resume vX.Y.Z push
         or resume vX.Y.Z release
  cut   re-check everything plan checks, then write: [Unreleased] stays,
         empty, and its lines move under "## [X.Y.Z] - date", with compare
         links at the bottom; each manifest's version characters, and no
         other byte; the overview's status line gains **Release:** vX.Y.Z.
         On any failure it writes nothing
  notes  print the lines under "## [X.Y.Z]", without the heading or the blank
         lines around them: the GitHub release's notes

The last version is the newest plain semver tag on HEAD's history; with no
tag, the version the manifests share; with neither, plan asks for the first.
The manifests are a closed list, each only when present: package.json,
pyproject.toml's [project], Cargo.toml's [package], .claude-plugin/plugin.json,
and in .claude-plugin/marketplace.json each plugin whose source is a path in
the repo, with that plugin's own .claude-plugin/plugin.json. Manifests that
disagree stop the release.

Exit 0 planned, written, or printed. Exit 1 a gate failed or the version was
refused (plan says "NEXT: stop", cut "Nothing written."), or notes found no
such section. Exit 2 bad usage, a bad date, a project folder that does not
exist, or one that is not a git repository.
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

USAGE = ("usage: release.py plan  <project-dir> [--version X.Y.Z]\n"
         "       release.py cut   <project-dir> --version X.Y.Z --date YYYY-MM-DD\n"
         "       release.py notes <project-dir> --version X.Y.Z")

# host, then owner/repo, from https, ssh:// and scp-style git@host:path URLs.
REMOTE = re.compile(r"^(?:[a-z][a-z+]*://)?(?:[^@/]+@)?([^/:]+)(?::\d+)?[:/]+(.+?)(?:\.git)?/*$")
OWNER_REPO = re.compile(r"^[\w.-]+/[\w.-]+$")
# A check run passes on these conclusions and a commit status on "success";
# anything else, including one still running, is not passing.
PASSING_RUN = ("success", "neutral", "skipped")
RANK = {None: 0, "patch": 1, "minor": 2, "major": 3}

# The closed list of manifests, in the order the plan names them.
KINDS = ("package.json", "pyproject.toml", "Cargo.toml", "plugin.json", "marketplace.json")
PLAIN = re.compile(r"^\d+\.\d+\.\d+$")
JSON_VERSION = re.compile(r'"version"\s*:\s*"([^"\\]*)"')
TOML_VERSION = re.compile(r"""^\s*version\s*=\s*(["'])([^"']*)\1""")
TOML_DYNAMIC = re.compile(r"^\s*dynamic\s*=")
PROBE = "zuko-probe"
LINK = re.compile(r"^\[[^\]]+\]:\s*\S")
STATUS_WORD = re.compile(r"^(\*\*Status:\*\*\s*\S+)")
RELEASE_FIELD = re.compile(r"\*\*Release:\*\*\s*\S+")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


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


class Field:
    """One version in one manifest, and the span of its characters: a bump
    rewrites that span and every other byte stays."""

    def __init__(self, path, kind, version, span):
        self.path, self.kind, self.version, self.span = path, kind, version, span


def read(project, path):
    # newline="" keeps the file's own line endings, so spans are exact.
    with open(os.path.join(project, path), encoding="utf-8", newline="") as handle:
        return handle.read()


def dig(data, keys):
    for key in keys:
        try:
            data = data[key]
        except (KeyError, IndexError, TypeError):
            return None
    return data


def json_fields(path, kind, text, keyed, gates):
    """A Field for each key path in keyed. A JSON dump would reorder and
    reflow the file, so each "version" string is found in the text by trying
    it: the one whose change shows up at that key path is the one."""
    spans = {}
    for match in JSON_VERSION.finditer(text):
        try:
            trial = json.loads(text[:match.start(1)] + PROBE + text[match.end(1):])
        except ValueError:
            continue
        for keys in keyed:
            if dig(trial, keys) == PROBE:
                spans[keys] = match.span(1)
    data = json.loads(text)
    fields = []
    for keys in keyed:
        if keys not in spans:
            gates.fail("manifests", "%s: cannot find its version to bump in place — bump it by hand"
                       % path)
        else:
            fields.append(Field(path, kind, dig(data, keys), spans[keys]))
    return fields


def json_file(project, path, gates):
    """(text, data), or (None, None) when the file is absent or not JSON."""
    if not os.path.isfile(os.path.join(project, path)):
        return None, None
    text = read(project, path)
    try:
        return text, json.loads(text)
    except ValueError:
        gates.fail("manifests", "%s is not valid JSON" % path)
        return None, None


def toml_version(text, table):
    """(version, span) of the version line in [table], ("dynamic", None) when
    [table] lists version as dynamic, or (None, None)."""
    current, offset, dynamic, in_dynamic = None, 0, False, False
    for line in text.splitlines(keepends=True):
        stripped = line.lstrip()
        if stripped.startswith("[") and not in_dynamic:
            header = re.match(r"\[([^\[\]]+)\]", stripped)
            current = header.group(1).strip() if header else None
        elif current == table:
            match = TOML_VERSION.match(line)
            if match:
                return match.group(2), (offset + match.start(2), offset + match.end(2))
            if TOML_DYNAMIC.match(line) or in_dynamic:
                in_dynamic = "]" not in line
                dynamic = dynamic or bool(re.search(r"""["']version["']""", line))
        offset += len(line)
    return ("dynamic", None) if dynamic else (None, None)


def manifests(project, gates):
    """(fields, notes): every version in the closed list of manifests, each
    only when present, and a note for a version that comes from the tag."""
    fields, notes = [], []

    def plain_json(path, kind):
        text, data = json_file(project, path, gates)
        if isinstance(data, dict) and isinstance(data.get("version"), str):
            return json_fields(path, kind, text, [("version",)], gates)
        return []

    fields += plain_json("package.json", "package.json")
    for path, table in (("pyproject.toml", "project"), ("Cargo.toml", "package")):
        if os.path.isfile(os.path.join(project, path)):
            version, span = toml_version(read(project, path), table)
            if version == "dynamic":
                notes.append("%s: version comes from the tag, not touched" % path)
            elif version is not None:
                fields.append(Field(path, path, version, span))
    fields += plain_json(".claude-plugin/plugin.json", "plugin.json")

    # Each plugin whose source is a path in this repo: its entry's version,
    # and its own plugin.json.
    path = ".claude-plugin/marketplace.json"
    text, data = json_file(project, path, gates)
    plugins = data.get("plugins") if isinstance(data, dict) else None
    keyed, nested = [], []
    for i, entry in enumerate(plugins if isinstance(plugins, list) else []):
        source = entry.get("source") if isinstance(entry, dict) else None
        if not isinstance(source, str) or "://" in source:
            continue
        if isinstance(entry.get("version"), str):
            keyed.append(("plugins", i, "version"))
        inner = os.path.normpath(os.path.join(source, ".claude-plugin", "plugin.json"))
        if not inner.startswith("..") and not os.path.isabs(inner) and inner not in nested:
            nested.append(inner)
    fields += json_fields(path, "marketplace.json", text, keyed, gates) if keyed else []
    for inner in nested:
        if inner != ".claude-plugin/plugin.json":
            fields += plain_json(inner, "plugin.json")

    bad = [field for field in fields if not PLAIN.match(field.version)]
    for field in bad:
        gates.fail("manifests", '%s version "%s" is not a plain X.Y.Z' % (field.path, field.version))
    if not bad and len({field.version for field in fields}) > 1:
        gates.fail("manifests", "versions disagree: " + " · ".join(
            "%s %s" % (field.path, field.version) for field in fields))
    return fields, notes


def show(version):
    return "%d.%d.%d" % version


def joined(words):
    return words[0] if len(words) == 1 else "%s and %s" % (", ".join(words[:-1]), words[-1])


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


def resume_state(project, repo, gates):
    """(tag, short sha, "push" or "release") when a release tag sits at HEAD
    and its release is not finished; None when there is nothing to resume."""
    at_head = semver_tags(project, "--points-at", "HEAD")
    if not at_head:
        return None
    tag = max(at_head, key=lambda pair: pair[1])[0]
    short = git(project, "rev-parse", "--short", "HEAD").stdout.strip()
    remote = git(project, "ls-remote", "--tags", "origin", "refs/tags/" + tag)
    if remote.returncode != 0:
        gates.fail("remote", "could not reach origin: %s" % first_line(remote.stderr))
        return None
    if not remote.stdout.strip():
        return tag, short, "push"
    code, out, err = gh("release", "view", tag, "--repo", repo)
    if code == 0:
        return None
    if "release not found" in err:
        return tag, short, "release"
    gates.fail("release", "could not check GitHub for release %s: %s" % (tag, first_line(err or out)))
    return None


class Release:
    """Everything plan shows and cut writes, worked out once. A release to
    resume skips the rest: its tests passed and its changelog was cut."""

    def __init__(self, project, override):
        self.gates = gates = Gates()
        branch_gate(project, gates)
        tree_gate(project, gates)
        repo = remote_gate(project, gates)
        self.resume = None
        if repo and not gates.failed:
            self.resume = resume_state(project, repo, gates)
        if self.resume:
            return
        if repo:
            tests_gate(project, repo, gates)
        self.lines = changelog_gate(project, gates)
        self.fields, self.notes = manifests(project, gates)

        # The newest tag is the last version; with none, the manifests' shared one.
        tagged = last_tag(project)
        self.tag, self.last = tagged if tagged else (None, None)
        if not tagged and self.fields and not gates.failed:
            self.last = parse(self.fields[0].version)
        self.commits = commits_since(project, self.tag)
        if self.tag and not self.commits:
            gates.fail("commits", "no commits since %s" % self.tag)
        self.called, self.reason = called_for(self.last, self.commits) if self.last else (None, None)
        self.proposed = bump(self.last, self.called) if self.called else None

        self.refused = self.advice = None
        self.version = self.proposed
        if override is not None:
            self.version = parse(override)
            self.refused = refusal(override, self.version, self.last, self.proposed)
            if not self.refused and self.last and self.version != self.proposed:
                self.advice = advice(self.version, self.last, self.called, self.proposed,
                                     self.commits)
        if self.version and not self.refused:
            tag_gate(project, self.version, gates)
        self.overview = has_status_line(project)
        self.project, self.repo = project, repo


def writes(release, today):
    """(path, what) for every file cut writes, in the order the plan lists them."""
    v = show(release.version)
    found = [(changelog.NAME, "[Unreleased] → [%s] - %s, links" % (v, today))]
    for field in release.fields:
        if field.path not in [path for path, _ in found]:
            found.append((field.path, "%s → %s" % (field.version, v)))
    if release.overview:
        found.append(("OVERVIEW.md", "Release: v%s on the status line" % v))
    return found


def print_writes(heading, found, notes=()):
    width = max(len(path) for path, _ in found) + 3
    print(heading)
    for path, what in found:
        print("  %s%s" % (path.ljust(width), what))
    for note in notes:
        print("  " + note)


def link_start(lines):
    """Where the link definitions at the bottom begin, blank lines above them
    included; len(lines) when there are none."""
    start = len(lines)
    while start and (not lines[start - 1].strip() or LINK.match(lines[start - 1])):
        start -= 1
    return start if any(LINK.match(line) for line in lines[start:]) else len(lines)


def section(lines, heading):
    """(start, end) of the lines under the first "## " heading that heading
    matches, up to the next one or the link definitions; None when absent."""
    body = lines[:link_start(lines)]
    heads = [i for i, line in changelog.unfenced(body) if line.startswith("## ")]
    start = next((i for i in heads if heading.match(body[i])), None)
    if start is None:
        return None
    return start, next((i for i in heads if i > start), len(body))


def trimmed(lines):
    """lines without blank lines at either end."""
    while lines and not lines[0].strip():
        lines = lines[1:]
    while lines and not lines[-1].strip():
        lines = lines[:-1]
    return lines


def cut_changelog(text, version, today, repo, last_tag):
    """[Unreleased] stays, empty; its lines move under the new version, and the
    links at the bottom point at the new tag."""
    lines = text.splitlines(keepends=True)
    if lines and not lines[-1].endswith("\n"):
        lines[-1] += "\n"
    start, end = section(lines, changelog.UNRELEASED)
    moved = trimmed(lines[start + 1:end])
    body, links = lines[:link_start(lines)], lines[link_start(lines):]
    after = ["\n"] + body[end:] if end < len(body) else []
    body = body[:start + 1] + ["\n", "## [%s] - %s\n" % (version, today), "\n"] + moved + after

    url = "https://github.com/" + repo
    new = ["[unreleased]: %s/compare/v%s...HEAD\n" % (url, version),
           "[%s]: %s/compare/%s...v%s\n" % (version, url, last_tag, version) if last_tag
           else "[%s]: %s/releases/tag/v%s\n" % (version, url, version)]
    old = next((i for i, line in enumerate(links) if line.lower().startswith("[unreleased]:")), None)
    if old is not None:
        links[old:old + 1] = new
    elif links:
        first = next(i for i, line in enumerate(links) if LINK.match(line))
        links[first:first] = new
    else:
        links = ["\n"] + new
    return "".join(body + links)


def release_field(text, version):
    """The overview with its status line naming the release. Readers of the
    line take only the first word after **Status:**, so the field goes after it."""
    lines = text.splitlines(keepends=True)
    for i, line in enumerate(lines):
        if line.startswith("**Status:**"):
            if RELEASE_FIELD.search(line):
                lines[i] = RELEASE_FIELD.sub("**Release:** v" + version, line, count=1)
            else:
                lines[i] = STATUS_WORD.sub(r"\1 · **Release:** v" + version, line, count=1)
            break
    return "".join(lines)


def rewritten(release, today):
    """{path: new text} for every file cut writes, worked out before any is written."""
    v, project = show(release.version), release.project
    files = {changelog.NAME: cut_changelog(read(project, changelog.NAME), v, today,
                                           release.repo, release.tag)}
    for field in release.fields:
        files.setdefault(field.path, read(project, field.path))
    # Spans are offsets into the file as read: replace from the end backwards.
    for field in sorted(release.fields, key=lambda field: field.span, reverse=True):
        text = files[field.path]
        files[field.path] = text[:field.span[0]] + v + text[field.span[1]:]
    if release.overview:
        files["OVERVIEW.md"] = release_field(read(project, "OVERVIEW.md"), v)
    return files


def print_plan(release, today):
    v = show(release.version)
    if release.version == release.proposed:
        why = release.reason
    elif release.proposed:
        why = "your version; the commits call for %s" % show(release.proposed)
    elif release.last:
        why = "your version; nothing since %s calls for a release" % show(release.last)
    else:
        why = "the first release"
    print("Proposed      %s  — %s" % (v, why))
    print()
    print_writes("Will write", writes(release, today), release.notes)
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
    if release.resume:
        tag, short, step = release.resume
        section_name = show(parse(tag))
        if step == "push":
            print("%s is tagged at HEAD (%s) but not on origin." % (tag, short))
            print("Resuming: pushing main and %s, then creating the release from the [%s] "
                  "section. No new commit or tag." % (tag, section_name))
        else:
            print("%s is tagged at HEAD (%s) and on origin, but GitHub has no release %s."
                  % (tag, short, tag))
            print("Resuming: creating the release from the [%s] section. No new commit or tag."
                  % section_name)
        print("NEXT: resume %s %s" % (tag, step))
        return 0
    if release.last is None and override is None:
        print("No tags and no manifest version to start from.")
        print("First version: 0.1.0 (still changing) or 1.0.0 (stable)?")
        print("NEXT: ask-first")
        return 0
    commits = release.commits
    if release.tag:
        print("Last version  %s  from tag %s" % (show(release.last), release.tag))
    elif release.last:
        kinds = [kind for kind in KINDS if kind in {field.kind for field in release.fields}]
        print("Last version  %s  from %s (no tags yet)" % (show(release.last), joined(kinds)))
    else:
        print("Last version  none — no tags and no manifest version")
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


def cut(project, version, today):
    release = Release(project, version)
    release.gates.show()
    if release.gates.failed or release.resume or release.refused:
        if release.resume:
            print()
            print("%s is tagged at HEAD; resume the release instead of cutting again."
                  % release.resume[0])
        elif release.refused:
            print()
            print(release.refused)
        print("Nothing written.")
        return 1
    for path, text in rewritten(release, today).items():
        with open(os.path.join(project, path), "w", encoding="utf-8", newline="") as handle:
            handle.write(text)
    print()
    print_writes("Wrote", writes(release, today))
    return 0


def notes(project, version):
    if not os.path.isfile(os.path.join(project, changelog.NAME)):
        print("%s missing" % changelog.NAME, file=sys.stderr)
        return 1
    lines = read(project, changelog.NAME).splitlines(keepends=True)
    found = section(lines, re.compile(r"^## \[%s\](\s|$)" % re.escape(version)))
    if found is None:
        print("%s has no [%s] section" % (changelog.NAME, version), file=sys.stderr)
        return 1
    text = "".join(trimmed(lines[found[0] + 1:found[1]]))
    sys.stdout.write(text if text.endswith("\n") else text + "\n")
    return 0


def is_date(text):
    try:
        return bool(DATE.match(text)) and bool(date.fromisoformat(text))
    except ValueError:
        return False


def main(argv):
    # <command> <project-dir> then --option value pairs, each option once.
    pairs = argv[2:]
    options = dict(zip(pairs[::2], pairs[1::2]))
    given = sorted(options) if len(argv) >= 2 and len(options) * 2 == len(pairs) else None
    command, project = (argv[0], argv[1]) if given is not None else (None, None)
    if command == "plan" and given in ([], ["--version"]):
        run = lambda: plan(project, options.get("--version"))
    elif command == "cut" and given == ["--date", "--version"] and is_date(options["--date"]):
        run = lambda: cut(project, options["--version"], options["--date"])
    elif command == "notes" and given == ["--version"] and parse(options["--version"]):
        run = lambda: notes(project, show(parse(options["--version"])))
    else:
        print(USAGE, file=sys.stderr)
        return 2
    if not os.path.isdir(project):
        print("release.py: %s is not a directory" % project, file=sys.stderr)
        return 2
    if git(project, "rev-parse", "--git-dir").returncode != 0:
        print("release.py: %s is not a git repository" % project, file=sys.stderr)
        return 2
    return run()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
