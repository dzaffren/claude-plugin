# Multi-Choice Prompt Pattern

Forge's house style for interactive questions. Every skill that prompts the
user applies this pattern whenever the answer space is small enough to
enumerate.

Pairs with `${CLAUDE_PLUGIN_ROOT}/references/plain-language.md` — the
plain-wording, reason-behind-the-recommendation, and detail-on-demand trust
standard that applies to every prompt built with this pattern.

## Format

```
Question: <one clear sentence>

Options:
  1. <most-common option>
  2. <option>
  3. <option>
  4. Other — I'll type my own answer

Why it matters: <1–2 lines; skip when obvious>
Recommended: <#>
```

## Rules

- **Max 4 options + "Other".** More than that and the user stops reading.
- **The recommended choice is always shown.** If the skill has no real
  preference, pick the safest default and say so.
- **State the reason for the recommendation.** The `Recommended: <#>` line must
  carry a short, plain-language reason — the basis for that pick, and why over
  the alternatives when relevant. A recommended option with no stated reason
  fails forge's trust standard (`plain-language.md`): the user can't judge a pick
  whose reasoning they can't see.
- **Offer technical detail on demand.** When an option carries technical depth
  the user might want to weigh, note that they can ask to see it — but keep it
  default-off; the plain options and the recommended reason are what the user
  reads to choose. See `plain-language.md`.
- **Multi-select allowed when additive.** If the question naturally takes
  multiple answers (e.g. "Which areas does this touch: 1. backend, 2. frontend, 3. db, 4. infra"), let the user reply "1, 3" and treat it as
  a set.
- **Redundant questions show the inferred answer pre-selected.** When the
  skill has enough context to infer, say so — `Recommended: 2 (inferred
from <reason>)` — and accept a bare "yes" as confirmation.
- **Keep "Other" last.** It is the escape hatch; if the enumerated options
  are right, the user never has to type.
- **Never add options the user cannot pick.** If an option is not actually
  available yet (e.g. a feature is disabled), omit it. Hiding is better
  than greying-out in text UIs.

## When NOT to use multi-choice

- Names and identifiers — the user has to type those.
- Open-ended brainstorming where enumerating would bias the answer.
- Questions with more than ~8 distinct reasonable answers.

## Example

```
Question: What's the nature of this work?

Options:
  1. Bug fix
  2. New feature (user-facing)
  3. Technical task (refactor, upgrade, infra, migration)
  4. Multi-story epic
  5. Other — I'll type my own answer

Why it matters: It picks the spec template — simple, story, technical, or
overview+stories.
Recommended: 2
```
