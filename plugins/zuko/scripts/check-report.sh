#!/usr/bin/env bash
# Reads a finished report and says whether it follows references/report.md.
# Usage: check-report.sh [<file>]   -- reads stdin when no file is given
#
# Exit 0  it conforms; prints what was checked
# Exit 1  it does not; one line per problem, each with its line number
# Exit 2  nothing to check -- no file, an empty input, or a path that is not there
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
glossary="$here/../references/glossary.md"

if [ "$#" -gt 0 ]; then
  if [ ! -f "$1" ]; then
    echo "check-report.sh: nothing to check — no file at $1." >&2
    exit 2
  fi
  report=$(cat "$1")
else
  report=$(cat)
fi

if [ -z "${report//[[:space:]]/}" ]; then
  echo "check-report.sh: nothing to check — empty input." >&2
  exit 2
fi

ZUKO_REPORT="$report" ZUKO_GLOSSARY="$glossary" python3 <<'PY'
import os
import re
import sys

lines = os.environ["ZUKO_REPORT"].split("\n")
problems = []

LABELS = ["What breaks", "Costs you", "Where", "Fix"]
LABEL_LINE = re.compile(r'^\s*(%s)\s' % "|".join(LABELS))
DECISION = re.compile(r'→.*skip')
SEVERITY = re.compile(r'^\s*(?:\d+\.\s*)?(Critical|High|Medium|Low|Severity):')


def fail(index, message):       # index is 0-based; reports are 1-based
    problems.append((index + 1, message))


# The vocabulary, and the words it deliberately leaves alone. Both are read from
# glossary.md, because a list you can read beats a rule you have to infer.
vocabulary, spared = [], set()
section = None
for line in open(os.environ["ZUKO_GLOSSARY"], encoding="utf-8"):
    if line.startswith("## "):
        section = line[3:].strip().lower()
        continue
    if section == "words the checker does not chase":
        spared.update(w.strip().strip("`").lower()
                      for w in line.split("·") if w.strip().startswith("`"))
        continue
    cell = re.match(r'^\|\s*([^|]+?)\s*\|', line)
    if cell and cell.group(1).lower() not in ("word", "----"):
        vocabulary.append(cell.group(1).lower())
vocabulary = [w for w in vocabulary if w not in spared]


def plain(line):
    """The line's own words. A token holding a slash, or a dot or colon with
    something after it, is a path, a branch or a file:line — never a word the
    report used. Trailing punctuation is not part of a word: `token.` at the end
    of a sentence is the same word as `token` in the middle of one."""
    kept = []
    for token in line.split():
        bare = token.strip('.,;:!?()[]"\'')
        if bare and "/" not in bare and not re.search(r'[.:]\S', bare):
            kept.append(bare)
    return kept


def sentences(text):
    """Sentence ends, counting the punctuation but not the dots inside a path or
    a file:line — `api/import.ts:12` ends no sentence."""
    kept = [t for t in text.split()
            if "/" not in t and not re.search(r'[.:]\S', t.strip('()[]"\''))]
    return len(re.findall(r'[.!?](?:\s|$)', " ".join(kept) + " "))


filled = [(i, l) for i, l in enumerate(lines) if l.strip()]

# Header. Line 1, not "the first line with something on it" — a report that
# opens with a blank line has already lost the reader's first glance.
head_at = 0
if not re.match(r'^[A-Za-z][A-Za-z ]*: .+ [—-] .+$', lines[0]):
    fail(head_at, 'the first line is not a header — "{Stage}: {what was looked at} — {size}"')

starts = [i for i, l in enumerate(lines) if re.match(r'^\d+\. ', l)]
ends = starts[1:] + [len(lines)]
inside = {i for n, start in enumerate(starts) for i in range(start, ends[n])}

gloss_at = next((i for i, l in enumerate(lines) if l.strip() == "Glossary"), None)
next_at = next((i for i, l in reversed(list(enumerate(lines))) if l.strip()), None)

# A finding nobody numbered is still a finding, and every check below hangs off
# the numbering. Left unsaid, a report could skip the numbers and skip the rules.
for i, line in enumerate(lines):
    if i not in inside and (LABEL_LINE.match(line) or DECISION.search(line)):
        fail(i, "a finding that is not numbered — findings are numbered 1., 2., 3.")
    if SEVERITY.match(line):
        fail(i, "a severity label — say what it costs someone instead")

