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
| `Handed to SLICE` | Shape only. The question belongs to a later slice. Does not block the shape. `/spec SLICE` copies it in as `Open`, naming the shape row. |
| `Decided alone` | `/build` or `/review` made a choice without the user. The Answer says what was chosen, the other choice, and how to undo it. Does not block. |

## Rules

**1. Never guess silently.** At a pause in `/shape` or `/spec`, ask each
unknown, as "Asking at a pause" says. Do not write it down without asking. In
`/build` and `/review`, a choice made without the user is a `Decided alone`
row, as "Deciding alone" says. In any other stage, any moment a stage would
assume something to keep moving, it writes an `assumption` row first. The
assumption still gets used — work continues — but it is now visible and owed
an answer.

**2. Rows are never deleted.** A resolved row is the decision record. Six
months later it answers "why did we do it this way". A row resolved as a
choice between options — one picked, another rejected — also drafts a D-entry
per `decisions.md`, shown and approved in the same pause.

**3. Resume starts with the ledger.** `/spec continue` prints the Open rows
first and works through them. Resolved rows stay resolved and are not
reopened unless the user reopens them.

**4. Nothing is approved with an Open row.** No pause of `/shape` or `/spec`
is approved while a row is Open, and this includes pauses 1 and 2. A shape is
not `Shaped`, and a spec is not `Refined`, while any row is `Open`: each is
answered, accepted, or — in a shape only — handed to the later slice it
belongs to. `/build` still refuses to start with any Open row. It prints them
and sends the user to `/spec continue {slice}`. It asks nothing.

**5. `Accepted risk` is a real answer, not a failure.** Some things genuinely
don't need resolving before building. It needs a stated reason, which is what
separates a decision from a shrug.

**6. New items can appear at any stage.** `/build` and `/review` add a
`Decided alone` row for each choice they make, and go on. Only a blocker sets
the spec back to `Draft`, at the end of the run. `/review` finding an
unconsidered case adds a row.

**7. A script enforces it.** `check-open-items.sh` runs on the Stop hook: a
shape at Status `Shaped`, or a spec at `Refined`, `Built` or `Shipped`, with
any `Open` row fails the turn. It judges only the zuko docs this branch or the
working tree changed, so an old breach never fails an unrelated turn.
`Accepted risk`, `Decided alone` and `Handed to SLICE` rows never count.
Prompt rules drift; grep does not.

## Asking at a pause

At each pause, `/shape` and `/spec` ask the user every open question and
every assumption. Use the question prompt, the `AskUserQuestion` tool.

- Ask up to four questions in one prompt. When there are more, use several
  prompts, one after the other.
- Give each question two to four answers. Put the recommended answer first,
  and end its label with "(Recommended)".
- For an `unproven` row, put `/poc` first. Put the recommended answer second.
- In a shape, give a question that belongs to a later slice the answer
  "Hand to {slice}", with a slice from the table.
- Write each answer into its row as `Resolved`, `Accepted risk` or, in a
  shape, `Handed to {slice}`. Add the date.
- When a question has no answer to offer, such as "What made you think of
  this?", ask it as plain text.

When no row is Open, the last question approves the pause. A typed reply is a
change. Make the change, then ask again. `/spec` pause 3 has no last question:
the user types `/build`, and that approves the plan.

| Pause | Last question | Answers |
| --- | --- | --- |
| `/spec` pause 1 | Approve pause 1 of {slice}? | Approve (Recommended): go on to pause 2. Not yet: stop here. |
| `/spec` pause 2 | Approve pause 2 of {slice}? | Approve (Recommended): go on to pause 3. Not yet: stop here. |
| `/shape` | Which slice do we spec first? | The recommended slice first, then the others. Not yet: stop here. |

**No question prompt.** In a `claude -p` run, or when the user denies the
tool, print the questions as a numbered list. Put the recommended answer first
in each. Then stop. Do not write an answer, and leave each row Open.

```text
Open items. Answer by number:

1. O2 · Can a refund be more than the order total?
   Recommended: No. A refund stops at the order total.
   Or: Yes, up to 110% as a goodwill payment.
2. O3 · Assuming refunds over £500 need a manager's approval. Is that right?
   Recommended: Yes.
   Or: No. Any refund goes through.
```

## Deciding alone

`/build` and `/review` never stop to ask. When a choice comes up, make it, add
a row and go on.

| The choice | What to do |
| --- | --- |
| An approved scenario is wrong. | Change it, and edit the spec to match. Go on, also when the change drops the scenario. |
| A scenario needs a file that the plan did not name. | Change the file. |
| A `/review` fix changes what the spec approved: an interface, a message or the scope. | Apply the fix, and edit the spec to match. |
| A Decisions finding. | Change the code to obey the entry. Do not edit `DECISIONS.md`. Superseding the entry stays the user's call. |

Add one row for each choice. Its Status is `Decided alone`, its Type is
`flag`, and Raised at is `build` or `review`. The Answer has three parts and
the date:

- **Chose:** what you did.
- **Other:** the choice that you did not make.
- **Undo:** what the user does to get the other choice. Name the commit when
  a `git revert` is enough.

When the choice changes a scenario, put its old text in the What column.

```markdown
| O7 | Scenario 3 said "Then the CSV has the columns number, date, total and VAT". The invoices table has no VAT field. | flag | build | user | Decided alone | Chose: drop the VAT column. Other: add a VAT field to invoices. Undo: put back the old scenario 3, and add the field. 2026-10-12 |
```

**A blocker** is a thing that you cannot choose around: a missing secret, an
account or a paid service. Build and test each scenario that does not need
it. At the end, set the spec's Status to `Draft` first. Then add an Open
`question` row that names the blocker, and report it. Do not stop in the
middle of the run.

## What qualifies

Keep the ledger for real unknowns. A ledger full of trivia gets rubber-stamped,
which is worse than no ledger.

**Belongs in it:**
- a business rule nobody has decided
- a technical claim the plan depends on and nobody has verified
- a consequence the user should weigh (cost, downtime, a breaking change)
- an interface contract with something outside this repo
- anything where being wrong means rework, not a small fix
- a choice that /build or /review made alone, as "Deciding alone" says: it
  changes what the user approved

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
