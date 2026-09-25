# scripts/lib/decisions.py adr-scan -- finding a repo's ADRs, reading each
# status and date, and numbering the ones to seed into DECISIONS.md.
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

# Inside run.sh's own temp dir, which its EXIT trap removes.
work=$(mktemp -d -p "$work")
decisions="$scripts/lib/decisions.py"
fixtures="$scripts/tests/fixtures/adr"

new_repo() {   # new_repo; prints an empty git repo
  local dir
  dir=$(mktemp -d -p "$work")
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email t@example.com
  git -C "$dir" config user.name Tester
  printf '%s' "$dir"
}

commit_all() {  # commit_all <repo>: one commit dated 2025-03-20
  git -C "$1" add -A
  GIT_AUTHOR_DATE="2025-03-20T10:00:00" GIT_COMMITTER_DATE="2025-03-20T10:00:00" \
    git -C "$1" commit -q --no-verify -m "docs: add ADRs"
}

scan() {       # scan <repo> [args...]; sets $scan_out $scan_status
  scan_out=$(python3 "$decisions" adr-scan "$@" 2>&1)
  scan_status=$?
}

# One ADR's fields, "key=value" per line, from $scan_out. JSON null prints None.
fields() {     # fields <adr number>
  printf '%s' "$scan_out" | python3 -c '
import json, sys
for adr in json.load(sys.stdin):
    if adr["adr"] == int(sys.argv[1]):
        for key, value in adr.items():
            print("%s=%s" % (key, value))' "$1" 2>/dev/null
}

adr() {        # adr <file> <status section line> [date]: a Nygard ADR
  {
    printf '# %s\n\n' "$(basename "$1" .md | sed -E 's/^0*([0-9]+)-/\1. /; s/-/ /g')"
    [ -n "${3:-}" ] && printf 'Date: %s\n\n' "$3"
    printf '## Status\n\n%s\n\n## Context\n\nA reason.\n' "$2"
  } >"$1"
}

# --- The seven fixture ADRs ---

