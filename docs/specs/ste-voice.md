# STE voice

**Version:** v1 · **Status:** Built · **Type:** Enhancement · **Project type:** CLI/Library

**Shape doc:** docs/specs/ask-up-front/shape.md
**Depends on:** None

zuko writes to the writing rules of ASD-STE100, a published standard that the
user can check against. Slices 3 to 5 write the pause questions and the PR body,
so the rules must be in place before them.

## Problem

zuko's writing follows `references/voice.md`: a ban list and ten house rules.
The rules have no numbers. "Short sentences" does not say how short. The user
cannot check a draft against a standard. In the five newest zuko docs, 14 of 209
prose sentences are longer than 25 words, and the longest has 43 words. A rough
sentence splitter made this count.

The shape says that every stage reads `voice.md` already. Eleven of the twelve
skills read it. `/status` does not read it, and no agent reads it. The agents
are chunk-builder, reviewer, finding-verifier and pentester.

## Slice test

| Check | Result |
| --- | --- |
| Cuts every layer it needs | yes. The rules in `voice.md`, the read line in each skill and agent that lacks it, the README's Voice section, and a contract test. |
| One e2e test walks it | partly. A contract test proves the text. The behaviour shows in the next real stage stop (O1). |
| Worth shipping alone | yes. Every stage writes to a standard that the user can check, and slices 3 to 5 use it from the start. |
| Fits (≤5 scenarios, ≤2 areas) | yes. 5 scenarios. Two areas: zuko's prompt text and the README. |

**Path:** full. It changes 8 files, which is more than the light path allows.
It adds no new interface, data or dependency. Pause 2 is the exact wording of
the rules.

## User story

As the person who reads zuko's specs and replies, I want them written to a
published standard, so I can check a draft against rules that I can look up.

## Flow

```mermaid
flowchart LR
    ST["a skill or agent starts"] -- "reads" --> V["references/voice.md"]
    V -- "ban list, house rules,<br/>STE rules" --> W{"what is it writing?"}
    W -- "a sentence of prose" --> S["STE: 20 words in an instruction,<br/>25 in a description"]
    W -- "code, a path, a quote,<br/>a heading, a commit subject" --> K["its own format"]
    S -- "the project's CLAUDE.md<br/>sets other rules" --> P["the project's rules win"]
```

Each skill and agent reads `voice.md` when it starts. A sentence of prose
follows the STE rules, unless the project's own rules say otherwise. Code,
paths, quotes, headings and commit subjects keep their own format.

## Acceptance criteria

```gherkin
Scenario: voice.md holds the STE rules
  Given voice.md on main has the ban list and ten house rules, and no STE rules
  When ste-voice ships
  Then voice.md has a section that names ASD-STE100 Issue 9, January 2025
  And the section states each rule in the "Rules adopted" list under Scope
  And it says that zuko does not use the STE dictionary
  And the ban list does not change
  And README.md's Voice section says that the stages write to the ASD-STE100 rules

Scenario: every skill and agent reads voice.md
  Given skills/status/SKILL.md and agents/chunk-builder.md, reviewer.md,
    finding-verifier.md and pentester.md do not name voice.md
  When ste-voice ships
  Then every plugins/zuko/skills/*/SKILL.md names references/voice.md
  And every plugins/zuko/agents/*.md names references/voice.md

Scenario: text that is not prose keeps its own format
  Given /ship writes the commit subject "docs(spec): mark stop-hook-scope shipped"
  And the PR body quotes the command bash plugins/zuko/scripts/tests/run.sh stop-scope
  When /ship applies voice.md
  Then the subject follows git-naming.md, with no article added
  And the command is copied as it is, and counts as one word in its sentence

Scenario: the project's own writing rules win
  Given the repo audit-portal has a CLAUDE.md that says
    "Write audit findings in the passive voice, as our report template does"
  When /review writes a finding in audit-portal
  Then the finding uses the passive voice
  And voice.md says that the project's own writing rules override the STE rules

Scenario: the next real stage stop follows the rules
  Given zuko is installed from the release that has ste-voice
  When /spec stops at pause 1 in a real session
  Then no prose sentence in the stop message has more than 25 words
  And no instruction in it has more than 20 words
```

The contract test proves scenarios 1 to 4 from the text of the files. Scenario
5 is checked by hand at the next real stop (O1).

## Scope

**In:**

- A new section in `voice.md`, next to the ban list. The ban list and the house
  rules stay. House rule 2, "Short sentences", points to the STE limits.
