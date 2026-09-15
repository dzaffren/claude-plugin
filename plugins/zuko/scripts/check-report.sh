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

report = os.environ["ZUKO_REPORT"]
lines = report.split("\n")
problems = []


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

filled = [(i, l) for i, l in enumerate(lines) if l.strip()]
if not filled:
    sys.exit(2)

# Header. Line 1, not "the first line with something on it" — a report that
# opens with a blank line has already lost the reader's first glance.
head_at, head = 0, lines[0]
if not re.match(r'^[A-Za-z][A-Za-z ]*: .+ [—-] .+$', head):
    fail(head_at, 'the first line is not a header — "{Stage}: {what was looked at} — {size}"')

starts = [i for i, l in enumerate(lines) if re.match(r'^\d+\. ', l)]
ends = starts[1:] + [len(lines)]

gloss_at = next((i for i, l in enumerate(lines) if l.strip() == "Glossary"), None)
next_at = next((i for i, l in reversed(list(enumerate(lines))) if l.strip()), None)

# Verdict and count line: at least two filled lines between the header and the
# first finding, or the next-step line when there are none.
stop = starts[0] if starts else (gloss_at if gloss_at is not None else next_at)
opening = [(i, l) for i, l in filled if head_at < i < stop]
if len(opening) < 2:
    fail(head_at, "no verdict and count line between the header and what follows")

# Findings.
LABELS = ["What breaks", "Costs you", "Where", "Fix"]
for n, start in enumerate(starts, 1):
    block = lines[start:ends[n - 1]]
    text = "\n".join(block)

    seen = [l for l in LABELS if re.search(r'^\s*' + l + r'\b', text, re.M)]
    if seen != LABELS:
        missing = [l for l in LABELS if l not in seen]
        if missing:
            fail(start, 'finding %d has no "%s" line' % (n, missing[0]))
        else:
            fail(start, "finding %d has its labels out of order: %s" % (n, ", ".join(seen)))
    elif not re.search(r'^\s*Where\s+\S+:\d+', text, re.M):
        fail(start, 'finding %d has a "Where" line with no file:line' % n)

    if not re.search(r'→.*skip', text):
        fail(start, "finding %d has no fix-or-skip question" % n)

    if re.match(r'^\d+\.\s+(Critical|High|Medium|Low)\b', block[0]):
        fail(start, "finding %d is titled with a severity label — say the consequence" % n)

for i, line in enumerate(lines):
    if re.match(r'^\s*Severity:', line):
        fail(i, "a Severity: line — say the consequence instead")

# Glossary coverage. The header line and the next-step line are the report's own
# furniture, and any token holding / . or : is a path, a branch, or a file:line,
# never a word the report used. Plurals are not chased: a matcher that guesses
# trades a false alarm you can see for a miss you cannot.
body_lines = [(i, l) for i, l in filled
              if i != head_at and i != next_at
              and not (gloss_at is not None and i >= gloss_at)]
body = " ".join(re.sub(r'\S*[/.:]\S*', " ", l) for _, l in body_lines).lower()

defined = []
if gloss_at is not None:
    for line in lines[gloss_at + 1:]:
        if not line.strip() or line.strip().startswith("Next:"):
            break
        defined.append(" ".join(line.split()).lower())

for word in vocabulary:
    if re.search(r'(?<![\w-])' + re.escape(word) + r'(?![\w-])', body):
        if not any(entry.startswith(word + " ") for entry in defined):
            at = next((i for i, l in body_lines
                       if re.search(r'(?<![\w-])' + re.escape(word) + r'(?![\w-])',
                                    re.sub(r'\S*[/.:]\S*', " ", l).lower())), head_at)
            fail(at, '"%s" is used here and not defined in the Glossary' % word)

# Next step.
if next_at is None or not lines[next_at].strip().startswith("Next:"):
    fail(next_at if next_at is not None else head_at,
         "the last line is not a next step — it must start with \"Next:\"")

if problems:
    for at, message in sorted(problems):
        print("check-report.sh: line %d — %s." % (at, message), file=sys.stderr)
    sys.exit(1)

parts = ["header", "verdict"]
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
