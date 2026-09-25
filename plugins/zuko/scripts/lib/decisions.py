#!/usr/bin/env python3
"""Read and check the repo's DECISIONS.md.

Usage: decisions.py titles   <project-dir>
       decisions.py active   <project-dir>
       decisions.py check    <project-dir> [--base <commit> [--label <name>]]
       decisions.py adr-scan <project-dir> [--dir <path>]

Every entry is a `## D<n> · <YYYY-MM-DD> · <title>` heading followed by its
Why, Rejected, optional Supersedes, Source and Status lines. The format and the
rules live in references/decisions.md.

  titles  one line per active entry, "D<n>  <title>", IDs padded to a column
  active  every active entry in full, as written, for the reviewer
          (both print nothing when there is no file)
  check   the branch's file against the one at <commit>: every entry recorded
          there is still here, unchanged except its Status line; and the
          branch's file has unique ascending numbers, the required lines, and
          supersede pairs that point at each other. With no --base, only the
          file itself is checked -- how onboarding checks a log it just wrote,
          before anything is committed
  adr-scan  the repo's Architecture Decision Records as JSON, one object per
          file in number order: status, date, and whether it seeds an entry,
          with its D-number and supersede pair, or why not. Reads docs/adr/,
          doc/adr/ or docs/decisions/, whichever holds ADRs first, or --dir.
          Prints [] when there are none

Exit 0 printed, or the check passed. Exit 1 the check found problems, one
"DECISIONS.md  <problem>" line each. Exit 2 bad usage, a base that is not a
commit, or a project or --dir folder that does not exist.
"""
import json
import os
import re
import subprocess
import sys

NAME = "DECISIONS.md"
USAGE = ("usage: decisions.py titles|active <project-dir>\n"
         "       decisions.py check <project-dir> [--base <commit> [--label <name>]]\n"
         "       decisions.py adr-scan <project-dir> [--dir <path>]")

HEADING = re.compile(r"^## D(\d+) · (\d{4}-\d{2}-\d{2}) · (.+)$")
FIELD = re.compile(r"^(Why|Rejected|Supersedes|Source|Status):\s*(.*)$")
FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
SUPERSEDED = re.compile(r"^superseded by D(\d+)$")
REQUIRED = ("Why", "Rejected", "Source", "Status")


class Entry:
    def __init__(self, n, heading):
        self.n = n
        self.heading = heading
        self.lines = [heading]
        self.fields = {}      # name -> [value lines]
        self.order = []       # field names, as they appear
        self.preamble = []    # body text before the first field

    def add(self, line):
        self.lines.append(line)
        match = FIELD.match(line)
        if match:
            name = match.group(1)
            self.order.append(name)
            self.fields.setdefault(name, []).append(match.group(2))
        elif line.strip():
            # A wrapped line belongs to the field above it.
            if self.order:
                self.fields[self.order[-1]].append(line)
            else:
                self.preamble.append(line)

    def value(self, name):
        return " ".join(" ".join(self.fields.get(name, [])).split())

    @property
    def status(self):
        return self.value("Status")

    @property
    def active(self):
        return self.status == "active"

    def recorded(self):
        """Everything a recorded entry may never change: all but its Status."""
        body = {name: self.value(name) for name in self.fields if name != "Status"}
        return (" ".join(self.heading.split()), " ".join(" ".join(self.preamble).split()), body)

    def unnumbered(self):
        """recorded() with the number left out, to find a renumbered entry."""
        heading, preamble, body = self.recorded()
        return (re.sub(r"^## D\d+ ", "## D ", heading), preamble, body)


def parse(text):
    """The entries, and every `## ` heading that is not an entry heading."""
    entries, bad_headings = [], []
    current = None
    fenced = False
    for line in text.splitlines():
        if FENCE.match(line):
            fenced = not fenced
        if not fenced and line.startswith("## "):
            match = HEADING.match(line)
            if match:
                current = Entry(int(match.group(1)), line)
                entries.append(current)
            else:
                bad_headings.append(line)
                current = None
            continue
        if current is not None:
            # Trailing blank lines are spacing, not part of the entry.
            current.add(line)
    for entry in entries:
        while entry.lines and not entry.lines[-1].strip():
            entry.lines.pop()
    return entries, bad_headings