- **Rules adopted.** These rules need no dictionary, and a public source
  confirms each one (O5):
  - An instruction has 20 words or fewer. A description has 25 words or fewer.
  - One instruction in each sentence. Put a condition before the instruction.
  - Write an instruction as a command.
  - Use the active voice. In a description, use the passive only when the
    doer is not known.
  - A noun cluster has no more than three words.
  - One topic in each paragraph, and six sentences or fewer.
  - Use an "-ing" form only as a technical noun, or in one.
  - Do not leave out the verb, the subject or the article to make a sentence
    shorter.
  - Use a vertical list for complex text.
- **Which text.** Every new sentence that zuko writes: terminal replies, specs,
  shapes, PR bodies, commit bodies, CHANGELOG lines, reports, and agent output.
- **Not prose (O6).** Code, commands, paths, quoted text, headings, table
  labels, diagram labels and other fragments keep their own format. Quoted text
  includes the user's words, ticket text, tool output, and a message that a
  skill gives word for word. Commit subjects follow
  `git-naming.md`. Code comments match the comments in the file around them.
- **Full sentences.** A full sentence follows the rules, also in a table cell
  or a Gherkin step. A command, path, number or name in backticks counts as one
  word.
- **Clash.** When the project's CLAUDE.md sets its own writing rules, those
  rules win. STE fills the gaps (O4).
- The read line goes into `skills/status/SKILL.md` and the four agent files (O2).
- One sentence in README.md's Voice section.
- A contract test, `tests/test-ste-voice.sh`.

**Out:**

- The STE dictionary of about 900 approved words. Shape O1 rejected it, and no
  slice picks it up.
- The STE rules that depend on the dictionary, and the rules for safety
  warnings. zuko writes no aerospace-style warnings. No slice picks them up.
- Rule numbers. The repo has no copy of Issue 9 (O3).
- Rewriting old specs, skills and references into STE. Shape "Not doing": new
  text only.
- A script or gate that measures sentence length (O1). No slice picks it up.
- The wording of the pause questions and the PR body. pause-questions and
  decision-pr write those, in this voice.

## Interface

The interface is the text that Claude reads. This section gives the exact
wording that `/build` puts into each file.

```mermaid
flowchart LR
    SK["12 skills/*/SKILL.md"] -- "Read voice.md" --> V["references/voice.md:<br/>Simplified Technical English"]
    AG["4 agents/*.md"] -- "Read voice.md" --> V
    V -- "rules for each<br/>new sentence" --> O["replies, specs, PR bodies,<br/>commit bodies, agent output"]
    V -- "commit subjects" --> G["references/git-naming.md"]
    R["README.md: Voice"] -- "names the standard" --> U((user))
    O -- "checks against ASD-STE100" --> U
```

Each skill and agent reads `voice.md`. Its new section sets the rules for each
new sentence. The README tells the user which standard to check against.

### The new section in voice.md

It goes after "Banned outright" and before "Rules".

```markdown
## Simplified Technical English

zuko writes to the writing rules of ASD-STE100, Issue 9 (January 2025).
ASD-STE100 is Simplified Technical English, a standard from ASD, the European
aerospace and defence association. zuko uses the writing rules only. It does
not use the STE dictionary of approved words.

The rules apply to each new sentence that zuko writes. This includes terminal
replies, specs, shapes, PR bodies, commit bodies, CHANGELOG lines, reports and
agent output. Old text stays as it is.

An instruction tells the reader to do something. A description tells the
reader what is true.

1. An instruction has 20 words or fewer. A description has 25 words or fewer.
2. Write one instruction in each sentence. Put a condition before the
   instruction.
3. Write an instruction as a command.
4. Use the active voice. In a description, use the passive voice only when the
   doer is not known.
5. Do not make a noun cluster of more than three words.
6. Write about one topic in each paragraph. A paragraph has six sentences or
   fewer.
7. Use an "-ing" form only as a technical noun, or as part of one.
8. Do not leave out a verb, a subject or an article to make a sentence shorter.
9. Use a vertical list for complex text.

A command, path, number or name in backticks counts as one word.

**Not prose.** These keep their own format:

- code, commands and paths
- quoted text, copied as it is: the user's words, ticket text, tool output,
  and a message that a skill gives word for word
- headings, table labels, diagram labels and other fragments
- commit subjects, which follow `git-naming.md`
- code comments, which match the comments in the file around them

A full sentence follows the rules, also in a table cell or a Gherkin step.

**The project's rules win.** When the project's CLAUDE.md sets its own writing
rules, follow those rules. The STE rules fill the gaps.
```

### House rule 2 in voice.md

Before:

```markdown
2. **Short sentences.** If a sentence has two ideas, make it two sentences.
```

After:

```markdown
2. **Short sentences.** If a sentence has two ideas, make it two sentences.
   The word limits are in "Simplified Technical English", above.
```