repo=$(new_repo)
mkdir -p "$repo/docs/adr"
cp "$fixtures"/*.md "$repo/docs/adr/"
commit_all "$repo"
scan "$repo"
expect_exit 0 "$scan_status" "fixtures: adr-scan exits 0"
expect_match '^7$' "$(printf '%s' "$scan_out" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>&1)" \
  "fixtures: one object per ADR file"

# Scenario 1: accepted ADRs become active entries, numbered from D1.
one=$(fields 1)
expect_match '^file=docs/adr/0001-record-architecture-decisions\.md$' "$one" "0001: path relative to the repo"
expect_match '^title=Record architecture decisions$' "$one" "0001: title without its number prefix"
expect_match '^status=accepted$' "$one" "0001: Nygard ## Status read"
expect_match '^date=2025-03-02$' "$one" "0001: date from the Date: line"
expect_match '^date_from=adr$' "$one" "0001: date_from adr"
expect_match '^seed=True$' "$one" "0001: seeded"
expect_match '^d=1$' "$one" "0001: becomes D1"
two=$(fields 2)
expect_match '^title=Use Postgres$' "$two" "0002: MADR title"
expect_match '^status=accepted$' "$two" "0002: MADR status: front matter read"
expect_match '^date=2025-03-09$' "$two" "0002: date from date: front matter"
expect_match '^d=2$' "$two" "0002: becomes D2"

# Scenario 2: no Date line, so the date comes from the file's first commit.
three=$(fields 3)
expect_match '^date=2025-03-20$' "$three" "0003: date from the first commit"
expect_match '^date_from=git$' "$three" "0003: date_from git"
expect_match '^d=3$' "$three" "0003: becomes D3"

# Scenario 3: the supersede pair, with the successor named through a link.
four=$(fields 4)
expect_match '^status=superseded$' "$four" "0004: superseded"
expect_match '^successor_adr=6$' "$four" "0004: successor read through the markdown link"
expect_match '^seed=True$' "$four" "0004: seeded"
expect_match '^d=4$' "$four" "0004: becomes D4"
expect_match '^superseded_by_d=5$' "$four" "0004: superseded by D5"
six=$(fields 6)
expect_match '^title=Queue for imports$' "$six" "0006: /adr skill title without its number prefix"
expect_match '^status=accepted$' "$six" "0006: /adr skill front matter status read"
expect_match '^d=5$' "$six" "0006: becomes D5, skipping the unseeded 0005"
expect_match '^supersedes_d=4$' "$six" "0006: supersedes D4"
expect_match '^superseded_by_d=None$' "$six" "0006: still in force"

# Scenario 4: undecided and retired ADRs are named, not seeded.
five=$(fields 5)
expect_match '^seed=False$' "$five" "0005: not seeded"
expect_match '^d=None$' "$five" "0005: no D-number"
expect_match '^skip_reason=Proposed$' "$five" "0005: named as Proposed"
seven=$(fields 7)
expect_match '^seed=False$' "$seven" "0007: not seeded"
expect_match '^skip_reason=Deprecated$' "$seven" "0007: named as Deprecated"

# --- Nothing to seed ---

repo=$(new_repo)
scan "$repo"
expect_exit 0 "$scan_status" "no ADR folder: exit 0"
expect_match '^\[\]$' "$scan_out" "no ADR folder: prints []"

mkdir -p "$repo/docs/adr"
printf '# Architecture Decision Records\n' >"$repo/docs/adr/README.md"
scan "$repo"
expect_match '^\[\]$' "$scan_out" "folder with only a README: prints []"

scan "$work/no-such-repo"
expect_exit 2 "$scan_status" "missing project dir: exit 2, not an empty pass"
scan "$repo" --dir docs/nowhere
expect_exit 2 "$scan_status" "missing --dir: exit 2, not an empty pass"

# --- Where ADRs live ---

repo=$(new_repo)
mkdir -p "$repo/doc/adr"
adr "$repo/doc/adr/0001-use-make.md" "Accepted" 2025-01-01
scan "$repo"
expect_match '"file": "doc/adr/0001-use-make\.md"' "$scan_out" "doc/adr/ is found"

repo=$(new_repo)
mkdir -p "$repo/docs/decisions"
adr "$repo/docs/decisions/0001-use-make.md" "Accepted" 2025-01-01
scan "$repo"
expect_match '"file": "docs/decisions/0001-use-make\.md"' "$scan_out" "docs/decisions/ is found"

repo=$(new_repo)
mkdir -p "$repo/architecture/records"
adr "$repo/architecture/records/0001-use-make.md" "Accepted" 2025-01-01
scan "$repo" --dir architecture/records
expect_match '"file": "architecture/records/0001-use-make\.md"' "$scan_out" "--dir scans the named folder"

# --- Status edge cases ---

# The /adr skill marks a superseded ADR in front matter, number in superseded-by.
repo=$(new_repo)
mkdir -p "$repo/docs/adr"
printf -- '---\nnumber: 0001\nstatus: Superseded\ndate: 2025-01-01\nsuperseded-by: 0002\n---\n\n# 0001. Use cron\n\n## Status\n\nSuperseded\n' \
  >"$repo/docs/adr/0001-use-cron.md"
adr "$repo/docs/adr/0002-use-a-queue.md" "Accepted" 2025-02-01
scan "$repo"
expect_match '^successor_adr=2$' "$(fields 1)" "front matter superseded-by: names the successor"
expect_match '^superseded_by_d=2$' "$(fields 1)" "front matter superseded ADR pairs with D2"

# adr-tools writes the successor as "[6. Title](file)".
repo=$(new_repo)
mkdir -p "$repo/docs/adr"
adr "$repo/docs/adr/0004-use-cron.md" "Superseded by [6. Use a queue](0006-use-a-queue.md)" 2025-01-01
adr "$repo/docs/adr/0006-use-a-queue.md" "Accepted" 2025-02-01
scan "$repo"
expect_match '^successor_adr=6$' "$(fields 4)" "adr-tools link form names the successor"

# Superseded by an ADR that is not seeded, and a chain that ends in one.
repo=$(new_repo)
mkdir -p "$repo/docs/adr"
adr "$repo/docs/adr/0001-first.md" "Superseded by ADR-0002" 2025-01-01
adr "$repo/docs/adr/0002-second.md" "Superseded by ADR-0003" 2025-02-01
adr "$repo/docs/adr/0003-third.md" "Proposed" 2025-03-01
adr "$repo/docs/adr/0004-fourth.md" "Superseded by ADR-0009" 2025-04-01
adr "$repo/docs/adr/0005-fifth.md" "Accepted" 2025-05-01
scan "$repo"
expect_match '^seed=False$' "$(fields 2)" "successor Proposed: not seeded"
expect_match '^skip_reason=Superseded by 0003, which is not seeded$' "$(fields 2)" "successor Proposed: named with why"
expect_match '^seed=False$' "$(fields 1)" "chain ending unseeded: not seeded"
expect_match '^skip_reason=Superseded by 0002, which is not seeded$' "$(fields 1)" "chain ending unseeded: named with why"
expect_match '^skip_reason=Superseded by 0009, which is not seeded$' "$(fields 4)" "missing successor: named with why"
expect_match '^d=1$' "$(fields 5)" "the only seeded ADR is D1"

# Two ADRs superseded by one: an entry supersedes exactly one, so the lower pairs.
repo=$(new_repo)
mkdir -p "$repo/docs/adr"
adr "$repo/docs/adr/0001-cron.md" "Superseded by ADR-0003" 2025-01-01
adr "$repo/docs/adr/0002-systemd-timer.md" "Superseded by ADR-0003" 2025-02-01
adr "$repo/docs/adr/0003-queue.md" "Accepted" 2025-03-01
scan "$repo"
expect_match '^superseded_by_d=2$' "$(fields 1)" "shared successor: the lower ADR pairs"
expect_match '^supersedes_d=1$' "$(fields 3)" "shared successor: the successor supersedes the lower one"
expect_match '^skip_reason=Superseded by 0003, which already supersedes 0001$' "$(fields 2)" \
  "shared successor: the higher ADR is named with why"

# No status, an unknown status, a Rejected ADR, and no date anywhere.
repo=$(new_repo)
mkdir -p "$repo/docs/adr"
printf '# 1. Something\n\nDate: 2025-01-01\n\n## Context\n\nA reason.\n' >"$repo/docs/adr/0001-something.md"
adr "$repo/docs/adr/0002-draft-thing.md" "Draft" 2025-01-01
adr "$repo/docs/adr/0003-rejected-thing.md" "Rejected" 2025-01-01
adr "$repo/docs/adr/0004-undated.md" "Accepted"
scan "$repo"
expect_match '^skip_reason=no status$' "$(fields 1)" "no status: named as no status"
expect_match '^skip_reason=Draft$' "$(fields 2)" "unknown status: named as written"
expect_match '^skip_reason=Rejected$' "$(fields 3)" "Rejected: named"
expect_match '^skip_reason=no date$' "$(fields 4)" "untracked with no Date line: not guessed"
expect_match '^date_from=None$' "$(fields 4)" "untracked with no Date line: date_from None"

# --- check with no base: how onboarding checks a log it just seeded ---

repo=$(new_repo)
cat >"$repo/DECISIONS.md" <<'LOG'
# Decisions

## D1 · 2025-04-01 · Cron for imports

Why: imports run twice a month.
Rejected: not recorded in docs/adr/0004-cron-for-imports.md
Source: docs/adr/0004-cron-for-imports.md
Status: superseded by D2

## D2 · 2025-05-10 · Queue for imports

Why: a failed cron import sat unnoticed for nine days.
Rejected: Cron with a retry wrapper (no alerting).
Supersedes: D1
Source: docs/adr/0006-queue-for-imports.md
Status: active
LOG
check_out=$(python3 "$decisions" check "$repo" 2>&1)
expect_exit 0 "$?" "no base: an untracked, valid log passes"
expect_match '^Decisions: 2 entries checked$' "$check_out" "no base: scope line has no base"
grep -v '^Supersedes: D1$' "$repo/DECISIONS.md" >"$repo/log.tmp" && mv "$repo/log.tmp" "$repo/DECISIONS.md"
check_out=$(python3 "$decisions" check "$repo" 2>&1)
expect_exit 1 "$?" "no base: a broken supersede pair fails"
expect_match 'D1 says "superseded by D2", but D2 does not say "Supersedes: D1"' "$check_out" \
  "no base: names the broken pair"
mv "$repo/DECISIONS.md" "$repo/DECISIONS.gone"
check_out=$(python3 "$decisions" check "$repo" 2>&1)
expect_exit 1 "$?" "no base: a missing file fails"

# Two files with one number: which one "0002" means is unknowable, so neither seeds.
repo=$(new_repo)
mkdir -p "$repo/docs/adr"
adr "$repo/docs/adr/0001-a.md" "Accepted" 2025-01-01
adr "$repo/docs/adr/0002-b.md" "Accepted" 2025-02-01
adr "$repo/docs/adr/0002-c.md" "Accepted" 2025-02-02
adr "$repo/docs/adr/0003-d.md" "Superseded by ADR-0002" 2025-03-01
adr "$repo/docs/adr/0004-e.md" "Accepted" 2025-04-01
scan "$repo"
dups=$(printf '%s' "$scan_out" | python3 -c '
import json, sys
for adr in json.load(sys.stdin):
    print(adr["file"], adr["d"], adr["skip_reason"], sep=" | ")' 2>&1)
expect_match '^docs/adr/0002-b\.md \| None \| number 0002 is used by 2 files$' "$dups" "shared number: first file not seeded"
expect_match '^docs/adr/0002-c\.md \| None \| number 0002 is used by 2 files$' "$dups" "shared number: second file not seeded"
expect_match '^docs/adr/0003-d\.md \| None \| Superseded by 0002, which is not seeded$' "$dups" \
  "shared number: an ADR superseded by it is not seeded"
expect_match '^docs/adr/0004-e\.md \| 2 \| None$' "$dups" "shared number: D-numbers stay unique"
