# Inline Artifact Digests

**Ticket:** TBD

**Epic Overview:** [spec.md](spec.md)

**Discovery Brief:** docs/discovery/build-once-quality/brief.md

Whenever forge's discovery, PRD, or refinement stage finishes writing an
artifact — a discovery brief, a PRD spec, or a refined spec — it presents a
concise digest of that artifact's key decisions directly in the conversation,
followed by a one-line offer to open the full file. The user can read, decide,
and keep moving without opening anything. This removes the friction of opening
a file at every step and keeps the decision loop fast for the indie builder,
founder, or product-minded developer running forge.

## User Story

As an indie builder running forge to shape a product, I want to see a concise
digest of each artifact right in the conversation as soon as it's written, so
that I can review what was decided and approve or request a change without
opening the file.

## Background & Context

**Current state:**

- forge's discovery, PRD, and refinement stages each produce an artifact and
  tell the user that a file was written.
- To see what was actually decided — the chosen opportunity, the scope, the
  acceptance criteria, the success metric — the user generally has to open the
  file.

**Problem:**

- Opening a file at the end of every stage adds friction and slows the
  decision loop. It is the opposite of "decide quickly and keep moving".
- When a stage writes several files at once (an epic overview plus several
  story specs), the user has even more files to open just to understand what
  was produced.
- forge is pre-launch, and this file-opening friction is one of the gaps the
  owner wants closed before sharing forge publicly.

## Target User & Persona

- **Who:** An indie builder, founder, or product-minded developer running
  forge to shape and build a product.
- **Context:** They are in a working session, moving through discovery, then
  the PRD stage, then refinement. At the end of each stage they need to decide
  whether the artifact is right before moving to the next stage.
- **Current workaround:** They open each written file in their editor to read
  the full artifact, then return to the conversation to respond.

## Goals

- Present a concise inline digest of every artifact the moment it is written,
  containing enough for the user to decide without opening the file.
- Always end the digest with a one-line offer to open the full file for
  complete detail.
- Apply the same digest-then-detail pattern consistently across the discovery
  brief, the PRD spec(s), and the refined spec.
- Summarise a multi-file set (e.g. an epic overview plus several story specs)
  as a set, without flooding the conversation with every file's full contents.

## Non-Goals

- The challenge / pushback behaviour forge applies while shaping an artifact —
  that is covered by the calibrated-pushback story and is out of scope here.
- Changing what goes into the artifacts themselves, or how the files are named
  or organised. This story only adds the inline digest presentation.
- Any setting to turn the digest off or change its length.

## User Workflow

> The step-by-step experience from the user's perspective.

1. **A stage finishes** — forge has just written an artifact (for example, a
   PRD for a CSV-export feature) and the user is waiting to see what was
   decided.
2. **Digest appears inline** — forge shows a concise digest right in the
   conversation: the key decisions and sections of the artifact, in plain
   language.
3. **One-line offer to open** — directly under the digest, forge offers, in a
   single line, to open the full file for complete detail.
4. **The user decides** — reading only the digest, the user approves, asks for
   a change, or moves to the next stage. If they want the full detail, they
   open the file from the offer that's right there.

## Acceptance Criteria

> Scenarios are from the perspective of the person running forge.

### Scenario: Single-artifact digest appears inline after a PRD is written

```gherkin
Given I am running forge's PRD stage for a "CSV export" feature
When forge finishes writing the PRD
Then I see a digest in the conversation that includes the user story, what is in scope, what is out of scope, the headline acceptance criteria, and the success metric
  And I see a one-line offer to open the full file for complete detail
  And the full file has been written, not withheld
```

### Scenario: Digest of a CSV-export PRD shows scope in and out

```gherkin
Given I am running forge's PRD stage for a "CSV export" feature
When forge finishes writing the PRD
Then the digest tells me that exporting the current table view to a downloadable file is in scope
  And the digest tells me that scheduled or recurring exports are out of scope
  And the digest names the success metric as the share of users who complete an export on their first attempt
  And I see a one-line offer to open the full file for complete detail
```

