# The open-items ledger

Nothing unresolved reaches `/build`. This file defines how that works.

## Why

The old failure: "Open questions" was an optional section that got deleted
when it was inconvenient, and assumptions were never written down at all —
they were just made. Work then proceeded on guesses nobody had agreed to.

The ledger fixes both. It can only grow. Rows are resolved, never removed.

## The table

Every spec carries this section. It is never deleted, even when empty.

```markdown
## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| -- | ---- | ---- | --------- | ----- | ------ | ------ |
| O1 | Can a share link outlive the report? | question | shape | user | Resolved | No — link dies with the report |
| O2 | Assuming saved reports are immutable | assumption | spec p3 | poc | Open | — |
| O3 | Migration may lock a 4M-row table | flag | spec p3 | user | Accepted risk | Off-peak window, 40s lock, agreed 2026-09-08 |
```

**Type** — one of:

| Type | Means |
|---|---|
| `question` | Something we need to know and don't. Nobody can answer it from the code. |
| `assumption` | Something we're treating as true so work can continue, without proof. |
| `flag` | A known consequence someone should decide about. Not unknown — unwelcome. |
| `unproven` | A technical claim the plan rests on that a spike could settle. |

**Status** — one of:

| Status | Means |
|---|---|
| `Open` | Blocks `/build`. |
| `Resolved` | Answered. The answer is in the row, and the spec reflects it. |
| `Accepted risk` | Knowingly proceeding without an answer. Needs a reason and a date in the Answer column. Does not block. |

## Rules

**1. Never guess silently.** Any moment a stage would assume something to
keep moving, it writes an `assumption` row first. The assumption still gets
used — work continues — but it is now visible and owed an answer.

**2. Rows are never deleted.** A resolved row is the decision record. Six
months later it answers "why did we do it this way".

**3. Resume starts with the ledger.** `/spec continue` prints the Open rows
first and works through them. Resolved rows stay resolved and are not
reopened unless the user reopens them.

**4. `/build` refuses to start with any Open row.** It prints them, and walks
through each one with the user. Each becomes `Resolved` or `Accepted risk`
before a line of code is written.

**5. `Accepted risk` is a real answer, not a failure.** Some things genuinely
don't need resolving before building. It needs a stated reason, which is what
separates a decision from a shrug.

**6. New items can appear at any stage.** `/build` discovering a bad
assumption adds a row and routes back. `/review` finding an unconsidered case
adds a row.

**7. A script enforces it.** `check-open-items.sh` runs on the Stop hook: a
spec at Status `Built` or `Shipped` with any `Open` row fails the turn. Prompt
rules drift; grep does not.

## What qualifies

Keep the ledger for real unknowns. A ledger full of trivia gets rubber-stamped,
which is worse than no ledger.

**Belongs in it:**
- a business rule nobody has decided
- a technical claim the plan depends on and nobody has verified
- a consequence the user should weigh (cost, downtime, a breaking change)
- an interface contract with something outside this repo
- anything where being wrong means rework, not a small fix

**Does not belong in it:**
- naming
- anything the code answers in under five minutes — go read the code
- style preferences
- something you could just try
- a thing you already decided and are recording for comfort

## In the terminal

Show it compactly. Open rows only, unless asked:

```
Open items: 2 open
  O2  assumption  saved reports are immutable      → /poc can settle this (~20 min)
  O3  flag        migration locks 4M rows for ~40s → needs your call
```

`/status` shows an open count per spec, so a blocked spec is visible before
you pick it up.
