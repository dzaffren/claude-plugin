#!/bin/bash
# Update CHANGELOG.md in Keep-a-Changelog format.
#
# Two modes:
#   1. Append-to-Unreleased (default)
#        update-changelog.sh <type> <subject>
#        Inserts "- <subject>" under the appropriate heading of [Unreleased].
#
#   2. Release
#        update-changelog.sh --release <version> [--date YYYY-MM-DD]
#        Renames [Unreleased] to [<version>] - <date>, then re-seeds a fresh
#        [Unreleased] block above it.
#
# <type> maps to a Keep-a-Changelog heading:
#   feat        → Added
#   fix         → Fixed
#   refactor    → Changed
#   perf        → Changed
#   docs        → Changed          (rarely interesting; skip-me is the caller's call)
#   test        → (skip — return 0 silently)
#   chore|ci|build|style|revert → (skip)
#
# Anything emitting "(skip)" returns 0 and does not modify CHANGELOG.md.

set -eu

CHANGELOG=CHANGELOG.md
if [ ! -f "$CHANGELOG" ]; then
  echo "no CHANGELOG.md in cwd; skipping" >&2
  exit 0
fi

MODE=append
VERSION=""
DATE=""

if [ "${1:-}" = "--release" ]; then
  MODE=release
  VERSION=${2:-}
  shift 2 || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --date) DATE=$2; shift 2 ;;
      *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
  done
  if [ -z "$VERSION" ]; then
    echo "usage: $(basename "$0") --release <version> [--date YYYY-MM-DD]" >&2
    exit 2
  fi
  if [ -z "$DATE" ]; then
    DATE=$(date +%Y-%m-%d)
  fi
fi

if [ "$MODE" = "append" ]; then
  TYPE=${1:-}
  shift || true
  SUBJECT=${*:-}
  if [ -z "$TYPE" ] || [ -z "$SUBJECT" ]; then
    echo "usage: $(basename "$0") <type> <subject>" >&2
    exit 2
  fi
  case "$TYPE" in
    feat)                 HEADING="Added" ;;
    fix)                  HEADING="Fixed" ;;
    refactor|perf|docs)   HEADING="Changed" ;;
    test|chore|ci|build|style|revert) exit 0 ;;
    *) echo "unknown type: $TYPE" >&2; exit 2 ;;
  esac

  python3 - "$CHANGELOG" "$HEADING" "$SUBJECT" <<'PY'
import sys, re, pathlib
path, heading, subject = sys.argv[1], sys.argv[2], sys.argv[3]
text = pathlib.Path(path).read_text()

unreleased_re = re.compile(r"(^## \[Unreleased\][^\n]*\n)(.*?)(?=^## \[|\Z)", re.M | re.S)
m = unreleased_re.search(text)
if not m:
    # Insert a fresh [Unreleased] block near the top after the first heading.
    top = "## [Unreleased]\n\n"
    first = re.search(r"^# [^\n]+\n+", text)
    insert_at = first.end() if first else 0
    text = text[:insert_at] + top + text[insert_at:]
    m = unreleased_re.search(text)

head, body = m.group(1), m.group(2)
section_re = re.compile(rf"(### {heading}\n)((?:- [^\n]*\n)*)", re.M)
sm = section_re.search(body)
entry = f"- {subject}\n"
if sm:
    new_body = body[:sm.end(1)] + entry + sm.group(2) + body[sm.end():]
else:
    block = f"\n### {heading}\n{entry}"
    new_body = body.rstrip() + "\n" + block + "\n" if body.strip() else f"\n### {heading}\n{entry}\n"
    # Ensure exactly one blank line after head
    if not new_body.startswith("\n"):
        new_body = "\n" + new_body

out = text[:m.start()] + head + new_body + text[m.end():]
pathlib.Path(path).write_text(out)
PY

  exit 0
fi

# Release mode
python3 - "$CHANGELOG" "$VERSION" "$DATE" <<'PY'
import sys, re, pathlib
path, version, date = sys.argv[1], sys.argv[2], sys.argv[3]
text = pathlib.Path(path).read_text()

unreleased_re = re.compile(r"^## \[Unreleased\][^\n]*", re.M)
m = unreleased_re.search(text)
if not m:
    sys.stderr.write("no [Unreleased] section found; nothing to release\n")
    sys.exit(0)

new_heading = f"## [{version}] - {date}"
replaced = text[:m.start()] + new_heading + text[m.end():]

fresh = "## [Unreleased]\n\n"
out = re.sub(rf"^{re.escape(new_heading)}", fresh + new_heading, replaced, count=1, flags=re.M)
pathlib.Path(path).write_text(out)
PY
