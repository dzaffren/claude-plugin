# Artifact Digest Pattern

Forge's house style for presenting an artifact after writing it. Every thinking
skill — discovery, PRD, and refinement — writes its file, then shows a concise
inline digest of the key decisions so the user can review and decide without
opening anything. The digest is an addition; the full file is always written.

## Format

```
<2–6 lines summarising the artifact's key decisions, in plain language>

Open the full file for complete detail: <path>
```

## Rules

- **Write first, then digest.** The digest is shown only after the file is on
  disk. Never withhold or replace the file with the digest — the digest is an
  addition, not a substitute.
- **Enough to decide.** The digest must carry enough for the user to approve,
  request a change, or move on without opening the file. See the minimums below.
- **One-line open offer.** End every digest with exactly one line offering the
  full file path to open. Nothing follows it.
- **Plain language.** Summarise decisions in prose or tight bullets; do not
  paste the file's headings or full sections back into the conversation.
- **Set digest for multiple files.** When a step writes more than one file (e.g.
  an epic overview + N story specs), summarise the _set_: name each story and
  what it delivers, plus the shared context (success metrics, how stories
  connect). Offer to open any one file. Do NOT inline every file's full contents.
- **Same pattern everywhere.** Apply this identically at the close of discovery,
  prd, and prd-refine.

## Minimum digest contents

| Artifact         | Digest must include                                                                                                                 |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Discovery brief  | desired outcome, selected opportunity, chosen solution, riskiest assumption, recommended experiment                                 |
| PRD / story spec | the user story, scope in, scope out, headline acceptance criteria, success metric                                                   |
| Refined spec     | which technical sections were added (e.g. system design, implementation plan sub-tasks, test scenarios) and any decisions/tradeoffs |

## Example

```
PRD written — CSV export.

User story: as a user viewing a table, I can export it to a downloadable file.
In scope: exporting the current table view to a downloadable file.
Out of scope: scheduled or recurring exports.
Headline acceptance criteria: an export of the visible rows downloads in one click.
Success metric: share of users who complete an export on their first attempt.

Open the full file for complete detail: docs/specs/csv-export/spec.md
```

## Example — multi-file set

```
Epic written — billing portal (overview + 3 story specs).

- view invoices — list and open past invoices.
- update payment method — change the card on file.
- download receipts — save a PDF receipt per charge.

Shared context: success metric is the share of users who self-serve a billing
task without contacting support; the three stories share one billing data model.

Open any one file for complete detail: docs/specs/billing-portal/spec.md
```
