# Decisions

Every real choice zuko makes with the user lands in one `DECISIONS.md` at the
repo root. One copy of the rules — `/spec`, `/poc`, `/design system`, and the
ledger all draft entries from this file, and `/review` holds the code to it.

## The file

```markdown
# Decisions

Append-only. A changed decision is a new entry that supersedes the old one; only an
old entry's Status line ever changes.

## D7 · 2026-09-24 · Use Postgres, not SQLite

Why: two finance users import at month end at the same time; SQLite locks the whole
file on write.
Rejected: SQLite (whole-file write lock), DynamoDB (cost for under 1 GB of data).
Source: specs/import-csv.md
Status: superseded by D12

## D12 · 2026-11-02 · Postgres on the server, SQLite for the laptop cache

Why: offline mode needs a local store with transactions; the laptop never has a second
writer, while the server still has two month-end importers.
Rejected: IndexedDB (no Python client), JSON files (no transactions).
Supersedes: D7
Source: specs/offline-mode.md
Status: active
```

| Line          | Rule                                                                                             |
| ------------- | ------------------------------------------------------------------------------------------------ |
| Heading       | `## D<n> · <YYYY-MM-DD> · <title>` — n is one more than the highest so far                       |
| `Why:`        | required; the reason, with a number where one exists                                             |
| `Rejected:`   | required; at least one option with its reason — no rejected option, no entry                     |
| `Supersedes:` | optional; exactly one `D<n>`, replaced whole — the new entry restates any part that still stands |
| `Source:`     | required; the spec, spike or design doc that made the choice                                     |
| `Status:`     | required, last line; `active` or `superseded by D<n>`                                            |

## What counts as an entry

A choice where at least one option was rejected, with its reason. No rejected
option → no entry; the choice stays in the spec.

Naming, style, and reusing a helper the repo already has are not entries, even
when an alternative crossed your mind.

## Numbering

One more than the highest `D<n>` in the file, counting superseded entries. The
first entry is D1. Never reuse a number.

## Supersede, never edit

A decision that changed is a new entry with `Supersedes: D<n>`. It replaces the
old one whole: restate any part of the old entry that still stands, so every
entry is either fully in force or fully history.

Then change the old entry's `Status:` line to `superseded by D<new>`. No other
line of the old entry changes, and no entry is ever removed.

## Drafting in a pause

The stage that made the choice drafts the entry and shows it in that stage's
pause summary:

```
Decisions to record (approve with this pause):
  D7  Use Postgres, not SQLite
      Rejected: SQLite (whole-file write lock), DynamoDB (cost)
Relies on: D2, D5
```

The user approves entries with the pause they came from. Approved → append
them to `DECISIONS.md`, full form, dated today, `Status: active`, and flip the
Status line of anything they supersede. Not approved → drop them with the rest
of that pause; the user's corrections come back as a new draft.

## Reading the active entries

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/decisions.py" titles <project-dir>
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/decisions.py" active <project-dir>
```

`titles` prints one line per active entry. `active` prints the full active
entries. Read `active` before proposing a choice: a plan that uses an option
an active entry rejected cites that entry and asks whether to supersede it. It
never proposes the rejected option as new.

## `Relies on:` in specs

A spec lists the active entries its plan depends on, under Technical plan ›
Approach:

```markdown
Relies on: D2, D5, D7
```

Include the entries this spec's own pause just drafted. None → `Relies on: none`.

## Enforced

`scripts/verify-ship-gates.sh` runs `scripts/lib/decisions.py check` against
the branch's merge-base. It fails the ship on an edited or removed entry, a
duplicate number, a missing required line, or a `Supersedes:` whose old entry
does not say `superseded by` the new one. The prose above drafts entries; the
gate does not trust it.