### Scenario: Marcus approves a discovery brief from the digest alone

```gherkin
Given Marcus is running forge's discovery stage for a "team availability calendar" idea
When forge finishes writing the discovery brief
Then Marcus sees a digest showing the desired outcome, the selected opportunity, the chosen solution, the riskiest assumption, and the recommended experiment
  And Marcus sees a one-line offer to open the full file
When Marcus replies that the brief looks right and to move on
Then forge moves to the next stage without Marcus having opened the file
```

### Scenario: The user drills into the full file from the offer

```gherkin
Given forge has just shown me the digest of a refined spec
  And the digest ends with a one-line offer to open the full file
When I choose to open the full file
Then I can read the complete refined spec in full detail
  And the digest I already saw matches the key decisions in the full file
```

### Scenario: A multi-file epic is digested as a set, not flooded

```gherkin
Given I am running forge's PRD stage for a "billing portal" idea that is large enough to split into multiple stories
When forge finishes writing an epic overview plus three story specs — "view invoices", "update payment method", and "download receipts"
Then I see a digest of the set that names each of the three stories and what each one delivers
  And I see the shared context from the epic overview, including the success metrics and how the stories connect
  And I see a one-line offer to open any one of the files for complete detail
  And the conversation does not contain the full contents of every file
```

### Scenario: The user opens one story spec from a multi-file digest

```gherkin
Given forge has shown me a set digest for the "billing portal" epic with three story specs
  And the digest offers to open any one of the files
When I ask to open the "update payment method" story spec
Then I can read that one story spec in full detail
  And the other files remain available to open but are not dumped into the conversation
```

### Scenario Outline: The digest-then-detail pattern is consistent across every thinking stage

```gherkin
Given I am running forge's <stage> stage
When forge finishes writing the <artifact>
Then I see a concise inline digest of the <artifact>'s key decisions
  And I see a one-line offer to open the full file for complete detail
  And the full file has been written

Examples:
  | stage      | artifact        |
  | discovery  | discovery brief |
  | PRD        | PRD spec        |
  | refinement | refined spec    |
```

### Scenario: The digest is an addition, never a replacement for the file

```gherkin
Given forge has finished writing any artifact in discovery, the PRD stage, or refinement
When forge presents the inline digest
Then the full file still exists and can be opened
  And the digest never stands in place of writing the file
```

## Business Rules & Constraints

- **Digest-then-detail (shared rule).** Every artifact forge writes is
  presented as a concise inline digest of its key decisions and sections,
  followed by a one-line offer to open the full file. The full file is never
  withheld — the digest is an addition, not a replacement.
- **Enough to decide.** A digest must contain enough for the user to approve,
  request a change, or move to the next stage without opening the file. For a
  PRD, that means at least the user story, scope in and out, the headline
  acceptance criteria, and the success metric.
- **One-line offer.** The offer to open the full file is a single line that
  follows the digest, so the path to full detail is always right there.
- **Set digest for multiple files.** When a stage writes more than one file
  (for example an epic overview plus several story specs), the digest
  summarises the set — naming each story and what it delivers, plus the shared
  context — and offers to open any one file. It must not place the full
  contents of every file into the conversation.
- **Consistency.** The same digest-then-detail pattern applies identically to
  the discovery brief, the PRD spec(s), and the refined spec.

## Success Metrics

- In a real end-to-end run (discovery to PRD to refinement on one genuine
  feature), the user reaches the build step having reviewed every artifact
  without opening a single file — confirmed by the user stating "I didn't need
  to open anything".
- For each artifact, the digest contained enough for the user to decide —
  approve, request a change, or move on — without opening the file, confirmed
  by the user not opening the file before deciding.
- When a stage produces multiple files, the user can say what each file
  delivers from the set digest alone, without opening any of them.