### README.md, Voice section

One paragraph goes after the current paragraph:

```markdown
The sentence rules come from ASD-STE100, Simplified Technical English. An
instruction has 20 words or fewer, and a description has 25 or fewer.
```

### The read line

`/status` and the four agents get this line. The agents already name
`owasp.md` with `${CLAUDE_PLUGIN_ROOT}`, so `voice.md` uses the same form.

```markdown
Read `${CLAUDE_PLUGIN_ROOT}/references/voice.md` before you write anything.
```

## Technical plan

### Approach

This change is prompt text only. `/build` adds the new section to `voice.md`,
a second line to house rule 2, a paragraph to the README, and the read line to
five files. A contract test, `test-ste-voice.sh`, is written first and checks
each change.

Relies on: D37, D38 (drafted below)

```mermaid
flowchart TB
    subgraph readers["read voice.md when they start"]
        SK["skills/*/SKILL.md:<br/>11 today, and status"]
        AG["agents/*.md: chunk-builder,<br/>reviewer, finding-verifier, pentester"]
    end
    V["references/voice.md"]
    GN["references/git-naming.md"]
    RM["README.md: Voice"]
    T["tests/test-ste-voice.sh"]
    SK -- "read line" --> V
    AG -- "read line" --> V
    V -- "commit subjects" --> GN
    T -- "checks the section" --> V
    T -- "checks each read line" --> readers
    T -- "checks the paragraph" --> RM
```

Each skill and agent reads `voice.md` through its read line. The test checks
the new section, each read line and the README paragraph.

```mermaid
sequenceDiagram
    participant U as user
    participant RS as /review skill
    participant RA as reviewer agent
    participant FV as finding-verifier
    participant V as voice.md
    U->>RS: /review
    RS->>V: Read (review/SKILL.md:17)
    RS->>RA: the diff
    RA->>V: Read (new line in reviewer.md)
    RA-->>RS: findings in the STE voice
    RS->>FV: one finding
    FV->>V: Read (new line in finding-verifier.md)
    FV-->>RS: verdict in the STE voice
    RS-->>U: report in the STE voice
```

In a `/review` run, the skill and both agents read `voice.md` before they
write. Today only the skill reads it.

**Evidence that the read line works in an agent.** The agents already name
`${CLAUDE_PLUGIN_ROOT}/references/owasp.md`. In the session logs, six agent
runs read `owasp.md` at its full cache path, and their dispatch prompts did not
contain that path. So Claude Code puts the real path in the agent's prompt.

### Changes

| File | What changes | Why |
| --- | --- | --- |
| `plugins/zuko/scripts/tests/test-ste-voice.sh` (new) | The contract test, written first. It fails before the other changes. | Test plan |
| `plugins/zuko/references/voice.md:40` | The new section goes between "Banned outright" (line 11) and "Rules" (line 41), word for word from the Interface section. | Scenarios 1, 3, 4 |
| `plugins/zuko/references/voice.md:44` | House rule 2 gets its second line. | Scenario 1 |
| `README.md:143` | A new paragraph after the Voice paragraph. | Scenario 1 |
| `plugins/zuko/skills/status/SKILL.md:13` | The read line, as a new paragraph after the opening paragraph. | Scenario 2 |
| `plugins/zuko/agents/chunk-builder.md:11` | The read line, after the opening paragraph. | Scenario 2 |
| `plugins/zuko/agents/reviewer.md:10` | The read line, after "You review a diff. You do not fix anything." | Scenario 2 |
| `plugins/zuko/agents/finding-verifier.md:14` | The read line, after the opening paragraph. | Scenario 2 |
| `plugins/zuko/agents/pentester.md:15` | The read line, after the line that names `owasp.md`. | Scenario 2 |

Reusing: `run.sh`'s `expect_match` and `expect_no_match`, and a one-line
`section()` helper, defined the same way as `test-ascii-terminal.sh:12`.

Added after the build, by `/debug` at the user's request: `run.sh`'s
`expect_match` and `expect_no_match` pass the pattern to grep with `-e`. Before
this, grep read a pattern that starts with `-` as an option.
`test-run-helpers.sh` has one regression case for each helper.

Two tests read `voice.md` today. `test-ascii-terminal.sh` checks the "Visuals
over prose" section, and `test-design-system.sh` checks one read line. Neither
changes, and both must stay green.

### Earn-it

Nothing new: no layer, script, option or dependency. The only new file is the
test.

### Non-functionals

