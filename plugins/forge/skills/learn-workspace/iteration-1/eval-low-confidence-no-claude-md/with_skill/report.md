# Learn skill eval — low-confidence, no CLAUDE.md update

## Outcome: BLOCKED BY SANDBOX

The harness's sandbox denied every attempt to write into
`with_skill/repo/` (both `Write` and `Bash` tools — `mkdir`, `touch`, and
file creation all returned permission-denied). Writes one level up at
`with_skill/report.md` succeed, so the restriction is specifically the
`repo/` subtree. Because of this, the intended filesystem mutations
below were NOT applied to the fixture. The eval should either (a) grant
write permission on the fixture `repo/` path, or (b) be re-run in an
environment where that path is writable.

## Intended actions (per `/learn` skill, capture mode)

### Step 1 — Parse the observation

- Rule: auth tests in this repo tend to use the `seedUserWithRole` fixture.
- Type: **pattern** — project-specific reusable approach naming a
  concrete fixture (per `references/types.md`, this is the canonical
  pattern example).
- Why: user didn't supply one explicitly; captured as an observed
  tendency and flagged for future confirmation.
- Source: `/learn` — user capture during session.
- Confidence signal: **LOW**. User said "tend to" and "not a hard rule,
  just something I've noticed". These are the explicit opposite of the
  absolute language ("always", "never", "from now on") that Step 5 of
  the skill requires before touching CLAUDE.md.

### Step 2 — Dedupe check

`.claude/learnings/` does not exist in the fixture, so there are no
existing learnings to dedupe against. Proceed to Step 3.

### Step 3 — Write the learning file

Would create `.claude/learnings/pattern-auth-test-seeding.md` with this
exact content:

```markdown
---
name: auth-test-seeding
description: Auth tests tend to use the seedUserWithRole fixture (observed, not enforced)
type: pattern
captured: 2026-04-28
source: /learn — user capture during session
---

Auth-related tests in this repo tend to create their users via a
`seedUserWithRole` fixture rather than inserting into the `users` table
directly. The user flagged this as an observation, not a hard rule.

**Why:** Not explicitly stated by the user — captured as a tendency they
noticed across the auth test suite. The likely reason is that fixtures
route through the real user-creation code path (hashing, defaults, audit
hooks) while raw inserts bypass it, but this should be confirmed before
promoting the learning to a rule.

**How to apply:** When writing or reviewing auth tests, prefer the
`seedUserWithRole` fixture over direct DB inserts, but treat it as a soft
default rather than a requirement. If a test has a specific reason to
bypass the fixture, that's fine. Revisit this learning if the pattern
becomes more formal — at that point it can be promoted into CLAUDE.md.
```

### Step 4 — Create the index

Would create `.claude/learnings/INDEX.md` (it does not yet exist) with:

```markdown
# Learnings Index

Per-repo learnings captured by the `/learn` skill. Each entry points to a
file in this directory. The active ruleset is synced into the repo's
`CLAUDE.md` under `## Learnings`.

- [Auth test seeding](pattern-auth-test-seeding.md) — Auth tests tend to use the seedUserWithRole fixture (observed, not enforced).
```

### Step 5 — CLAUDE.md decision

**CLAUDE.md was NOT updated, and would not have been updated even if
writes had succeeded.**

Reason: the user's language ("tend to", "not a hard rule", "just
something I've noticed") is explicitly low-confidence. Step 5 of the
skill requires ONE of:

- absolute language ("always", "never", "from now on", "we don't", "we do"),
- an explicit instruction to update CLAUDE.md, or
- a `learning-capturer` proposal with explicit user approval.

None of those conditions are met here, so the learning stays in
`.claude/learnings/` only. CLAUDE.md remains untouched.

### Step 6 — Report

```
CAPTURED: pattern-auth-test-seeding
File: .claude/learnings/pattern-auth-test-seeding.md  (write blocked by sandbox)
Index updated: yes (also blocked by sandbox)
CLAUDE.md updated: no — user's language was low-confidence ("tend to",
"not a hard rule"); Step 5 requires absolute language or an explicit
request to promote the rule to CLAUDE.md.
```

## Files touched in the fixture

- **Created:** none (all blocked by sandbox).
- **Modified:** none.
- **CLAUDE.md:** NOT touched, and would not have been touched. This is
  the correct behavior per Step 5 — the low-confidence signal ("tend
  to", "not a hard rule") explicitly does NOT meet the bar for a
  CLAUDE.md rule.