## Dependencies

- A real, genuine feature idea to run the end-to-end experiment from the
  discovery brief — the validation depends on running one real feature through
  the full chain, not a synthetic example.

## Open Questions

- [x] ~~How much should an inline digest show?~~ — **Resolved:** a concise
      digest of the artifact's key decisions and sections (for a PRD: the user
      story, scope in and out, headline acceptance criteria, and success
      metric), plus a one-line offer to open the full file.
- [x] ~~What happens when a stage writes several files at once?~~ —
      **Resolved:** the digest summarises the set, naming each story and what
      it delivers plus the shared context, and offers to open any one file
      rather than dumping every file's full contents.
- [x] ~~Does the digest replace writing the file?~~ — **Resolved:** no. The
      full file is always written and never withheld; the digest is an
      addition.

---

## Functional Requirements

- **Single source of truth.** The digest contract lives in one new shared
  reference, `plugins/forge/references/artifact-digest.md`, referenced by each
  thinking skill via `${CLAUDE_PLUGIN_ROOT}/references/`. Skills do not restate
  the format inline.
- **Write-then-digest ordering.** The digest is produced only after the artifact
  file is written. The file is never withheld or replaced by the digest
  (digest = addition, not substitute).
- **Minimum digest contents by artifact type:**
  - **Discovery brief:** desired outcome, selected opportunity, chosen solution,
    riskiest assumption, recommended experiment.
  - **PRD / story spec:** the user story, scope in, scope out, headline
    acceptance criteria, success metric.
  - **Refined spec:** what technical sections were added (e.g. system design,
    implementation plan sub-tasks, test scenarios) and any decisions/tradeoffs.
- **One-line open offer.** Each digest ends with exactly one line offering the
  full file path to open.
- **Set digest for multiple files.** When a step writes >1 file (epic overview +
  N story specs), the digest names each story and what it delivers plus the
  shared context, and offers to open any one file — it must NOT inline the full
  contents of every file.
- **Consistency.** The same contract applies identically at the close of
  discovery, prd, and prd-refine.

## Permissions & Security

N/A — no authorization surface. The digest echoes user-authored artifact content
back into the same conversation; nothing is read from or sent anywhere external.

## System Design

This story implements the **`artifact-digest.md` producer** plus edits to its
three consumers (the hand-off/closing steps). See the epic overview's _Shared
System Design_ for the component diagram and tradeoffs. Story-specific contract:

`plugins/forge/references/artifact-digest.md` must define: the per-artifact
minimum contents above, the one-line open-offer format, the multi-file set rule,
and the "addition, never replacement" rule.

## Threat Model Checklist

- **Data classification:** N/A — no PII/secrets; surfaces user-authored content
  only, within the same conversation.
- **Attack surface:** N/A — no endpoints, parsers, uploads, or network calls.
- **Authn / authz changes:** N/A — none.
- **Dependency additions:** None.

## Architecture Notes

- **New file:** `plugins/forge/references/artifact-digest.md` (exemplar to mirror
  for tone/structure: `plugins/forge/references/multi-choice.md`).
