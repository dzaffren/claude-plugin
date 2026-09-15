# The report

What a stage prints when it finishes. One copy of the shape, one copy of each
example — `scripts/check-report.sh` reads the examples out of this file at test
time, so the rule and the check cannot drift apart.

## The parts, in order

| Part | Rule |
| ---- | ---- |
| Header | `{Stage}: {what was looked at} — {size}`. The first line, always |
| Verdict | One or two sentences. What it means for the reader, good or bad news first |
| Count line | How many were raised, how many held up. Words, not a ratio |
| Finding | Four labels, in this order: `What breaks`, `Costs you`, `Where`, `Fix`. At most two sentences each. Worst first |
| Decision | Every finding ends with `→ Fix it, or skip it?` |
| Glossary | Every technical word the report used, one plain line each. No technical words, no Glossary section |
| Next | The last line names the next command, or the question to answer |

## Rules

**Say the consequence, not a severity word.** A finding is titled by what goes
wrong for someone — "Anyone can download another team's rows" — never
`Critical:`, `High:`, `Medium:`, `Low:`, or a `Severity:` line.

**Define every technical word.** `references/glossary.md` holds the words and
their lines. A word that file does not have yet gets its line written into it in
the same run. A report never ships with a word it did not explain.

**One decision per finding.** The reader answers each one on its own. Never a
single yes/no covering several findings.

**No summary at the end.** The verdict already said it. The last line is the
next step, nothing else.

**The ban list in `voice.md` applies here too.** That stays a prompt rule — the
checker reads structure, not vocabulary.

## Example — a report with findings

<!-- example:findings -->
```
Review: feat/share-links — 6 files, 240 lines

Two real problems. One lets a stranger read a shared report; the other hides a
failure from the person who caused it.
The reviewers raised 9 possible problems and 7 did not hold up on a second look.

1. Anyone can guess a share link, given enough tries
   What breaks  The share token is compared with ===, which stops at the first
                wrong character. How long the check takes tells an attacker how
                much of the token they already have, so they can find the rest
                one character at a time.
   Costs you    Any shared report can be read by someone it was never sent to.
   Where        api/shares.ts:88
   Fix          Compare with crypto.timingSafeEqual — it takes the same time
                whatever the input.
   → Fix it, or skip it?

2. A failed copy looks like it worked
   What breaks  The catch block in the copy handler returns without telling
                anyone, so the "Copied" message shows even when nothing reached
                the clipboard.
   Costs you    Someone pastes an empty link into an email and finds out when
                the recipient says it does not work.
   Where        ui/ShareModal.tsx:41
   Fix          Show the error state the design system already has.
   → Fix it, or skip it?

Glossary
  token           the secret string in a share link that proves you may read the report
  timing attack   guessing a secret by measuring how long a wrong guess takes to fail
  catch block     the part of the code that runs when something fails
  clipboard       where Copy puts something so you can paste it

Next: answer each finding above, then /ship.
```
<!-- /example -->

## Example — a report with nothing in it

<!-- example:clean -->
```
Review: feat/share-links — 6 files, 240 lines

Nothing to fix. I looked for bugs, security holes, and code more complicated than
it needs to be.
The reviewers raised 4 possible problems and none held up on a second look.

Next: /ship
```
<!-- /example -->

A clean report has no findings, so it has no decisions and no Glossary. It still
has a header, a verdict, a count line, and a next step.