# Verdict and count line.
stop = starts[0] if starts else (gloss_at if gloss_at is not None else next_at)
opening = [(i, l) for i, l in filled if head_at < i < stop]
counts = [(i, l) for i, l in opening if re.search(r'\braised\b', l)]
if not counts:
    fail(head_at, "no count line — say how many were raised and how many held up")
if not [l for i, l in opening if (i, l) not in counts]:
    fail(head_at, "no verdict between the header and what follows")

# Findings.
for n, start in enumerate(starts, 1):
    block = lines[start:ends[n - 1]]
    text = "\n".join(block)

    at = {}
    for label in LABELS:
        found = re.search(r'^\s*' + label + r'\b', text, re.M)
        if found:
            at[label] = found.start()
    missing = [label for label in LABELS if label not in at]
    if missing:
        fail(start, 'finding %d has no "%s" line' % (n, missing[0]))
    elif sorted(at, key=at.get) != LABELS:
        fail(start, "finding %d has its labels out of order: %s"
                    % (n, ", ".join(sorted(at, key=at.get))))
    else:
        if not re.search(r'^\s*Where\s+\S+:\d+', text, re.M):
            fail(start, 'finding %d has a "Where" line with no file:line' % n)
        edges = sorted(at.values()) + [len(text)]
        for label in LABELS:
            piece = text[at[label]:edges[sorted(at.values()).index(at[label]) + 1]]
            if sentences(piece) > 2:
                fail(start, 'finding %d runs to more than two sentences on "%s"'
                            % (n, label))

    if not DECISION.search(text):
        fail(start, "finding %d has no fix-or-skip question" % n)

# Glossary coverage.
body_lines = [(i, l) for i, l in filled
              if i != head_at and i != next_at
              and not (gloss_at is not None and i >= gloss_at)]
body = " ".join(" ".join(plain(l)) for _, l in body_lines).lower()

defined, gloss_end = [], gloss_at
if gloss_at is not None:
    for i in range(gloss_at + 1, len(lines)):
        if not lines[i].strip() or lines[i].strip().startswith("Next:"):
            break
        defined.append(" ".join(lines[i].split()).lower())
        gloss_end = i

for word in vocabulary:
    if re.search(r'(?<![\w-])' + re.escape(word) + r'(?![\w-])', body):
        if not any(entry.startswith(word + " ") for entry in defined):
            at_line = next((i for i, l in body_lines
                            if re.search(r'(?<![\w-])' + re.escape(word) + r'(?![\w-])',
                                         " ".join(plain(l)).lower())), head_at)
            fail(at_line, '"%s" is used here and not defined in the Glossary' % word)

# Nothing after the findings but the next step. The verdict already said it.
boundary = None
if starts:
    decisions = [i for i in range(starts[-1], len(lines)) if DECISION.search(lines[i])]
    boundary = decisions[-1] if decisions else None
if gloss_at is not None:
    boundary = gloss_end
if boundary is not None:
    for i, line in filled:
        if i > boundary and i != next_at:
            fail(i, "a closing summary — the verdict already said it")

# Next step.
if next_at is None or not lines[next_at].strip().startswith("Next:"):
    fail(next_at if next_at is not None else head_at,
         'the last line is not a next step — it must start with "Next:"')

if problems:
    for at_line, message in sorted(problems):
        print("check-report.sh: line %d — %s." % (at_line, message), file=sys.stderr)
    sys.exit(1)

parts = ["header", "verdict", "count line"]
if starts:
    parts.append("%d finding%s" % (len(starts), "" if len(starts) == 1 else "s"))
    parts.append("%d decision%s" % (len(starts), "" if len(starts) == 1 else "s"))
else:
    parts.append("no findings")
if gloss_at is not None:
    parts.append("glossary (%d word%s)" % (len(defined), "" if len(defined) == 1 else "s"))
parts.append("next step")
print("check-report.sh: %d lines — %s." % (len(lines), ", ".join(parts)))
PY
