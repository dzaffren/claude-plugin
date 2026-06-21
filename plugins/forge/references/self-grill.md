# Self-Grill

A shared procedure for the planning stages — discovery, prd, prd-refine — to
**stress-test their own draft output** before presenting or handing it off,
instead of the user manually running a separate grilling step afterward. It
reuses the `grill-me` questioning discipline and the multi-choice format; the
only change is *who gets grilled* — the stage critiques its own draft, not the
user.

## When it runs (producer before consumer)

Run the self-grill on the stage's **draft artifact** — after the stage has
produced it, but **before** the draft is presented, written, or handed to the
next stage. The draft must exist first; never self-grill a not-yet-drafted
artifact (an empty or partial draft has nothing meaningful to critique). See
`blocker-skill-step-numbering-vs-data-deps`.

| Stage      | Draft artifact to grill                                          | Run it…                                          |
| ---------- | --------------------------------------------------------------- | ------------------------------------------------ |
| discovery  | the assembled brief (goal, problems, pick, ideas, leap, experiment) | once the brief is assembled, before writing it   |
| prd        | the drafted requirements                                        | once composed from context, before filling the template |
| prd-refine | the drafted technical sections                                  | once drafted, before presenting them for approval |

## The procedure

1. **Critique your own draft.** Read it as a skeptical reviewer and find:
   - **gaps** — something a consumer of this artifact will need that is missing or vague;
   - **contradictions** — two parts of the draft that conflict;
   - **unstated assumptions** — a choice the draft silently bakes in.
2. **Classify each finding** as exactly one of:
   - **Minor / low-risk gap** — an omission or ambiguity with an obvious, reasonable default that does *not* change product scope, a real product decision, or a trade-off the user would care about → **resolve it yourself**.
   - **Genuine decision** — a real product, scope, or trade-off call (who qualifies, which requirement wins, instant-vs-reliable) → **surface it to the user**; never decide it on their behalf at these stages.
3. **Auto-resolve the minors** — apply the reasonable default in the draft, and record each one in the assumptions summary (step 6). Never silently resolve without disclosing.
4. **Surface only the genuine decisions** — one at a time, in plain language, each with a recommended answer and the reason, using the multi-choice format (`${CLAUDE_PLUGIN_ROOT}/references/multi-choice.md`) and the `grill-me` question discipline (specific, concrete, something to react to). Never dump a checklist.
5. **If there are no genuine decisions, ask nothing.** Present only the assumptions summary for the user to confirm or correct.
6. **Show the assumptions summary** — a short "here's what I assumed" block, in plain language, listing **every** gap you resolved yourself. The user can confirm or correct any of them.
7. **Fold answers and corrections back into the draft** — update the affected part only; leave unrelated parts unchanged. Then continue.

## Rules

- **The user makes every genuine call.** At discovery / prd / prd-refine the
  stage assists; it never decides a real product/scope/trade-off question for the
  user. The draft changes for that decision only after the user answers, and if
  the user disagrees with the recommended answer, the user's choice wins.
- **Disclose every self-resolved gap.** Anything you settled yourself goes in the
  assumptions summary — nothing is silently baked in.
- **Surface few, plainly.** Only genuine decisions become questions; minor gaps
  become assumptions. Never escalate a minor gap into a question, nor demote a
  genuine product/scope/trade-off into a silent assumption.
- **Reuse, don't reinvent.** Use the existing `grill-me` discipline and the
  `multi-choice.md` format. Do not invent a new questioning mechanism, and do not
  re-run the standalone `/grill-me` skill — this is the embedded, self-directed
  version.
- **Idempotent.** Re-grilling an unchanged, already-grilled draft surfaces nothing
  new — same draft in, same classification out. (A draft revised by a correction
  is a *different* draft and may legitimately produce a different result.)