- **Edited files:**
  - `plugins/forge/skills/product-discovery/SKILL.md` — _Step 8: Write the brief
    and hand off_: after writing, present the brief digest + one-line open offer.
  - `plugins/forge/skills/prd/SKILL.md` — _Step 9: Handoff_: present a digest of
    the spec(s); for epics, use the set digest (overview + each story) instead of
    inlining every file.
  - `plugins/forge/skills/prd-refine/SKILL.md` — _Step 6_ (the "Then STOP. Tell
    the user the path(s)" step): present the refined-spec digest + open offer.
- **Verification constraint:** skills load at session start (repo learning
  `blocker-skills-load-at-session-start`) — exercise in a fresh session.

## Implementation Plan

| #   | Sub-task                                                                                                                 | Label                  | Size | Files                                                                                                                                                      |
| --- | ------------------------------------------------------------------------------------------------------------------------ | ---------------------- | ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Author `artifact-digest.md` (per-artifact contents, one-line open offer, set-digest rule, addition-not-replacement rule) | INDEPENDENT            | M    | `plugins/forge/references/artifact-digest.md` (new)                                                                                                        |
| 2   | Add brief digest to discovery hand-off                                                                                   | SEQUENTIAL (after 1)   | S    | `plugins/forge/skills/product-discovery/SKILL.md`                                                                                                          |
| 3   | Add spec / epic-set digest to prd hand-off                                                                               | SEQUENTIAL (after 1)   | S    | `plugins/forge/skills/prd/SKILL.md`                                                                                                                        |
| 4   | Add refined-spec digest to prd-refine close                                                                              | SEQUENTIAL (after 1)   | S    | `plugins/forge/skills/prd-refine/SKILL.md`                                                                                                                 |
| 5   | Add eval cases asserting digest contents + one-line offer + set-digest behaviour                                         | SEQUENTIAL (after 2–4) | S    | `plugins/forge/skills/product-discovery/evals/evals.json`, `plugins/forge/skills/prd/evals/evals.json`, `plugins/forge/skills/prd-refine/evals/evals.json` |

Sub-tasks 2–4 are independent of each other (different files) but all depend on
sub-task 1.

## Negative Constraints

- Do NOT change what goes into the artifacts themselves, or how files are named/
  organised — this story only adds the inline digest presentation.
- Do NOT withhold or stop writing the full file; the digest is always an addition.
- Do NOT add a setting to disable or resize the digest (explicit non-goal).
- Do NOT inline the full contents of every file in the multi-file case.
- Do NOT describe digest styling/colours/layout — content only.

## Test Scenarios

> Validated by `evals.json` cases and a manual fresh-session run; no unit/HTTP
> tests exist in this repo.

- **TS1 — Single PRD digest:** Finish a "CSV export" PRD → digest includes user
  story, scope-in ("export current table view to a downloadable file"), scope-out
  ("scheduled/recurring exports"), headline acceptance criteria, success metric
  ("share of users who complete an export on first attempt"), then one open-offer
  line. Eval expectation added to `prd/evals/evals.json`.
- **TS2 — Brief digest, decide-without-opening:** Finish a "team availability
  calendar" discovery brief → digest shows outcome, selected opportunity, chosen
  solution, riskiest assumption, recommended experiment; user approves without an
  open action. Eval expectation added to `product-discovery/evals/evals.json`.
- **TS3 — Epic set digest, no flood:** PRD step writes an epic overview + three
  story specs ("view invoices", "update payment method", "download receipts") →
  digest names each story + shared success metrics + offers to open any one;
  asserts the full text of all four files is NOT inlined. Eval expectation added
  to `prd/evals/evals.json`.
- **TS4 — Refined-spec digest:** Finish prd-refine on a spec → digest lists the
  technical sections added (system design, implementation plan, test scenarios)
  - one open-offer line. Eval expectation added to `prd-refine/evals/evals.json`.
- **TS5 — Addition-not-replacement:** For any artifact, after the digest is
  shown the full file still exists on disk at its path. Asserted by the manual
  run (file present) and an eval expectation "the file is written, not replaced
  by the digest".

## Verification

- **Backend tests:** N/A — no application code.
- **Eval suite:** Run forge's eval harness against the three updated
  `evals.json` files; the new cases (TS1–TS5) must pass.
- **Browser / UI:** N/A — no UI.
- **E2E:** N/A — no E2E framework in this repo (`package.json` absent); the E2E
  mapping section is intentionally omitted.
- **Manual fresh-session run (the brief's experiment):** In a new session, take
  one real feature through discovery → prd → prd-refine and confirm the user can
  approve every artifact from its digest alone, never needing to open a file, and
  that the epic case digests as a set rather than flooding the conversation.