def read(project):
    """The file's text; a missing file reads as no entries."""
    path = os.path.join(project, NAME)
    if not os.path.isfile(path):
        return ""
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def titles(project):
    active = [e for e in parse(read(project))[0] if e.active]
    width = max((len("D%d" % e.n) for e in active), default=0) + 2
    for entry in active:
        title = HEADING.match(entry.heading).group(3)
        print("%s%s" % (("D%d" % entry.n).ljust(width), title))


def active(project):
    blocks = ["\n".join(e.lines) for e in parse(read(project))[0] if e.active]
    if blocks:
        print("\n\n".join(blocks))


def structure(entries, bad_headings):
    problems = ["heading '%s' is not '## D<n> · <YYYY-MM-DD> · <title>'" % h
                for h in bad_headings]
    by_n = {}
    highest = None
    for entry in entries:
        if entry.n in by_n:
            if by_n[entry.n] == 1:
                problems.append("D%d appears twice" % entry.n)
            by_n[entry.n] += 1
            continue
        by_n[entry.n] = 1
        if highest is not None and entry.n < highest:
            problems.append("D%d comes after D%d — number each entry one more than the highest"
                            % (entry.n, highest))
        highest = entry.n if highest is None else max(highest, entry.n)

    first = {}
    for entry in entries:
        first.setdefault(entry.n, entry)

    for entry in entries:
        for name in REQUIRED:
            # An empty line says nothing, so it counts as no line.
            if not entry.value(name):
                if name == "Rejected":
                    problems.append("D%d has no Rejected line — a choice with nothing "
                                    "rejected is not an entry" % entry.n)
                else:
                    problems.append("D%d has no %s line" % (entry.n, name))
        if not entry.status:
            continue
        status = entry.status
        if status != "active" and not SUPERSEDED.match(status):
            problems.append("D%d Status is '%s' — it must be 'active' or 'superseded by D<n>'"
                            % (entry.n, status))
        elif entry.order[-1] != "Status":
            problems.append("D%d Status is not the last line" % entry.n)

        if "Supersedes" in entry.fields:
            target = re.match(r"^D(\d+)$", entry.value("Supersedes"))
            if not target:
                problems.append("D%d Supersedes is '%s' — it must name exactly one D<n>"
                                % (entry.n, entry.value("Supersedes")))
            else:
                old = first.get(int(target.group(1)))
                if old is None:
                    problems.append("D%d supersedes D%s, but there is no D%s"
                                    % (entry.n, target.group(1), target.group(1)))
                elif old.status != "superseded by D%d" % entry.n:
                    problems.append('D%d supersedes D%d, but D%d does not say "superseded by D%d"'
                                    % (entry.n, old.n, old.n, entry.n))

        superseded = SUPERSEDED.match(status)
        if superseded:
            newer = first.get(int(superseded.group(1)))
            if newer is None or newer.value("Supersedes") != "D%d" % entry.n:
                problems.append('D%d says "superseded by D%s", but D%s does not say "Supersedes: D%d"'
                                % (entry.n, superseded.group(1), superseded.group(1), entry.n))
    return problems


def history(recorded, entries):
    """Every entry recorded at the base is still here, changed only in Status."""
    problems = []
    now = {}
    for entry in entries:
        now.setdefault(entry.n, entry)
    seen = {}
    for old in recorded:
        seen[old.n] = seen.get(old.n, 0) + 1
    unmatched = list(entries)
    for old in recorded:
        if seen[old.n] > 1:
            # Two merged branches both added this number. Renumbering one
            # copy is the fix, so find each copy by its content instead.
            match = next((e for e in unmatched if e.unnumbered() == old.unnumbered()), None)
            if match is None:
                problems.append("D%d changed after it was recorded — only its Status line may "
                                "change; supersede it with a new entry" % old.n)
            else:
                unmatched.remove(match)
            continue
        new = now.get(old.n)
        if new is None:
            problems.append("D%d was removed after it was recorded — supersede it with a new "
                            "entry instead" % old.n)
        elif new.recorded() != old.recorded():
            problems.append("D%d changed after it was recorded — only its Status line may "
                            "change; supersede it with a new entry" % old.n)
    return problems


def git(project, *args):
    return subprocess.run(["git", "-C", project] + list(args),
                          capture_output=True, text=True)