|  |  |
| --- | --- |
| **Load** | `voice.md` grows from 647 words to about 980. The five new readers each read it once in each run, which is about 1,300 tokens. |
| **Breaks first** | A longer `voice.md` is easier to skim. If it doubles again, split the STE section into its own reference. |
| **Security surface** | Prompt text only. Nothing calls it, it trusts no input, it touches no secrets, and it stores nothing. |
| **Proof it works** | After the release and a plugin update, the next `/spec` pause 1 stop has no prose sentence over 25 words. The rough splitter in the scratchpad counts it. |
| **Rollout** | No flag. Rollback: `git revert` the build commits. |

### Test plan

| Scenario | Test | Command |
| --- | --- | --- |
| 1. voice.md holds the STE rules | `tests/test-ste-voice.sh` | `bash plugins/zuko/scripts/tests/run.sh ste-voice` |
| 2. Every skill and agent reads voice.md | `tests/test-ste-voice.sh` | same |
| 3. Text that is not prose keeps its format | `tests/test-ste-voice.sh` | same |
| 4. The project's own writing rules win | `tests/test-ste-voice.sh` | same |
| 5. The next real stop follows the rules | by hand, after the release (O1) | — |

What the test checks:

- **Scenario 1.** The section names "ASD-STE100, Issue 9 (January 2025)" and
  says that zuko does not use the dictionary. One pattern for each of the nine
  rules. "Banned outright" still holds `leverage` and `Emojis`. Rule 2 names
  the new section. The README's Voice section names ASD-STE100 and "20 words or
  fewer".
- **Scenario 2.** Each `skills/*/SKILL.md` and `agents/*.md` names
  `${CLAUDE_PLUGIN_ROOT}/references/voice.md`. The test fails if it finds fewer
  than 12 skills or 4 agents, because a loop that read nothing is not a pass.
- **Scenarios 3 and 4.** The "Not prose" list, the one-word count, the
  full-sentence line and "The project's rules win" are in the section.

**E2E:** `test-ste-voice.sh` walks scenarios 1 to 4 over the files that ship.
Scenario 5 is the behaviour check, by hand at the next real stop.

The full suite must stay green: `bash plugins/zuko/scripts/tests/run.sh`.

### Chunks

Single chunk. The test file is written first.

### Risks

| Risk | Mitigation |
| --- | --- |
| Claude reads the rules and still writes long sentences. Only a person checks it. | Accepted in O1. The next real stop shows it. |
| An agent skips its read line. | The stage that reports to the user reads `voice.md` too, and it writes the final text. |
| Claude rewords a fixed message that a skill gives word for word. | The quoted-text item in "Not prose" names those messages. |
| macOS runs the test with bash 3.2. | The test uses only the helpers and forms of the existing tests. `/build` checks it with `bash -n`. |

### Decisions to record

Recorded as D37, D38.

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | How do we prove that zuko writes to the STE rules? | question | spec p1 | user | Resolved | A contract test proves the text. The next real `/spec` stop shows the behaviour. No check script, no headless spike. 2026-10-12 |
| O2 | `/status` and the four agents do not read `voice.md`. Which of them should? | question | spec p1 | user | Resolved | All of them. Every skill and agent names `voice.md`. 2026-10-12 |
| O3 | Does the user have a copy of ASD-STE100 Issue 9, so `voice.md` can cite rule numbers? | question | spec p1 | user | Resolved | No. `voice.md` states each rule in its own words, with no numbers. 2026-10-12 |
| O4 | When the project's CLAUDE.md sets other writing rules, which wins? | question | spec p1 | user | Resolved | The project's rules. STE fills the gaps. 2026-10-12 |
| O5 | Assuming the adopted rules are the ones that public sources confirm: the shape's list and the Wikipedia summary of Issue 9. Rules not checked against a source are left out. | assumption | spec p1 | user | Resolved | Accepted as written. A missing rule costs one line in `voice.md` later. 2026-10-12 |
| O6 | Assuming code, commands, paths, quotes, headings, table labels, diagram labels and commit subjects are not prose, and a name in backticks counts as one word. | assumption | spec p1 | user | Resolved | Accepted with two changes. Code comments match the file. A full sentence follows STE, also in a table cell or a Gherkin step. 2026-10-12 |

_Never delete this section or its rows. See references/ledger.md._

## Glossary

- **ASD-STE100** — Simplified Technical English. A writing standard from ASD,
  the European aerospace and defence association. It has 53 writing rules and a
  dictionary of approved words. ASD owns the text.
- **Noun cluster** — nouns stacked in a row, such as "spec gate check failure
  message".
- **Contract test** — a test that checks the text of a prompt or reference file,
  not what Claude does with it.
- **Headless run** — running Claude Code with `claude -p`, with no terminal UI,
  so a script can check what it did.
- **e2e** — end-to-end: one test that walks the whole slice as a user would.