def check(project, base, label):
    if base is not None and git(project, "rev-parse", "--verify", "--quiet",
                                base + "^{commit}").returncode != 0:
        print("decisions.py: base '%s' is not a commit" % base, file=sys.stderr)
        return 2
    path = os.path.join(project, NAME)
    if os.path.islink(path):
        print("%s  is a symlink — the session loader will not load it" % NAME)
        return 1
    if not os.path.isfile(path):
        print("%s  missing — onboarding creates it" % NAME)
        return 1
    # An untracked copy on disk is not what the branch merges.
    if base is not None and git(project, "ls-files", "--error-unmatch", "--", NAME).returncode != 0:
        print("%s  not tracked by git — commit it on this branch" % NAME)
        return 1

    entries, bad_headings = parse(read(project))
    problems = structure(entries, bad_headings)
    if base is not None:
        # "./" resolves from the project dir, which may sit below the repo root.
        shown = git(project, "show", "%s:./%s" % (base, NAME))
        if shown.returncode == 0:
            problems += history(parse(shown.stdout)[0], entries)

    if problems:
        for problem in problems:
            print("%s  %s" % (NAME, problem))
        return 1
    against = "" if base is None else " against %s" % (label or base)
    print("Decisions: %d entries checked%s" % (len(entries), against))
    return 0


ADR_DIRS = ("docs/adr", "doc/adr", "docs/decisions")
ADR_FILE = re.compile(r"^(\d+)-.+\.md$")
FRONT = re.compile(r"^([A-Za-z-]+):\s*(.*)$")
STATUS_HEADING = re.compile(r"^#{2,}\s+status\s*$", re.I)
DATE_LINE = re.compile(r"^Date:\s*(\S+)")
ISO_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
# The first number after "superseded by", link or not: "ADR-0006",
# "[6. Queue](0006-queue.md)", "[ADR-0006](0006-queue.md)".
SUCCESSOR = re.compile(r"superseded by\D*?(\d+)", re.I)
WORDS = ("accepted", "proposed", "rejected", "deprecated", "superseded")


def adr_status(front, section):
    """(status, successor number): a word from WORDS, the text as written,
    or None; the successor only for a superseded ADR."""
    text = front.get("status") or (section[0] if section else "")
    if not text:
        return None, None
    word = re.sub(r"[^a-z]", "", text.split()[0].lower())
    if word not in WORDS:
        return text, None
    successor = None
    if word == "superseded":
        # The /adr skill keeps the number in its own front matter key.
        for source in [text, "superseded by " + front.get("superseded-by", "")] + section:
            match = SUCCESSOR.search(source)
            if match:
                successor = int(match.group(1))
                break
    return word, successor


def read_adr(project, path, number):
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().splitlines()
    front, body = {}, lines
    if lines and lines[0].strip() == "---":
        for i, line in enumerate(lines[1:], 1):
            if line.strip() == "---":
                body = lines[i + 1:]
                break
            match = FRONT.match(line)
            if match:
                front[match.group(1).lower()] = match.group(2).strip().strip("\"'")
        else:
            front = {}   # no closing line: not front matter
    title, date, section = None, None, []
    in_status = fenced = False
    for line in body:
        if FENCE.match(line):
            fenced = not fenced
        if fenced:
            continue
        if line.startswith("# ") and title is None:
            title = line[2:].strip()
        elif line.startswith("#"):
            in_status = bool(STATUS_HEADING.match(line))
        elif in_status and line.strip():
            section.append(line.strip())
        match = DATE_LINE.match(line)
        if match and date is None:
            date = match.group(1)

    rel = os.path.relpath(path, project)
    if title:
        # "1. Title", "0006. Title", "ADR-0002: Title" -- only this ADR's own number.
        prefix = re.match(r"^(?:ADR[-\s]?)?(\d+)\s*[.:)-]?\s+", title, re.I)
        if prefix and int(prefix.group(1)) == number:
            title = title[prefix.end():]
    else:
        title = front.get("title") or re.sub(r"^\d+-", "", os.path.basename(path))[:-3].replace("-", " ").capitalize()

    date = front.get("date") or date
    date_from = "adr"
    if not (date and ISO_DATE.match(date)):
        added = git(project, "log", "--diff-filter=A", "--format=%as", "--", rel).stdout.split()
        date, date_from = (added[-1], "git") if added else (None, None)

    status, successor = adr_status(front, section)
    return {"file": rel, "adr": number, "title": title, "status": status,
            "successor_adr": successor, "date": date, "date_from": date_from,
            "seed": False, "d": None, "superseded_by_d": None, "supersedes_d": None,
            "skip_reason": None}


def adr_scan(project, folder):
    if not os.path.isdir(project):
        print("decisions.py: %s is not a directory" % project, file=sys.stderr)
        return 2
    if folder is not None:
        folders = [folder]
        if not os.path.isdir(os.path.join(project, folder)):
            print("decisions.py: --dir %s is not a directory" % folder, file=sys.stderr)
            return 2
    else:
        folders = ADR_DIRS
    files = []
    for candidate in folders:
        full = os.path.join(project, candidate)
        if os.path.isdir(full):
            files = sorted((int(m.group(1)), name) for name in os.listdir(full)
                           for m in [ADR_FILE.match(name)] if m)
            if files:
                break
    adrs = [read_adr(project, os.path.join(full, name), n) for n, name in files]

    def padded(n, like):   # an ADR number the way this repo writes it: 0003, 003
        return "%0*d" % (len(re.match(r"\d+", os.path.basename(like["file"])).group()), n)

    uses = {}
    for adr in adrs:
        uses[adr["adr"]] = uses.get(adr["adr"], 0) + 1
    for adr in adrs:
        if uses[adr["adr"]] > 1:
            # Which file "superseded by 0002" means is unknowable, so neither seeds.
            adr["skip_reason"] = "number %s is used by %d files" % (padded(adr["adr"], adr), uses[adr["adr"]])
        elif adr["status"] is None:
            adr["skip_reason"] = "no status"
        elif adr["status"] not in ("accepted", "superseded"):
            adr["skip_reason"] = adr["status"].capitalize() if adr["status"] in WORDS else adr["status"]
        elif adr["date"] is None:
            adr["skip_reason"] = "no date"
        elif adr["status"] == "superseded" and adr["successor_adr"] is None:
            adr["skip_reason"] = "Superseded, successor not named"

    # A superseded ADR seeds only when its successor seeds, and an entry
    # supersedes exactly one other. Dropping one can strand another, so repeat.
    changed = True
    while changed:
        changed = False
        seeded = {a["adr"]: a for a in adrs if a["skip_reason"] is None}
        claimed = {}
        for adr in adrs:
            if adr["skip_reason"] is not None or adr["status"] != "superseded":
                continue
            n = adr["successor_adr"]
            if n not in seeded:
                adr["skip_reason"] = "Superseded by %s, which is not seeded" % padded(n, adr)
                changed = True
            elif n in claimed:
                adr["skip_reason"] = "Superseded by %s, which already supersedes %s" % (
                    padded(n, adr), padded(claimed[n]["adr"], adr))
                changed = True
            else:
                claimed[n] = adr

    d_of = {}
    for adr in adrs:
        if adr["skip_reason"] is None:
            adr["seed"] = True
            adr["d"] = d_of[adr["adr"]] = len(d_of) + 1
    for adr in adrs:
        if adr["seed"] and adr["status"] == "superseded":
            successor = next(a for a in adrs if a["seed"] and a["adr"] == adr["successor_adr"])
            adr["superseded_by_d"] = successor["d"]
            successor["supersedes_d"] = adr["d"]
    print(json.dumps(adrs, indent=2, ensure_ascii=False))
    return 0


def main(argv):
    if len(argv) == 2 and argv[0] in ("titles", "active"):
        {"titles": titles, "active": active}[argv[0]](argv[1])
        return 0
    if len(argv) == 2 and argv[0] == "check":
        return check(argv[1], None, None)
    if len(argv) in (2, 4) and argv[0] == "adr-scan":
        if len(argv) == 4 and argv[2] != "--dir":
            print(USAGE, file=sys.stderr)
            return 2
        return adr_scan(argv[1], argv[3] if len(argv) == 4 else None)
    if len(argv) >= 4 and argv[0] == "check" and argv[2] == "--base":
        label = None
        if len(argv) == 6 and argv[4] == "--label":
            label = argv[5]
        elif len(argv) != 4:
            print(USAGE, file=sys.stderr)
            return 2
        return check(argv[1], argv[3], label)
    print(USAGE, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
